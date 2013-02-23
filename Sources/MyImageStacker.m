//
//  Lynkeos
//  $Id: MyImageStacker.m 506 2011-03-26 18:40:46Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun Jun 17 2007.
//  Copyright (c) 2007-2011. Jean-Etienne LAMIAUD
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
//

#include "MyUserPrefsController.h"
#include "MyChromaticAlignerView.h"
#include "MyImageStackerPrefs.h"
#include "MyImageStacker.h"

#include "MyImageStacker_Standard.h"
#include "MyImageStacker_SigmaReject.h"
#include "MyImageStacker_Extrema.h"

static NSString * const K_CROP_RECTANGLE_KEY = @"crop";
static NSString * const K_SIZE_FACTOR_KEY    = @"sizef";
static NSString * const K_MONOFLAT_KEY       = @"monoflat";
static NSString * const K_STACK_METHOD_KEY   = @"method";
static NSString * const K_SIGMA_THRESHOLD_KEY= @"sigmaThreshold";
static NSString * const K_MIN_MAX_KEY        = @"extremumMinMax";

NSString * const myImageStackerRef = @"MyImageStacker";
NSString * const myImageStackerParametersRef = @"StackerParams";
NSString * const myImageStackerListRef = @"ListToStack";

@implementation MyImageStackerParameters
- (id) init
{
   self = [super init];
   if ( self != nil )
   {
      _cropRectangle = LynkeosMakeIntegerRect(0,0,0,0);
      _factor = 1.0;
      _stackMethod = Stacking_Standard;
      _postStack = NoPostStack;
      _monochromeStack = NO;
   }

   return( self );
}

