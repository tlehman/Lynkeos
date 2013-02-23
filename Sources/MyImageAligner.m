//  $Id: MyImageAligner.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun Dec 12 2005.
//  Copyright (c) 2005-2008. Jean-Etienne LAMIAUD
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

/*!
 * @header
 * @abstract Image alignment process implementation
 */
#include "processing_core.h"
#include "corelation.h"
#include "LynkeosStandardImageBufferAdditions.h"

#include "LynkeosBasicAlignResult.h"

#include "MyImageAlignerPrefs.h"
#include "MyImageAligner.h"

NSString * const myImageAlignerRef = @"MyImageAligner";
NSString * const myImageAlignerParametersRef = @"AlignParams";

#define K_ALIGN_ORIGIN_KEY    @"origin"    ///< Key for saving the square origin
#define K_ALIGN_SIZE_KEY      @"size"        ///< Key for saving the square size
#define K_ALIGN_DARKFRAME_KEY @"dark"        ///< Key for saving dark frame ref
#define K_ALIGN_FLATFIELD_KEY @"flat"        ///< Key for saving flat field ref
#define K_ALIGN_REF_KEY       @"refitem"  ///< Key for saving the reference item
#define K_ALIGN_CUTOFF_KEY    @"cutoff" ///< Key for saving the cutoff threshold
//! Key for saving the align precision threshold
#define K_ALIGN_PRECISION_KEY @"precision"

//==============================================================================
// Generic processing functions
//==============================================================================

/*!
 * Cut the highest frequencies from the spectrum to suppress noise
 */
static void cutoffSpectrum( LynkeosFourierBuffer *spectrum, u_short cutoff )
{
   u_short x, y;
   u_short h_2 = spectrum->_h/2;
   u_long cut2 = cutoff*cutoff;

   // Save time if there is no cutoff at all
   if ( cutoff >= sqrt(spectrum->_w*spectrum->_w+spectrum->_h*spectrum->_h) )
      return;

   for ( y = 0; y < spectrum->_h; y++ )
   {
      for ( x = 0; x < spectrum->_halfw; x++ )
      {
         short dx = x, dy = y;
         u_long f2; 
         if ( dy >= h_2 )
            dy -= spectrum->_h;
         f2 = dx*dx + dy*dy;

         if ( f2 > cut2 )
         {
            u_char c;

            for( c = 0; c < spectrum->_nPlanes; c++ )
               colorComplexValue(spectrum,x,y,c) = 0.0;
         }
      }
   }
}

static BOOL performAlignment( id <LynkeosProcessableItem> item,
                              LynkeosIntegerRect extractRect,
                              LynkeosFourierBuffer *buf,
                              LynkeosFourierBuffer *ref,
                              double cutoff,
                              double sigmaThreshold,
                              double valueThreshold,
                              CORRELATION_PEAK *peak )
{
   // Get the spectrum of that other image
   [item getFourierTransform:&buf forRect:extractRect prepareInverse:NO];
   cutoffSpectrum( buf, cutoff );

   // correlate it against the reference
   correlate_spectrums( ref, buf, buf );
   corelation_peak( buf, peak );

   return( peak->val >= valueThreshold &&
           peak->sigma_x < sigmaThreshold && peak->sigma_y < sigmaThreshold );
}

@implementation MyImageAlignerParameters
- (id) init
{
   self = [super init];
   if ( self != nil )
   {
      _alignOrigin.x = 0;
      _alignOrigin.y = 0;
   }

   return( self );
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [encoder encodePoint: NSPointFromIntegerPoint(_alignOrigin) 
                 forKey: K_ALIGN_ORIGIN_KEY];
}

- (id)initWithCoder:(NSCoder *)decoder
{
   self = [self init];

   if ( self != nil && [decoder containsValueForKey:K_ALIGN_ORIGIN_KEY] )
      _alignOrigin = LynkeosIntegerPointFromNSPoint(
                              [decoder decodePointForKey:K_ALIGN_ORIGIN_KEY]);

   return( self );
}

@end

@implementation MyImageAlignerListParameters

- (id) init
{
   self = [super init];
   if ( self != nil )
   {
      _alignSize.width = 0;
      _alignSize.height = 0;
      _referenceItem = nil;
      _refSpectrumLock = [[NSLock alloc] init];
      _referenceSpectrum = nil;
      _cutoff = 0.0;
      _precisionThreshold = 0.0;
      _checkAlignResult = NO;
   }

   return( self );
}

