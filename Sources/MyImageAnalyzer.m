//
//  Lynkeos
//  $Id: MyImageAnalyzer.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Wed jun 6 2007.
//  Copyright (c) 2007-2008. Jean-Etienne LAMIAUD
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

#include "processing_core.h"
#include "MyImageAnalyzerPrefs.h"
#include "MyImageAnalyzer.h"
#include "LynkeosStandardImageBufferAdditions.h"

NSString * const myImageAnalyzerRef = @"MyImageAnalyzer";
NSString * const myImageAnalyzerParametersRef = @"AnalysisParams";
NSString * const myImageAnalyzerResultRef = @"AnalysisResult";

static NSString * const K_ANALYSIS_METHOD_KEY = @"analysmethod";
static NSString * const K_ANALYZE_RECT_KEY    = @"analysrect";
static NSString * const K_QUALITY_KEY         = @"quality";

@implementation MyImageAnalyzerParameters
- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _analysisRect = LynkeosMakeIntegerRect(0,0,0,0);
      _method = EntropyAnalysis;
      _lowerCutoff = 0.0;
      _upperCutoff = 0.0;
   }

   return( self );
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [encoder encodeRect:NSRectFromIntegerRect(_analysisRect)
                forKey:K_ANALYZE_RECT_KEY];
   [encoder encodeInt:_method forKey:K_ANALYSIS_METHOD_KEY];
}

- (id)initWithCoder:(NSCoder *)decoder
{
   if ( (self = [self init]) != nil )
   {
      if ( [decoder containsValueForKey:K_ANALYZE_RECT_KEY] )
         _analysisRect = LynkeosIntegerRectFromNSRect(
                                [decoder decodeRectForKey:K_ANALYZE_RECT_KEY]);
      _method = [decoder decodeIntForKey:K_ANALYSIS_METHOD_KEY];
   }

   return( self );
}
@end

@implementation MyImageAnalyzerResult
- (id) init
{
   if ( (self = [super init]) != nil )
      _quality = 0.0;

   return( self );
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [encoder encodeDouble:_quality forKey:K_QUALITY_KEY];
}

- (id)initWithCoder:(NSCoder *)decoder
{
   if ( (self = [self init]) != nil
        && [decoder containsValueForKey:K_QUALITY_KEY] )
      _quality = [decoder decodeDoubleForKey:K_QUALITY_KEY];

   return( self );
}

- (NSNumber*) quality { return( [NSNumber numberWithDouble:_quality]  ); }
@end

/*!
 * Evaluate the power spectrum quality
 */
static double quality( LynkeosFourierBuffer *spectrum, u_short down, u_short up )
{
   u_short x, y, c;
   double q = 0.0;
   u_long d2 = down*down, u2 = up*up;
   u_long n = 0;

   for( c = 0; c < spectrum->_nPlanes; c++ )
   {
      double lum = (__real__ colorComplexValue(spectrum,0,0,c))
      /(double)spectrum->_w/(double)spectrum->_h;
      double planeq = 0.0;

      for( y = 0; y < spectrum->_h; y++ )
      {
         for ( x = 0; x < spectrum->_halfw; x++ )
         {
            short dx = x, dy = y;
            u_long f2;
            if ( dy >= spectrum->_h/2 )
               dy -= spectrum->_h;
            f2 = dx*dx + dy*dy;
            if ( f2 > d2 && f2 < u2 )
            {
               COMPLEX s = colorComplexValue(spectrum,x,y,c);
               planeq += __real__ s * __real__ s + __imag__ s * __imag__ s;
               n++;
            }
         }
      }

      q += planeq / lum / lum;
   }

   return( q/(double)n );
}

