//
//  MyImageStacker_Extrema.m
//  Lynkeos
//
//  Created by Jean-Etienne LAMIAUD on 09/01/11.
//  Copyright 2011 Jean-Etienne LAMIAUD. All rights reserved.
//

#include "MyImageStacker_Extrema.h"

// Private (and temporary) parameter used to recombine the stacks
static NSString * const myExtremaImageStackerResult = @"ExtremaStackerResult";

@interface ExtremaImageStackerResult : NSObject <LynkeosProcessingParameter>
{
@public
   LynkeosStandardImageBuffer* _extremum; //!< Global extremum
}
@end

@implementation ExtremaImageStackerResult
- (id) init
{
   self = [super init];
   if ( self != nil )
   {
      _extremum = nil;
   }

   return( self );
}

- (void) dealloc
{
   if ( _extremum != nil )
      [_extremum release];

   [super dealloc];
}

// This parameter is deleted at process end, it cannot be saved
- (void)encodeWithCoder:(NSCoder *)encoder
{
   [self doesNotRecognizeSelector:_cmd];
}
- (id)initWithCoder:(NSCoder *)decoder
{
   [self doesNotRecognizeSelector:_cmd];
   return( nil );
}
@end

@interface MyImageStacker_Extrema(Private)
- (void) processBuffer:(LynkeosStandardImageBuffer*)buf
            withResult:(LynkeosStandardImageBuffer*)res ;
@end

@implementation MyImageStacker_Extrema(Private)
- (void) processBuffer:(LynkeosStandardImageBuffer*)buf
            withResult:(LynkeosStandardImageBuffer*)res
{
   u_short x, y, c;
   REAL **p = (REAL**)[res colorPlanes];

   for( c = 0; c < buf->_nPlanes; c++ )
      for( y = 0; y < buf->_h; y++ )
         for( x = 0; x < buf->_w; x++ )
         {
            REAL v = stdColorValue(buf,PROCESSING_PRECISION,x,y,c);
            if ( _params->_method.extremum.maxValue )
            {
               if ( v > stdColorValue(res,PROCESSING_PRECISION,x,y,c) )
               {
                  SET_SAMPLE(p[c],PROCESSING_PRECISION,x,y,res->_padw, v);
               }
            }
            else
            {
               if ( v < stdColorValue(res,PROCESSING_PRECISION,x,y,c) )
               {
                  SET_SAMPLE(p[c],PROCESSING_PRECISION,x,y,res->_padw, v);
               }
            }
         }
}
@end

@implementation MyImageStacker_Extrema

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _params = nil;
      _extremum = nil;
   }

   return( self );
}

- (id) initWithParameters: (id <NSObject>)params
                     list: (id <LynkeosImageList>)list
{
   if ( (self = [self init]) != nil )
      _params = [params retain];

   return( self );
}

- (void) dealloc
{
   if ( _params != nil )
      [_params release];
   if ( _extremum != nil )
      [_extremum release];

   [super dealloc];
}

- (void) processImage: (id <LynkeosImageBuffer>)image
          withOffsets: (NSPoint*)offsets
{
   NSAssert( _extremum == nil || _extremum->_nPlanes == [image numberOfPlanes],
            @"heterogeneous planes numbers in extremum stacking" );

   // Extract the data in a local image buffer
   LynkeosStandardImageBuffer *buf
      = [LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:
                                               [image numberOfPlanes]
                                                         width:
                                               [image width]*_params->_factor
                                                        height:
                                               [image height]*_params->_factor];
   [buf add:image withOffsets:offsets withExpansion:_params->_factor];

   // If this is the first image, create the empty stack buffer with the same 
   // number of planes (taking into account the expansion factor)
   if ( _extremum == nil )
      _extremum = [[LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:
                                                                   buf->_nPlanes
                                                                       width:
                                                                   buf->_w
                                                                      height:
                                                                   buf->_h]
                                                                        retain];

   [self processBuffer:buf withResult:_extremum];
}

- (void) finishOneProcessingThreadInList:(id <LynkeosImageList>)list ;
{
   // Recombine the stacks in the list
   ExtremaImageStackerResult *res
      = [list getProcessingParameterWithRef:myExtremaImageStackerResult
                              forProcessing:myImageStackerRef];

   if ( res == nil )
   {
      res = [[[ExtremaImageStackerResult alloc] init] autorelease];
      
      [list setProcessingParameter:res withRef:myExtremaImageStackerResult 
                     forProcessing:myImageStackerRef];
   }

   if ( res->_extremum == nil )
      res->_extremum = [_extremum retain];
   else
      [self processBuffer:_extremum withResult:res->_extremum];   
}

- (void) finishAllProcessingInList: (id <LynkeosImageList>)list;
{
}

- (LynkeosStandardImageBuffer*) stackingResult { return( _extremum ); }
@end
