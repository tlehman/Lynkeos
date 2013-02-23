//
//  Lynkeos
//  $Id: MyWaveletTest.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun Jun 22 2008.
//  Copyright (c) 2008. Jean-Etienne LAMIAUD
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

#include "MyWaveletTest.h"

#include "LynkeosProcessing.h"
#include "LynkeosStandardImageBufferAdditions.h"
#include "MyImageListItem.h"
#include "MyPluginsController.h"
#include "MyWavelet.h"

extern BOOL processTestInitialized;

static void ProcessLargeWavelet( MyImageListItem *item, wavelet_kind_t kind )
{
   MyWaveletParameters *param = [[MyWaveletParameters alloc] init];

   param->_waveletKind = kind;
   param->_numberOfWavelets = 3;
   param->_wavelet = (wavelet_t*)malloc( 3*sizeof(wavelet_t) );
   param->_wavelet[0]._frequency = 0.0;
   param->_wavelet[0]._weight = 0.0;
   param->_wavelet[1]._frequency = 0.35;
   param->_wavelet[1]._weight = 1.0;
   param->_wavelet[2]._frequency = 0.707;
   param->_wavelet[2]._weight = 0.0;

   // Place a somehow big Fourier buffer in it
   LynkeosFourierBuffer *buf = [[[LynkeosFourierBuffer alloc] initWithNumberOfPlanes:3
                                                                     width:640
                                                                    height:480
                                                            withGoal:FOR_INVERSE
                                                                isSpectrum:YES]
                                                                   autorelease];
   u_short x, y, c;
   for ( c = 0; c < 3; c++ )
      for( y = 0; y < 480; y++ )
         for( x = 0; x < 320; x++ )
            colorComplexValue(buf,x,y,c) = 1.0;
   [item setFourierTransform:buf];

   // Process it
   MyWavelet *proc = [[MyWavelet alloc] initWithDocument:nil
                                              parameters:param
                                               precision:PROCESSING_PRECISION];
   NSDate *start = [NSDate date];
   [proc processItem:item];
   NSLog( @"Processing time : %f seconds", -[start timeIntervalSinceNow] );
   [proc finishProcessing];

   [proc release];
   [param release];
}

// Fake reader
@interface TestDiracReader : NSObject <LynkeosImageFileReader>
{
   LynkeosStandardImageBuffer *_image;
}
@end

@implementation TestDiracReader
+ (void) lynkeosFileTypes:(NSArray**)fileTypes
{
   *fileTypes = [NSArray arrayWithObject:@"dir"];
}

- (id) init
{
   if ( (self = [super init]) != nil )
      _image = [[LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:1 
                                                      width:60
                                                     height:60] retain];

   return( self );
}

- (id) initWithURL:(NSURL*)url
{
   u_short x, y;

   if ( (self = [self init]) != nil )
   {
      // We want a constant spectrum, therefore, build a Dirac
      for( y = 0; y < 60; y++ )
         for( x = 0; x < 60; x++ )
            colorValue(_image,x,y,0) = ( x == 0 && y == 0 ? 1.0 : 0.0 );
   }

   return( self );
}

- (void) dealloc
{
   [_image release];
   [super dealloc];
}

- (u_short) numberOfPlanes
{
   return( [_image numberOfPlanes] );
}

- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax
{
   *vmin = 0.0;
   *vmax = 1.0;
}

- (void) imageWidth:(u_short*)w height:(u_short*)h
{
   *w = [_image width];
   *h = [_image height];
}

- (NSDictionary*) getMetaData { return( nil ); }
+ (BOOL) hasCustomImageBuffer { return( NO ); }
- (BOOL) canBeCalibratedBy:(id <LynkeosFileReader>)reader 
{ return( NO ); }

- (NSImage*) getNSImage{ return( nil ); }

- (void) getImageSample:(void * const * const)sample 
          withPrecision:(floating_precision_t)precision
             withPlanes:(u_short)nPlanes
                    atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
              lineWidth:(u_short)lineW ;
{
   NSAssert( precision == PROCESSING_PRECISION, @"Wrong precision in reader" );
   [_image extractSample:sample 
                     atX:x Y:y withWidth:w height:h
              withPlanes:nPlanes lineWidth:lineW];
}

- (id <LynkeosImageBuffer>) getCustomImageSampleAtX:(u_short)x Y:(u_short)y 
                                                  W:(u_short)w H:(u_short)h
{
   [self doesNotRecognizeSelector:_cmd];
   return( nil );
}
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

@implementation MyWaveletTest
+ (void) initialize
{
   if ( !processTestInitialized )
   {
      processTestInitialized = YES;
      // Initialize vector and multiprocessor stuff
      initializeProcessing();
      // Create the plugins controller singleton, and initialize it
      [[[MyPluginsController alloc] init] awakeFromNib];
   }
}

