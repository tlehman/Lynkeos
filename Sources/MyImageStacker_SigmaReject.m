//
//  MyImageStacker_SigmaReject.m
//  Lynkeos
//
//  Created by Jean-Etienne LAMIAUD on 03/01/11.
//  Copyright 2011 Jean-Etienne LAMIAUD. All rights reserved.
//
#include <stdlib.h>

#include "MyImageStacker_SigmaReject.h"

// Private (and temporary) parameter used to recombine the stacks
static NSString * const mySigmaRejectImageStackerResult
                           = @"SigmaRejectStackerResult";

@interface SigmaRejectImageStackerResult : NSObject <LynkeosProcessingParameter>
{
@public
   LynkeosStandardImageBuffer* _sum; //!< Sum at end of pass1, mean during pass2
   //! square sum at end of pass1, Standard deviation during pass2
   LynkeosStandardImageBuffer* _sum2;
   u_short*                    _count; //!< Buffer of pixels count during pass2
}
@end

@implementation SigmaRejectImageStackerResult
- (id) init
{
   self = [super init];
   if ( self != nil )
   {
      _sum = nil;
      _sum2 = nil;
      _count = NULL;
   }

   return( self );
}

- (void) dealloc
{
   if ( _sum != nil )
      [_sum release];
   if ( _sum2 != nil )
      [_sum2 release];
   if ( _count != NULL )
      free( _count );

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

@implementation MyImageStacker_SigmaReject

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _params = nil;
      _sum = nil;
      _sum2 = nil;
      _count = NULL;
      _list = nil;
   }

   return( self );
}

- (id) initWithParameters: (id <NSObject>)params
                     list: (id <LynkeosImageList>)list
{
   if ( (self = [self init]) != nil )
   {
      _params = [params retain];
      _list = list;
   }
   
   return( self );
}

- (void) dealloc
{
   if ( _params != nil )
      [_params release];
   if ( _sum != nil )
      [_sum release];
   if ( _sum2 != nil )
      [_sum2 release];
   if ( _count != NULL )
      free( _count );

   [super dealloc];
}

- (void) processImage: (id <LynkeosImageBuffer>)image
          withOffsets: (NSPoint*)offsets
{
   NSAssert( _sum == nil || _sum->_nPlanes == [image numberOfPlanes],
             @"heterogeneous planes numbers in sigma reject stacking" );

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
   if ( _sum == nil )
      _sum = [[LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:
                                                               buf->_nPlanes
                                                                  width:
                                                               buf->_w
                                                                 height:
                                                               buf->_h]
                                                                        retain];


   if ( _params->_method.sigma.pass == 1 )
   {
      // Allocate the square sum buffer if needed
      if ( _sum2 == nil )
         _sum2 = [[LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:
                                                                  buf->_nPlanes
                                                                      width:
                                                                  buf->_w
                                                                     height:
                                                                  buf->_h]
                                                                        retain];

      // Accumulate
      [_sum add:buf];

      // And accumulate the square values
      [buf multiplyWith:buf result:buf];
      [_sum2 add:buf];
   }
   else
   {
      u_short x, y, c;
      REAL **p = (REAL**)[_sum colorPlanes];
      SigmaRejectImageStackerResult *res
         = [_list getProcessingParameterWithRef:mySigmaRejectImageStackerResult
                                  forProcessing:myImageStackerRef];
      
      // Allocate the count buffer if needed
      if ( _count == NULL )
         _count = (u_short*)calloc( buf->_nPlanes*buf->_w*buf->_h,
                                    sizeof(u_short) );

      // Perform pixel addition only when below the standard deviation threshold
      for( c = 0; c < buf->_nPlanes; c++ )
      {
         for( y = 0; y < buf->_h; y++ )
         {
            for( x = 0; x < buf->_w; x++ )
            {
               REAL v = stdColorValue(buf,PROCESSING_PRECISION,x,y,c);
               REAL m = stdColorValue(res->_sum,PROCESSING_PRECISION,x,y,c);
               REAL s = stdColorValue(res->_sum2,PROCESSING_PRECISION,x,y,c);
               if ( fabs(v-m) <= s*_params->_method.sigma.threshold )
               {
                  v += stdColorValue(buf,PROCESSING_PRECISION,x,y,c);
                  SET_SAMPLE(p[c],PROCESSING_PRECISION,x,y,_sum->_padw, v);
                  _count[(c*buf->_h + y)*buf->_w + x]++;
               }
            }
         }
      }
   }
}

