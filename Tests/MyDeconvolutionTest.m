//
//  Lynkeos
//  $Id: MyDeconvolutionTest.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Wed Sep 3 2008.
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

#include "MyDeconvolutionTest.h"

#include "LynkeosProcessing.h"
#include "MyImageListItem.h"
#include "MyPluginsController.h"
#include "MyDeconvolution.h"
#include "LynkeosStandardImageBufferAdditions.h"

extern BOOL processTestInitialized;

// "Large" image processing for vectoring time measure
static void ProcessLargeDeconvolution( MyImageListItem *item )
{
   MyDeconvolutionParameters *param = [[MyDeconvolutionParameters alloc] init];

   param->_radius = 4.0;
   param->_threshold = 0.5;

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
   MyDeconvolution *proc = [[MyDeconvolution alloc] initWithDocument:nil
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
- (NSTimeInterval) testDuration;
@end



@implementation MyDeconvolutionTest
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

- (void) test_deconvolution_square
{
   MyDeconvolutionParameters *param = [[MyDeconvolutionParameters alloc] init];

   param->_radius = 4.0;
   param->_threshold = 0.5;

   // Create an item
   MyImageListItem *item = [[MyImageListItem alloc] initWithURL:
      [NSURL URLWithString:@"file:///image1.dir"]];

   // Process it
   MyDeconvolution *proc = [[MyDeconvolution alloc] initWithDocument:nil
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
         const double f2 = (y2 + x*x)/60.0/60.0;
         REAL expected = exp(-f2*M_PI*M_PI*16/M_LN2);
         if ( expected < 0.5 )
            expected = 2.0;
         else
            expected = 1.0/expected;
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

- (void) test_deconvolution_rect
{
   MyDeconvolutionParameters *param = [[MyDeconvolutionParameters alloc] init];

   param->_radius = 4.0;
   param->_threshold = 0.5;

   // Create an item
   MyImageListItem *item = [[MyImageListItem alloc] initWithURL:
      [NSURL URLWithString:@"file:///image1.dir"]];
   LynkeosStandardImageBuffer *img = nil;
   [item getImageSample:&img inRect:LynkeosMakeIntegerRect(0,0,60,40)];
   [item setImage:img];

   // Process it
   MyDeconvolution *proc = [[MyDeconvolution alloc] initWithDocument:nil
                                                      parameters:param
                                                       precision:PROCESSING_PRECISION];
   [proc processItem:item];
   [proc finishProcessing];

   // Check the result
   LynkeosFourierBuffer *buf = nil;
   [item getFourierTransform:&buf forRect:LynkeosMakeIntegerRect(0,0,60,40)
              prepareInverse:NO];
   u_short x, y;
   for( y = 0; y < 40; y++ )
   {
      double y2;
      if ( y < 20 )
         y2 = y*y;
      else
         y2 = (40-y)*(40-y);
      for( x = 0; x < 30; x++ )
      {
         const double f2 = y2/40.0/40.0 + x*x/60.0/60.0;
         REAL expected = exp(-f2*M_PI*M_PI*16/M_LN2);
         if ( expected < 0.5 )
            expected = 2.0;
         else
            expected = 1.0/expected;
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

- (void) test_deconvolution_with_vect
{
   if ( ! hasSIMD )
   {
      NSLog(@"This machine has no vector, skipping test_deconvolution_with_vect");
      return;
   }

   // Create an item
   MyImageListItem *item = [[MyImageListItem alloc] initWithURL:
      [NSURL URLWithString:@"file:///image1.dir"]];

   ProcessLargeDeconvolution(item);

   // Check the result
   LynkeosFourierBuffer *buf = nil;
   [item getFourierTransform:&buf forRect:LynkeosMakeIntegerRect(0,0,640,480)
              prepareInverse:NO];
   u_short x, y;
   for( y = 0; y < 480; y++ )
   {
      double y2;
      if ( y < 240 )
         y2 = (double)y*(double)y;
      else
         y2 = (480.0-y)*(480.0-y);
      for( x = 0; x < 320; x++ )
      {
         const double f2 = y2/480.0/480.0 + x*x/640.0/640.0;
         REAL expected = exp(-f2*M_PI*M_PI*16/M_LN2);
         if ( expected < 0.5 )
            expected = 2.0;
         else
            expected = 1.0/expected;
         COMPLEX v = colorComplexValue(buf,x,y,0);
         STAssertEqualsWithAccuracy( __real__ v, expected, 1e-2,
                                     @"Bad processed spectrum real part" );
         STAssertEqualsWithAccuracy( (double)(__imag__ v), 0.0, 1e-2,
                                     @"Bad processed spectrum imaginary part" );
      }
   }

   // Tidy up
   [item release];
}

- (void) test_deconvolution_without_vect
{
   u_char reallyHasSIMD = hasSIMD;
   hasSIMD = NO;

   // Create an item
   MyImageListItem *item = [[MyImageListItem alloc] initWithURL:
      [NSURL URLWithString:@"file:///image1.dir"]];

   ProcessLargeDeconvolution(item);

   // Check the result
   LynkeosFourierBuffer *buf = nil;
   [item getFourierTransform:&buf forRect:LynkeosMakeIntegerRect(0,0,640,480)
              prepareInverse:NO];
   u_short x, y;
   for( y = 0; y < 480; y++ )
   {
      double y2;
      if ( y < 240 )
         y2 = (double)y*(double)y;
      else
         y2 = (480.0-y)*(480.0-y);
      for( x = 0; x < 320; x++ )
      {
         const double f2 = y2/480.0/480.0 + x*x/640.0/640.0;
         REAL expected = exp(-f2*M_PI*M_PI*16/M_LN2);
         if ( expected < 0.5 )
            expected = 2.0;
         else
            expected = 1.0/expected;
         COMPLEX v = colorComplexValue(buf,x,y,0);
         STAssertEqualsWithAccuracy( __real__ v, expected, 1e-2,
                                     @"Bad processed spectrum real part" );
         STAssertEqualsWithAccuracy( (double)(__imag__ v), 0.0, 1e-2,
                                     @"Bad processed spectrum imaginary part" );
      }
   }

   // Tidy up
   [item release];

   hasSIMD = reallyHasSIMD;
}
@end