static double entropy( LynkeosStandardImageBuffer *image, double *n )
{
   double v, e = 0, bmax = 0;
   u_short x, y, c;
   u_long nb = 0;

   // Compute the quadratic pixel sum
   for( c = 0; c < image->_nPlanes; c++ )
   {
      for( y = 0; y < image->_h; y++ )
      {
         for( x = 0; x < image->_w; x++ )
         {
            v = colorValue(image,x,y,c);
            if ( v > 0.0 )
               bmax += v*v;
         }
      }
   }

   bmax = sqrt(bmax);

   // Compute the entropy
   for( c = 0; c < image->_nPlanes; c++ )
   {
      for( y = 0; y < image->_h; y++ )
      {
         for( x = 0; x < image->_w; x++ )
         {
            double b = colorValue(image,x,y,c)/bmax;
            if ( b > 0.0 )
            {
               nb++;
               e -= b * log(b);
            }
         }
      }
   }
   *n = (double)nb;

   return( e );
}

@implementation MyImageAnalyzer
+ (ParallelOptimization_t) supportParallelization
{
   return( [[NSUserDefaults standardUserDefaults] integerForKey:
                                                      K_PREF_ANALYSIS_MULTIPROC]
           & ListThreadsOptimizations );
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
   _params = [params retain];

   _lowerCutoff = _params->_lowerCutoff*_params->_analysisRect.size.width;
   _upperCutoff = _params->_upperCutoff*_params->_analysisRect.size.width;

   // Allocate the buffer for each image
   if ( _params->_method == SpectrumAnalysis )
      _bufferSpectrum = [[LynkeosFourierBuffer fourierBufferWithNumberOfPlanes:1
                                       width:_params->_analysisRect.size.width
                                       height:_params->_analysisRect.size.height 
                                       withGoal: FOR_DIRECT] retain];
   else
      _bufferSpectrum = (LynkeosFourierBuffer*)
         [[LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:1 
                          width:_params->_analysisRect.size.width
                          height:_params->_analysisRect.size.height] retain];
   return( self );
}

- (void) dealloc
{
   if ( _bufferSpectrum != nil )
      [_bufferSpectrum release];
   [_params release];

   [super dealloc];
}

// As this processing is compiled in, only the compile precision is implemented
// (be lazy).
- (void) processItem:(id <LynkeosProcessableItem>)item
{
   LynkeosIntegerRect r = _params->_analysisRect;
   id <LynkeosAlignResult> aligned =
      (id <LynkeosAlignResult>)[item getProcessingParameterWithRef:
                                                         LynkeosAlignResultRef
                                                         forProcessing:
                                                               LynkeosAlignRef];
   LynkeosIntegerSize imageSize = [item imageSize];
   MyImageAnalyzerResult *res;
   double sqrt_n;

   // Take alignment into account
   if ( aligned != nil )
   {
      NSPoint p = [aligned offset];
      // Shift the crop rectangle in the opposite direction
      r.origin.x -= (int)(p.x+0.5);
      r.origin.y -= (int)(p.y+0.5);
   }

   // Convert from Cocoa to bitmap coordinates
   r.origin.y = imageSize.height - r.origin.y - r.size.height;

   // Get the sample in that image
   [item getImageSample:&_bufferSpectrum inRect:r];

   if ( _params->_method == SpectrumAnalysis )
      [_bufferSpectrum directTransform];

   // Analyze its quality
   res = [[[MyImageAnalyzerResult alloc] init] autorelease];
   switch ( _params->_method )
   {
      case SpectrumAnalysis:
         res->_quality = quality( _bufferSpectrum, _lowerCutoff, _upperCutoff );
         break;
      case EntropyAnalysis:
         // Maximum entropy of N pixels is sqrt(N)*log(sqrt(N))
         res->_quality = entropy(_bufferSpectrum, &sqrt_n);
         sqrt_n = sqrt(sqrt_n);
         res->_quality = (sqrt_n*log(sqrt_n) / res->_quality -  1.0) * 10.0;
         break;
      default:
         NSAssert(NO, @"Invalid analysis method");
   }

   // Save the result
   [item setProcessingParameter:res withRef:myImageAnalyzerResultRef 
                  forProcessing:myImageAnalyzerRef];
}

- (void) finishProcessing
{
}

@end