- (void) test_Sawtooth_Wavelet
{
   // Build a single sawtooth with 3 wavelets
   MyWaveletParameters *param = [[MyWaveletParameters alloc] init];

   param->_waveletKind = FrequencySawtooth_Wavelet;
   param->_numberOfWavelets = 3;
   param->_wavelet = (wavelet_t*)malloc( 3*sizeof(wavelet_t) );
   param->_wavelet[0]._frequency = 0.0;
   param->_wavelet[0]._weight = 0.0;
   param->_wavelet[1]._frequency = 0.35;
   param->_wavelet[1]._weight = 1.0;
   param->_wavelet[2]._frequency = 0.707;
   param->_wavelet[2]._weight = 0.0;

   // Create an item
   MyImageListItem *item = [[MyImageListItem alloc] initWithURL:
                                   [NSURL URLWithString:@"file:///image1.dir"]];

   // Process it
   MyWavelet *proc = [[MyWavelet alloc] initWithDocument:nil
                                              parameters:param
                                               precision:PROCESSING_PRECISION];

   [proc processItem:item];
   [proc finishProcessing];

   // Check the result
   LynkeosFourierBuffer *buf = nil;
   [item getFourierTransform:&buf forRect:LynkeosMakeIntegerRect(0,0,60,60)
              prepareInverse:NO];
   u_short x, y;
   for( y = 0; y < 60; y++ )
   {
      double y2;
      if ( y < 30 )
         y2 = y*y;
      else
         y2 = (60-y)*(60-y);
      for( x = 0; x < 30; x++ )
      {
         const double r = sqrt(y2 + x*x)/60.0;
         REAL expected;
         if ( r <= 0.35 )
            expected = r/0.35;
         else
            expected = (0.707-r)/(0.707-0.35);
         COMPLEX v = colorComplexValue(buf,x,y,0);
         STAssertEqualsWithAccuracy( __real__ v, expected, 1e-2,
                                     @"Bad processed spectrum real part" );
         STAssertEqualsWithAccuracy( (double)(__imag__ v), 0.0, 1e-2,
                                     @"Bad processed spectrum imaginary part" );
      }
   }

   // Tidy up
   [proc release];
   [param release];
   [item release];
}

- (void) test_ESO_Wavelet_0_5
{
   // Build a single sequence with 3 wavelets
   MyWaveletParameters *param = [[MyWaveletParameters alloc] init];

   param->_waveletKind = ESO_Wavelet;
   param->_numberOfWavelets = 3;
   param->_wavelet = (wavelet_t*)malloc( 3*sizeof(wavelet_t) );
   param->_wavelet[0]._frequency = 0.0;
   param->_wavelet[0]._weight = 0.0;
   param->_wavelet[1]._frequency = 0.25;
   param->_wavelet[1]._weight = 0.0;
   param->_wavelet[2]._frequency = 0.5;
   param->_wavelet[2]._weight = 1.0;

   // Create an item
   MyImageListItem *item = [[MyImageListItem alloc] initWithURL:
      [NSURL URLWithString:@"file:///image1.dir"]];

   // Process it
   MyWavelet *proc = [[MyWavelet alloc] initWithDocument:nil
                                              parameters:param
                                               precision:PROCESSING_PRECISION];

   [proc processItem:item];
   [proc finishProcessing];

   // Check the result
   // Expected image is 1 - g1/2
   LynkeosFourierBuffer *buf = nil;
   [item getFourierTransform:&buf forRect:LynkeosMakeIntegerRect(0,0,60,60)
              prepareInverse:NO];

   const double k = log(2)/param->_wavelet[2]._frequency
                          /param->_wavelet[2]._frequency;
   u_short x, y;
   for( y = 0; y < 60; y++ )
   {
      double y2;
      if ( y < 30 )
         y2 = y*y;
      else
         y2 = (60-y)*(60-y);
      for( x = 0; x < 30; x++ )
      {
         const double f2 = (y2 + x*x)/60.0/60.0;
         REAL expected = 1.0 - exp(-f2*k);
         COMPLEX v = colorComplexValue(buf,x,y,0);
         STAssertEqualsWithAccuracy( __real__ v, expected, 1e-2,
                                     @"Bad wavelet(0.5) spectrum real part" );
         STAssertEqualsWithAccuracy( (double)(__imag__ v), 0.0, 1e-2,
                                     @"Bad wavelet(0.5) spectrum imaginary part" );
      }
   }

   // Tidy up
   [proc release];
   [param release];
   [item release];
}