- (void) dealloc
{
   if ( _refSpectrumLock != nil )
      [_refSpectrumLock release];
   if ( _referenceSpectrum != nil )
      [_referenceSpectrum release];

   [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [super encodeWithCoder:encoder];

   [encoder encodeSize: NSSizeFromIntegerSize(_alignSize) 
                 forKey: K_ALIGN_SIZE_KEY];
   [encoder encodeConditionalObject:_referenceItem forKey:K_ALIGN_REF_KEY];
}

- (id) initWithCoder:(NSCoder *)decoder
{
   self = [super initWithCoder:decoder];

   if ( self != nil )
   {
      if ( [decoder containsValueForKey:K_ALIGN_SIZE_KEY] )
         _alignSize = LynkeosIntegerSizeFromNSSize(
                                [decoder decodeSizeForKey:K_ALIGN_SIZE_KEY]);
      _referenceItem = [decoder decodeObjectForKey:K_ALIGN_REF_KEY];
   }

   return( self );
}

@end

@implementation MyImageAligner

+ (ParallelOptimization_t) supportParallelization
{
   return( [[NSUserDefaults standardUserDefaults] integerForKey:
                                                         K_PREF_ALIGN_MULTIPROC]
           & ListThreadsOptimizations);
}

- (id <LynkeosProcessing>) initWithDocument: (id <LynkeosDocument>)document
                                 parameters:(id <NSObject>)params
                                  precision: (floating_precision_t)precision
{
   NSAssert( precision == PROCESSING_PRECISION, 
             @"Wrong precision in aligner initialization" );
   self = [self init];
   if ( self == nil )
      return( self );

   _document = document;
   _rootParams = [params retain];

   _cutoff = _rootParams->_cutoff*_rootParams->_alignSize.width;
   _precisionThreshold = _rootParams->_precisionThreshold
                         * _rootParams->_alignSize.width;

   // Prepare the reference spectrum in only one thread
   if ( [_rootParams->_refSpectrumLock tryLock] )
   {
      if ( _rootParams->_referenceSpectrum == nil )
      {
         LynkeosFourierBuffer *refSpectrum;
         MyImageAlignerParameters *refParam;
         LynkeosIntegerRect r;

         // Allocate it first
         refSpectrum = [[LynkeosFourierBuffer fourierBufferWithNumberOfPlanes:1 
                                       width:_rootParams->_alignSize.width
                                      height:_rootParams->_alignSize.height 
                                    withGoal: FOR_DIRECT|FOR_INVERSE] retain];

         // Retrieve the alignment rectangle for the reference item
         refParam = [_rootParams->_referenceItem getProcessingParameterWithRef:
                                                     myImageAlignerParametersRef
                                               forProcessing:myImageAlignerRef];
         NSAssert( refParam != nil, @"No alignment parameters for ref item");

         r.origin = refParam->_alignOrigin;
         r.size = _rootParams->_alignSize;

         // Take any previous alignment into account
         LynkeosBasicAlignResult *align = (LynkeosBasicAlignResult*)
                  [_rootParams->_referenceItem getProcessingParameterWithRef:
                                                           LynkeosAlignResultRef
                                                 forProcessing:LynkeosAlignRef];
         if ( align != nil )
         {
            // Alignment, when present, contains any individual offset
            r.origin.x = _rootParams->_alignOrigin.x
                         - (short)floorf(align->_alignOffset.x + 0.5);
            r.origin.y = _rootParams->_alignOrigin.y
                         - (short)floorf(align->_alignOffset.y + 0.5);
         }

         // Convert the coordinate system from Cocoa to bitmap
         r.origin.y = [_rootParams->_referenceItem imageSize].height 
                       - r.origin.y - r.size.height;

         // Get the sample
         [_rootParams->_referenceItem getImageSample:&refSpectrum
                                              inRect:r];
         // Calculate the minimum valid correlation peak height
         double vmin, vmax;
         [refSpectrum getMinLevel:&vmin maxLevel:&vmax];
         _valueThreshold = (vmax-vmin)*(vmax-vmin);
         // Get the spectrum
         [refSpectrum directTransform];

         // Cut the highest frequencies
         cutoffSpectrum( refSpectrum, _cutoff );

         // The spectrum is ready to be shared
         _rootParams->_referenceSpectrum = refSpectrum;
      }
      [_rootParams->_refSpectrumLock unlock];
   }

   // Allocate the buffer for each other images
   _bufferSpectrum = [[LynkeosFourierBuffer fourierBufferWithNumberOfPlanes:1 
                                       width:_rootParams->_alignSize.width
                                      height:_rootParams->_alignSize.height 
                                    withGoal: FOR_DIRECT|FOR_INVERSE] retain];

   return( self );
}

- (void) dealloc
{
   [_bufferSpectrum release];
   [_rootParams release];

   [super dealloc];
}

// As this processing is compiled in, only the compile precision is implemented
// (be lazy).
- (void) processItem:(id <LynkeosProcessableItem>)item
{
   MyImageAlignerParameters *itemParam =
                 [item getProcessingParameterWithRef:myImageAlignerParametersRef
                                       forProcessing:myImageAlignerRef];
   LynkeosIntegerRect r;

   // Retrieve the alignment rectangle for the item
   r.origin = itemParam->_alignOrigin;
   r.size = _rootParams->_alignSize;

   // Take any previous alignment into account
   LynkeosBasicAlignResult *align = (LynkeosBasicAlignResult*)
                       [item getProcessingParameterWithRef:LynkeosAlignResultRef
                                             forProcessing:LynkeosAlignRef];
   if ( align != nil )
   {
      // Alignment, when present, contains any individual offset
      r.origin.x = _rootParams->_alignOrigin.x
                   - (short)floorf(align->_alignOffset.x + 0.5);
      r.origin.y = _rootParams->_alignOrigin.y
                   - (short)floorf(align->_alignOffset.y + 0.5);
   }

   if ( item == _rootParams->_referenceItem )
   {
      // Set the reference item to 0,0 offset
      LynkeosBasicAlignResult *res =
                           [[[LynkeosBasicAlignResult alloc] init] autorelease];
      res->_alignOffset.x = -r.origin.x + _rootParams->_alignOrigin.x;
      res->_alignOffset.y = -r.origin.y + _rootParams->_alignOrigin.y;
      [item setProcessingParameter:res withRef:LynkeosAlignResultRef 
                     forProcessing:LynkeosAlignRef];
   }
   else
   {
      LynkeosIntegerRect extractRect;
      CORRELATION_PEAK peak;
      BOOL isAligned;

      // Check the reference spectrum availability before corelating against it
      if ( _rootParams->_referenceSpectrum == nil )
      {
         // Rendez vous with the "reference" thread
         [_rootParams->_refSpectrumLock lock];
         [_rootParams->_refSpectrumLock unlock];
      }

      // correlate it against the reference
      extractRect = r;
      extractRect.origin.y = [item imageSize].height 
                             - extractRect.origin.y - extractRect.size.height;
      isAligned = performAlignment( item, extractRect, _bufferSpectrum,
                                    _rootParams->_referenceSpectrum, _cutoff,
                                    _precisionThreshold, _valueThreshold,
                                    &peak );

      if ( isAligned && _rootParams->_checkAlignResult )
      {
         // Verify the alignment and flip it if needed
         BOOL alignChecked = NO;
         double ox, oy;
         for( oy = 0.0;
              !alignChecked && oy <= r.size.width;
              oy += r.size.width )
         {
            for( ox = 0.0;
                 !alignChecked && ox <= r.size.width;
                 ox += r.size.width )
            {
               CORRELATION_PEAK checkPeak;
               NSPoint flippedPeak;
               LynkeosIntegerPoint shift;
               LynkeosIntegerRect checkRect = extractRect;

               // Realign with a rectangle adjusted by the (flipped) result
               if ( peak.x >= 0.0 )
               {
                  flippedPeak.x = peak.x - ox;
                  shift.x = (int)(-flippedPeak.x - 1);
               }
               else
               {
                  flippedPeak.x = peak.x + ox;
                  shift.x = (int)(-flippedPeak.x);
               }
               if ( peak.y >= 0.0 )
               {
                  flippedPeak.y = peak.y - oy;
                  shift.y = (int)(-flippedPeak.y - 1);
               }
               else
               {
                  flippedPeak.y = peak.y + oy;
                  shift.y = (int)flippedPeak.y;
               }
               checkRect.origin.x += shift.x;
               checkRect.origin.y += shift.y;
               alignChecked = performAlignment( item, checkRect,
                                          _bufferSpectrum,
                                          _rootParams->_referenceSpectrum,
                                          _cutoff,
                                          _precisionThreshold, _valueThreshold,
                                          &checkPeak );
               if ( alignChecked )
               {
                  // Verify that the new peak is the residual of the
                  // (flipped) one
                  if ( fabs(checkPeak.x-(double)shift.x-flippedPeak.x) >= 0.5 
                     || fabs(checkPeak.y-(double)shift.y-flippedPeak.y) >= 0.5 )
                     // Alas! this alignment is not consistent
                     isAligned = NO;
                  else
                  {
                     // Adjust the result
                     peak.x = checkPeak.x - (double)shift.x;
                     peak.y = checkPeak.y - (double)shift.y;
                  }
               }
            }
         }
      }

      if ( isAligned )
      {
         LynkeosBasicAlignResult *res =
                           [[[LynkeosBasicAlignResult alloc] init] autorelease];

         // Beware, there is a y-flip between the bitmap and the screen
         res->_alignOffset.x= peak.x - r.origin.x + _rootParams->_alignOrigin.x;
         res->_alignOffset.y= -peak.y - r.origin.y +_rootParams->_alignOrigin.y;

         [item setProcessingParameter:res withRef:LynkeosAlignResultRef 
                        forProcessing:LynkeosAlignRef];
      }
      else
         [item setProcessingParameter:nil withRef:LynkeosAlignResultRef 
                        forProcessing:LynkeosAlignRef];
   }
}

- (void) finishProcessing
{
}
@end