- (void) dealloc
{
   if ( _stackLock != nil )
      [_stackLock release];

   [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [encoder encodeRect: NSRectFromIntegerRect(_cropRectangle) 
                forKey: K_CROP_RECTANGLE_KEY];
   [encoder encodeDouble:_factor forKey:K_SIZE_FACTOR_KEY];
   [encoder encodeBool:_monochromeStack forKey:K_MONOFLAT_KEY];
   [encoder encodeInt:(int)_stackMethod forKey:K_STACK_METHOD_KEY];
   switch ( _stackMethod )
   {
      case Stacking_Standard:
         // No parameters
         break;
      case Stacking_Sigma_Reject:
         [encoder encodeFloat:_method.sigma.threshold forKey:K_SIGMA_THRESHOLD_KEY];
         break;
      case Stacking_Extremum:
         [encoder encodeBool:_method.extremum.maxValue
                      forKey:K_MIN_MAX_KEY];
         break;
      default:
         NSAssert( NO, @"Invalid stacking mode" );
   }
}

- (id)initWithCoder:(NSCoder *)decoder
{
   self = [self init];

   if ( self != nil )
   {
      _cropRectangle = LynkeosIntegerRectFromNSRect(
                               [decoder decodeRectForKey:K_CROP_RECTANGLE_KEY]);
      if ( [decoder containsValueForKey:K_SIZE_FACTOR_KEY] )
         _factor = [decoder decodeDoubleForKey:K_SIZE_FACTOR_KEY];
      _monochromeStack = [decoder decodeBoolForKey:K_MONOFLAT_KEY];
      _stackMethod = [decoder decodeIntForKey:K_STACK_METHOD_KEY];
      switch ( _stackMethod )
      {
         case Stacking_Standard:
            // No parameters
            break;
         case Stacking_Sigma_Reject:
            _method.sigma.threshold =
               [decoder decodeFloatForKey:K_SIGMA_THRESHOLD_KEY];
            break;
         case Stacking_Extremum:
            _method.extremum.maxValue =
               [decoder decodeBoolForKey:K_MIN_MAX_KEY];
            break;
      }
   }

   return( self );
}
@end

@implementation MyImageStackerList
- (id) init
{
   self = [super init];
   if ( self != nil )
      _list = nil;

   return( self );
}
@end

@implementation MyImageStacker

+ (ParallelOptimization_t) supportParallelization
{
   return( [[NSUserDefaults standardUserDefaults] integerForKey:
                                                         K_PREF_STACK_MULTIPROC]
           & ListThreadsOptimizations);
}

- (id <LynkeosProcessing>) initWithDocument: (id <LynkeosDocument>)document
                                 parameters:(id <NSObject>)params
                                  precision: (floating_precision_t)precision
{
   NSAssert( precision == PROCESSING_PRECISION, 
             @"Wrong precision in stacker initialization" );
   NSAssert( params != nil || ![params isKindOfClass:[MyImageStackerList class]],
             @"No list argument for stack start" );
   self = [self init];
   if ( self == nil )
      return( self );

   _document = document;
   _list = ((MyImageStackerList*)params)->_list;
   NSAssert( _list != nil, @"Failed to find which list to stack" );
   _params = [_list getProcessingParameterWithRef:myImageStackerParametersRef
                                    forProcessing:myImageStackerRef];
   NSAssert( _params != nil, @"Failed to find stack parameters" );
   _monoBuffer = nil;
   _rgbBuffer = nil;
   _imagesStacked = 0;

   // Allocate the strategy
   switch ( _params->_stackMethod )
   {
      case Stacking_Standard:
         _stackingStrategy =
            [[MyImageStacker_Standard alloc] initWithParameters:_params
                                                           list:_list];
         break;
      case Stacking_Sigma_Reject:
         _stackingStrategy =
            [[MyImageStacker_SigmaReject alloc] initWithParameters:_params
                                                              list:_list];
         break;
      case Stacking_Extremum:
         _stackingStrategy =
            [[MyImageStacker_Extrema alloc] initWithParameters:_params
                                                          list:_list];
         break;
      default:
         NSAssert( NO, @"Invalid stacking method" );
   }

   [_params->_stackLock lock];
   _params->_livingThreads++;
   [_params->_stackLock unlock];

   return( self );
}

- (void) dealloc
{
   if ( _monoBuffer != nil )
      [_monoBuffer release];
   if ( _rgbBuffer != nil )
      [_rgbBuffer release];
   [_stackingStrategy release];

   [super dealloc];
}

// As this processing is compiled in, only the compile precision is implemented
// (be lazy).
- (void) processItem :(id <LynkeosProcessableItem>)item
{
   id <LynkeosAlignResult> alignRes =
      (id <LynkeosAlignResult>)[item getProcessingParameterWithRef:
                                                         LynkeosAlignResultRef
                                          forProcessing:LynkeosAlignRef];

   if ( alignRes != nil )
   {
      LynkeosIntegerRect r = _params->_cropRectangle;
      LynkeosIntegerPoint shift;
      NSPoint p = [alignRes offset];
      LynkeosStandardImageBuffer **image;
      NSPoint offsets[3];
      u_short c;

      // Get the image part to add
      p.x *= -1;	// Shift the crop rectangle in the opposite side
      p.y *= -1;

      shift.x = (p.x < 0 ? (int)(p.x-1) : (int)p.x);   // Crop at integer pixels
      shift.y = (p.y < 0 ? (int)(p.y-1) : (int)p.y);
      r.origin.x += shift.x;
      r.origin.y += shift.y;

      // Convert to bitmap coordinate system
      r.origin.y = [item imageSize].height - r.origin.y - r.size.height;

      // Work on variables according to planearity
      if ( [item numberOfPlanes] == 1 )
         image = &_monoBuffer;
      else
         image = &_rgbBuffer;

      // Create a buffer from the calibrated image
      LynkeosStandardImageBuffer *imageBefore = *image;
      [item getImageSample:image inRect:r];
      if ( imageBefore == nil && *image != nil )
         [*image retain];  // It was autoreleased by the item

      // Take the chromatic dispersion correction into account
      MyChromaticAlignParameter *chroma =
                [item getProcessingParameterWithRef:myChromaticAlignerOffsetsRef
                                      forProcessing:myChromaticAlignerRef];

      // Prepare the offsets, with conversion to the bitmap coordinate system
      p.x = (p.x - shift.x)*(double)_params->_factor;
      p.y = (-p.y + shift.y)*(double)_params->_factor;
      for( c = 0; c < (*image)->_nPlanes; c++ )
      {
         offsets[c] = p;
         if ( chroma != nil )
         {
            offsets[c].x += chroma->_offsets[c].x*(double)_params->_factor;
            offsets[c].y -= chroma->_offsets[c].y*(double)_params->_factor;
         }
      }

      // Accumulate
      [_stackingStrategy processImage:*image withOffsets:offsets];
      _imagesStacked++;

      // As the item is not modified, force a notification
      [_document itemWasProcessed:item];
   }
}

- (void) finishProcessing
{
   // Take control of the list
   [_params->_stackLock lock];

   // Finish the processing for this thread
   [_stackingStrategy finishOneProcessingThreadInList:_list];

   _params->_imagesStacked += _imagesStacked;   

   // Finalize everything if we are the last thread
   _params->_livingThreads--;
   if ( _params->_livingThreads == 0 )
   {
      double b = 0.0, w = -1.0;

      [_stackingStrategy finishAllProcessingInList:_list];

      // Maybe, all this was for nothing !...
      LynkeosStandardImageBuffer *stack = [_stackingStrategy stackingResult];
      if ( stack != nil )
      {
         // Well... maybe not
         // Perform any postprocessing
         switch( _params->_postStack )
         {
            case NoPostStack:
               // "Monochromize" the stack if required
               if ( _params->_monochromeStack && [stack numberOfPlanes] != 1 )
                  [stack normalizeWithFactor:1.0
                                        mono:_params->_monochromeStack];
               break;
            case MeanStack:
               [stack normalizeWithFactor:1.0/(double)_params->_imagesStacked
                                     mono:_params->_monochromeStack];
               break;
            case NormalizeStack:
               // Normalize the stack to max = 1.0
               [stack normalizeWithFactor:0.0 mono:_params->_monochromeStack];
               b = 0.0;
               w = 1.0;
               break;
            default:
               NSAssert1( NO, @"Invalid post stack action : %d",
                          _params->_postStack );
         }
      }

      // Put the stack in the list
      [_list setOriginalImage:stack];
      if ( w > b )
         [_list setBlackLevel:b whiteLevel:w gamma:1.0];
   }

   [_params->_stackLock unlock];
}
@end