- (void) test_ESO_Wavelet_0_25
{
   // Build a single sequence with 3 wavelets
   MyWaveletParameters *param = [[MyWaveletParameters alloc] init];

   param->_waveletKind = ESO_Wavelet;
   param->_numberOfWavelets = 3;
   param->_wavelet = (wavelet_t*)malloc( 3*sizeof(wavelet_t) );
   param->_wavelet[0]._frequency = 0.0;
   param->_wavelet[0]._weight = 0.0;
   param->_wavelet[1]._frequency = 0.25;
   param->_wavelet[1]._weight = 1.0;
   param->_wavelet[2]._frequency = 0.5;
   param->_wavelet[2]._weight = 0.0;

   // Create an item
   MyImageListItem *item = [[MyImageListItem alloc] initWithURL:
      [NSURL URLWithString:@"file:///image1.dir"]];

   // Process it
   MyWavelet *proc = [[MyWavelet alloc] initWithDocument:nil
                                              parameters:param
                                               precision:PROCESSING_PRECISION];

   [proc processItem:item];
   [proc finishProcessing];

   // Check the result
   // Expected image is g1/2 - g1/4
   LynkeosFourierBuffer *buf = nil;
   [item getFourierTransform:&buf forRect:LynkeosMakeIntegerRect(0,0,60,60)
              prepareInverse:NO];

   const double k1 = log(2)/param->_wavelet[1]._frequency
                           /param->_wavelet[1]._frequency;
   const double k2 = log(2)/param->_wavelet[2]._frequency
                           /param->_wavelet[2]._frequency;
   u_short x, y;
   for( y = 0; y < 60; y++ )
   {
      double y2;
      if ( y < 30 )
         y2 = y*y;
      else
         y2 = (60-y)*(60-y);
      for( x = 0; x < 30; x++ )
      {
         const double f2 = (y2 + x*x)/60.0/60.0;
         REAL expected = exp(-f2*k2) - exp(-f2*k1);
         COMPLEX v = colorComplexValue(buf,x,y,0);
         STAssertEqualsWithAccuracy( __real__ v, expected, 1e-2,
                                     @"Bad wavelet(0.25) spectrum real part" );
         STAssertEqualsWithAccuracy( (double)(__imag__ v), 0.0, 1e-2,
                                     @"Bad wavelet(0.25) spectrum imaginary part" );
      }
   }

   // Tidy up
   [proc release];
   [param release];
   [item release];
}

- (void) test_Sawtooth_Wavelet_with_vect
{
   if ( ! hasSIMD )
   {
      NSLog( @"This machine has no vector, skipping test" );
      return;
   }

   // Create an item
   MyImageListItem *item = [[MyImageListItem alloc] initWithURL:
                                   [NSURL URLWithString:@"file:///image1.dir"]];

   // Process it
   ProcessLargeWavelet(item,FrequencySawtooth_Wavelet);

   // Check the result
   LynkeosFourierBuffer *buf = nil;
   [item getFourierTransform:&buf forRect:LynkeosMakeIntegerRect(0,0,640,480)
              prepareInverse:NO];

   u_short x, y, c;
   for( y = 0; y < 480; y++ )
   {
      double y2;
      if ( y < 240 )
         y2 = y*y;
      else
         y2 = (480-y)*(480-y);
      for( x = 0; x < 320; x++ )
      {
         const double r = sqrt(y2/480.0/480.0 + x*x/640.0/640.0);
         REAL expected;
         if ( r <= 0.35 )
            expected = r/0.35;
         else
            expected = (0.707-r)/(0.707-0.35);
         for( c = 0; c < 3; c++ )
         {
            COMPLEX v = colorComplexValue(buf,x,y,0);
            STAssertEqualsWithAccuracy( __real__ v, expected, 1e-2,
                      @"Bad processed spectrum real part at x=%d y=%d plane=%d",
                      x, y, c );
            STAssertEqualsWithAccuracy( (double)(__imag__ v), 0.0, 1e-2,
                 @"Bad processed spectrum imaginary part at x=%d y=%d plane=%d",
                 x, y, c);
         }
      }
   }

   // Tidy up
   [item release];
}

