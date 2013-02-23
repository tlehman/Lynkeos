//
//  MyImageStacker_Standard.m
//  Lynkeos
//
//  Created by Jean-Etienne LAMIAUD on 01/01/11.
//  Copyright 2011 Jean-Etienne LAMIAUD. All rights reserved.
//

#include "MyImageStacker_Standard.h"

// Private (and temporary) parameter used to recombine the stacks
static NSString * const myStandardImageStackerResult = @"StandardStackerResult";

@interface StandardImageStackerResult : NSObject <LynkeosProcessingParameter>
{
@public
   LynkeosStandardImageBuffer* _mono;
   LynkeosStandardImageBuffer* _rgb;
}
@end

@implementation StandardImageStackerResult
- (id) init
{
   self = [super init];
   if ( self != nil )
   {
      _mono = nil;
      _rgb = nil;
   }
   
   return( self );
}

- (void) dealloc
{
   if ( _mono != nil )
      [_mono release];
   if ( _rgb != nil )
      [_rgb release];
   
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

@implementation MyImageStacker_Standard

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _params = nil;
      _monoStack = nil;
      _rgbStack = nil;
   }

   return( self );
}

- (id) initWithParameters: (id <NSObject>)params
                     list: (id <LynkeosImageList>)list
{
   if ( (self = [self init]) != nil )
   {
      _params = [params retain];
   }

   return( self );
}

- (void) dealloc
{
   if ( _monoStack != nil )
      [_monoStack release];
   if ( _rgbStack != nil )
      [_rgbStack release];

   [super dealloc];
}

- (void) processImage: (id <LynkeosImageBuffer>)image
         withOffsets: (NSPoint*)offsets
{
   LynkeosStandardImageBuffer **sum;

   if ( [image numberOfPlanes] == 1 )
      sum = &_monoStack;
   else
      sum = &_rgbStack;

   // If this is the first image, create the empty stack buffer with the same 
   // number of planes (taking into account the expansion factor)
   if ( *sum == nil )
      *sum = [[LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:
                                                [image numberOfPlanes]
                                                                  width:
                                                [image width]*_params->_factor
                                                                 height:
                                                [image height]*_params->_factor]
              retain];

   // Accumulate
   [*sum add:image withOffsets:offsets withExpansion:_params->_factor];
}

- (void) finishOneProcessingThreadInList:(id <LynkeosImageList>)list ;
{
   // Recombine the stacks in the list
   StandardImageStackerResult *res
      = [list getProcessingParameterWithRef:myStandardImageStackerResult
                              forProcessing:myImageStackerRef];

   if ( res == nil )
   {
      res = [[[StandardImageStackerResult alloc] init] autorelease];
      res->_mono = [_monoStack retain];
      res->_rgb = [_rgbStack retain];
      [list setProcessingParameter:res withRef:myStandardImageStackerResult 
                     forProcessing:myImageStackerRef];
   }
   else
   {
      if ( _monoStack != nil )
      {
         if ( res->_mono != nil )
            [res->_mono add:_monoStack];
         else
            res->_mono = [_monoStack retain];
      }
      if ( _rgbStack != nil )
      {
         if ( res->_rgb != nil )
            [res->_rgb add:_rgbStack];
         else
            res->_rgb = [_rgbStack retain];
      }
   }
}

- (void) finishAllProcessingInList: (id <LynkeosImageList>)list;
{
   // Recombine monochrome and RGB stacks if needed
   StandardImageStackerResult *res
      = [list getProcessingParameterWithRef:myStandardImageStackerResult
                              forProcessing:myImageStackerRef];
   LynkeosStandardImageBuffer *stack = nil;

   if ( res->_rgb != nil )
      stack = [res->_rgb retain];

   if ( res->_mono != nil )
   {
      if ( stack == nil )
         stack = [res->_mono retain];
      else
         // Add code knows how to add L with RGB
         [stack add:res->_mono];
   }

   if ( _rgbStack != nil )
      [_rgbStack release];
   _rgbStack = stack;
   if ( _monoStack != nil )
      [_monoStack release];
   _monoStack = nil;

   // And get rid of the recombining parameter
   [list setProcessingParameter:nil withRef:myStandardImageStackerResult 
                  forProcessing:myImageStackerRef];   
}

- (LynkeosStandardImageBuffer*) stackingResult { return( _rgbStack ); }

@end