- (void) finishOneProcessingThreadInList:(id <LynkeosImageList>)list ;
{
   // Recombine the stacks in the list
   SigmaRejectImageStackerResult *res
      = [list getProcessingParameterWithRef:mySigmaRejectImageStackerResult
                              forProcessing:myImageStackerRef];

   if ( res == nil )
   {
      res = [[[SigmaRejectImageStackerResult alloc] init] autorelease];

      [list setProcessingParameter:res withRef:mySigmaRejectImageStackerResult 
                     forProcessing:myImageStackerRef];
   }

   if ( res->_sum == nil )
      res->_sum = [_sum retain];
   else
      [res->_sum add:_sum];

   if ( _params->_method.sigma.pass == 1 )
   {
      if ( res->_sum2 == nil )
         res->_sum2 = [_sum2 retain];
      else
         [res->_sum2 add:_sum2];
   }
   else
   {
      u_short x, y, c;

      if ( res->_count == NULL )
         res->_count = (u_short*)calloc(_sum->_nPlanes*_sum->_w*_sum->_h,
                                        sizeof(u_short));

      for( c = 0; c < _sum->_nPlanes; c++ )
         for( y = 0; y < _sum->_h; y++ )
            for( x = 0; x < _sum->_w; x++ )
               res->_count[(c*_sum->_h + y)*_sum->_w + x] +=
                                          _count[(c*_sum->_h + y)*_sum->_w + x];
   }
}

- (void) finishAllProcessingInList: (id <LynkeosImageList>)list;
{
   REAL **p;
   u_short x, y, c;

   // Calculate the stats
   SigmaRejectImageStackerResult *res
      = [list getProcessingParameterWithRef:mySigmaRejectImageStackerResult
                              forProcessing:myImageStackerRef];
   NSAssert( res != nil, @"No stacking result at sigma reject pass end" );

   if ( _params->_method.sigma.pass == 1 )
   {
      // Compute the mean
      REAL s = 1.0/(REAL)_params->_imagesStacked;
      [res->_sum multiplyWithScalar:s];
      // The variance
      [res->_sum2 multiplyWithScalar:s];
      LynkeosStandardImageBuffer *buf
         = [LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:
                                                             res->_sum->_nPlanes
                                                               width:
                                                             res->_sum->_w
                                                              height:
                                                             res->_sum->_h];
      [res->_sum multiplyWith:res->_sum result:buf];
      [res->_sum2 substract:buf];
      // And the standard deviation from the variance
      p = (REAL**)[res->_sum2 colorPlanes];
      for( c = 0; c < res->_sum2->_nPlanes; c++ )
         for( y = 0; y < res->_sum2->_h; y++ )
            for( x = 0; x < res->_sum2->_w; x++ )
            {
               REAL v = sqrt(stdColorValue(res->_sum2,PROCESSING_PRECISION,
                                           x,y,c));
               SET_SAMPLE(p[c],PROCESSING_PRECISION,x,y,res->_sum2->_padw, v);
            }

   }
   else
   {
      // Compute the second pass mean, and store it
      p = (REAL**)[_sum colorPlanes];
      for( c = 0; c < _sum->_nPlanes; c++ )
         for( y = 0; y < _sum->_h; y++ )
            for( x = 0; x < _sum->_w; x++ )
            {
               REAL v;
               u_short n = res->_count[(c*res->_sum->_h + y)*res->_sum->_w + x];
               if ( n == 0 )
                  v = 0.0;
               else
                  v = stdColorValue(res->_sum,PROCESSING_PRECISION,x,y,c)
                      / (REAL)n;
               SET_SAMPLE(p[c],PROCESSING_PRECISION,x,y,_sum->_padw, v);
            }

      // And get rid of the recombining parameter
      [list setProcessingParameter:nil withRef:mySigmaRejectImageStackerResult 
                     forProcessing:myImageStackerRef];   
   }
}

- (LynkeosStandardImageBuffer*) stackingResult { return( _sum ); }

@end