- (void) test_Sawtooth_Wavelet_without_vect
{
   u_char reallyHasSIMD = hasSIMD;
   hasSIMD = NO;

   // Create an item
   MyImageListItem *item = [[MyImageListItem alloc] initWithURL:
      [NSURL URLWithString:@"file:///image1.dir"]];

   // Process it
   ProcessLargeWavelet(item,FrequencySawtooth_Wavelet);

   // Check the result
   LynkeosFourierBuffer *buf = nil;
   [item getFourierTransform:&buf forRect:LynkeosMakeIntegerRect(0,0,640,480)
              prepareInverse:NO];

   u_short x, y, c;
   for( y = 0; y < 480; y++ )
   {
      double y2;
      if ( y < 240 )
         y2 = y*y;
      else
         y2 = (480-y)*(480-y);
      for( x = 0; x < 320; x++ )
      {
         const double r = sqrt(y2/480.0/480.0 + x*x/640.0/640.0);
         REAL expected;
         if ( r <= 0.35 )
            expected = r/0.35;
         else
            expected = (0.707-r)/(0.707-0.35);
         for( c = 0; c < 3; c++ )
         {
            COMPLEX v = colorComplexValue(buf,x,y,0);
            STAssertEqualsWithAccuracy( __real__ v, expected, 1e-2,
                                        @"Bad processed spectrum real part at x=%d y=%d plane=%d",
                                        x, y, c );
            STAssertEqualsWithAccuracy( (double)(__imag__ v), 0.0, 1e-2,
                                        @"Bad processed spectrum imaginary part at x=%d y=%d plane=%d",
                                        x, y, c);
         }
      }
   }

   // Tidy up
   [item release];
   hasSIMD = reallyHasSIMD;
}

- (void) test_ESO_Wavelet_with_vect
{
   if ( ! hasSIMD )
   {
      NSLog( @"This machine has no vector, skipping test" );
      return;
   }

   // Create an item
   MyImageListItem *item = [[MyImageListItem alloc] initWithURL:
                                   [NSURL URLWithString:@"file:///image1.dir"]];

   // Process it
   ProcessLargeWavelet(item,ESO_Wavelet);

   // Check the result
   LynkeosFourierBuffer *buf = nil;
   [item getFourierTransform:&buf forRect:LynkeosMakeIntegerRect(0,0,640,480)
              prepareInverse:NO];

   // Expected image is g0.707 - g0.35
   const double k1 = log(2)/0.35/0.35;
   const double k2 = log(2)/0.707/0.707;

   u_short x, y, c;
   for( y = 0; y < 480; y++ )
   {
      double y2;
      if ( y < 240 )
         y2 = y*y;
      else
         y2 = (480-y)*(480-y);
      for( x = 0; x < 320; x++ )
      {
         const double f2 = y2/480.0/480.0 + x*x/640.0/640.0;
         REAL expected = exp(-f2*k2) - exp(-f2*k1);
         for( c = 0; c < 3; c++ )
         {
            COMPLEX v = colorComplexValue(buf,x,y,0);
            STAssertEqualsWithAccuracy( __real__ v, expected, 1e-2,
                                        @"Bad processed spectrum real part at x=%d y=%d plane=%d",
                                        x, y, c );
            STAssertEqualsWithAccuracy( (double)(__imag__ v), 0.0, 1e-2,
                                        @"Bad processed spectrum imaginary part at x=%d y=%d plane=%d",
                                        x, y, c);
         }
      }
   }

   // Tidy up
   [item release];
}

- (void) test_ESO_Wavelet_without_vect
{
   u_char reallyHasSIMD = hasSIMD;
   hasSIMD = NO;

   // Create an item
   MyImageListItem *item = [[MyImageListItem alloc] initWithURL:
      [NSURL URLWithString:@"file:///image1.dir"]];

   // Process it
   ProcessLargeWavelet(item,ESO_Wavelet);

   // Check the result
   LynkeosFourierBuffer *buf = nil;
   [item getFourierTransform:&buf forRect:LynkeosMakeIntegerRect(0,0,640,480)
              prepareInverse:NO];

   // Expected image is g0.707 - g0.35
   const double k1 = log(2)/0.35/0.35;
   const double k2 = log(2)/0.707/0.707;

   u_short x, y, c;
   for( y = 0; y < 480; y++ )
   {
      double y2;
      if ( y < 240 )
         y2 = y*y;
      else
         y2 = (480-y)*(480-y);
      for( x = 0; x < 320; x++ )
      {
         const double f2 = y2/480.0/480.0 + x*x/640.0/640.0;
         REAL expected = exp(-f2*k2) - exp(-f2*k1);
         for( c = 0; c < 3; c++ )
         {
            COMPLEX v = colorComplexValue(buf,x,y,0);
            STAssertEqualsWithAccuracy( __real__ v, expected, 1e-2,
                                        @"Bad processed spectrum real part at x=%d y=%d plane=%d",
                                        x, y, c );
            STAssertEqualsWithAccuracy( (double)(__imag__ v), 0.0, 1e-2,
                                        @"Bad processed spectrum imaginary part at x=%d y=%d plane=%d",
                                        x, y, c);
         }
      }
   }

   // Tidy up
   [item release];
   hasSIMD = reallyHasSIMD;
}
@end
