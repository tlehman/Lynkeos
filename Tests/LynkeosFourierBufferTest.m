//
//  Lynkeos
//  $Id: LynkeosFourierBufferTest.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Sep 19 2008.
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

#include "processing_core.h"
#include <LynkeosCore/LynkeosFourierBuffer.h>
#include "LynkeosStandardImageBufferAdditions.h"

#import "LynkeosFourierBufferTest.h"

extern BOOL testInitialized;

@interface LynkeosFourierBufferTest(Utilities) ;
- (void) testMulWithVect:(BOOL)vect withThreads:(BOOL)thread ;
- (void) testScaleWithVect:(BOOL)vect withThreads:(BOOL)thread ;
- (void) testDivWithVect:(BOOL)vect withThreads:(BOOL)thread ;
- (void) testImageMulWithVect:(BOOL)vect withThreads:(BOOL)thread ;
- (void) testImageScaleWithVect:(BOOL)vect withThreads:(BOOL)thread ;
- (void) testImageDivWithVect:(BOOL)vect withThreads:(BOOL)thread ;
@end

@implementation LynkeosFourierBufferTest(Utilities)
- (void) testMulWithVect:(BOOL)vect withThreads:(BOOL)thread
{
   u_short x, y, c;
   BOOL reallyHasSIMD = hasSIMD;

   if ( vect )
   {
      if ( ! hasSIMD )
      {
         NSLog( @"This machine has no vector, skipping test" );
         return;
      }
   }
   else
      hasSIMD = NO;

   LynkeosFourierBuffer *spectrum1 =
        [[[LynkeosFourierBuffer alloc] initWithNumberOfPlanes:3
                                                        width:640
                                                       height:480
                                                     withGoal:0
                                                   isSpectrum:YES] autorelease];
   LynkeosFourierBuffer *spectrum2 =
        [[[LynkeosFourierBuffer alloc] initWithNumberOfPlanes:3
                                                        width:640
                                                       height:480
                                                     withGoal:0
                                                   isSpectrum:YES] autorelease];

   // Prepare the test spectrums
   for( y = 0; y < 480; y++ )
   {
      for( x = 0; x < 320; x++ )
      {
         for( c = 0; c < 3; c++ )
         {
            double a = M_PI*((x*480.0 + y)*3.0 + (REAL)c)/160.0/480.0/3.0 ;

            __real__ colorComplexValue(spectrum1,x,y,c) = cos(a);
            __imag__ colorComplexValue(spectrum1,x,y,c) = sin(a);
            __real__ colorComplexValue(spectrum2,x,y,c) = cos(2.0*M_PI-a);
            __imag__ colorComplexValue(spectrum2,x,y,c) = sin(2.0*M_PI-a);
         }
      }
   }

   if ( thread )
      [spectrum1 setOperatorsStrategy:ParallelizedStrategy];

   NSDate *start = [NSDate date];
   [spectrum1 multiplyWith:spectrum2 result:spectrum1];
   NSLog( @"Processing time %f", -[start timeIntervalSinceNow] );

   for( y = 0; y < 480; y++ )
   {
      for( x = 0; x < 320; x++ )
      {
         for( c = 0; c < 3; c++ )
         {
            COMPLEX v = colorComplexValue(spectrum1,x,y,c);

            STAssertEqualsWithAccuracy(__real__ v, (REAL)1.0, 1e-5, @"at %d,%d", x, y );
            STAssertEqualsWithAccuracy(__imag__ v, (REAL)0.0, 1e-5, @"at %d,%d", x, y );
         }
      }
   }

   if ( ! vect )
      hasSIMD = reallyHasSIMD;
}
- (void) testScaleWithVect:(BOOL)vect withThreads:(BOOL)thread
{
   u_short x, y, c;
   BOOL reallyHasSIMD = hasSIMD;

   if ( vect )
   {
      if ( ! hasSIMD )
      {
         NSLog( @"This machine has no vector, skipping test" );
         return;
      }
   }
   else
      hasSIMD = NO;

   LynkeosFourierBuffer *spectrum =
        [[[LynkeosFourierBuffer alloc] initWithNumberOfPlanes:3
                                                        width:640
                                                       height:480
                                                     withGoal:0
                                                   isSpectrum:YES] autorelease];
   // Prepare the test spectrum
   for( y = 0; y < 480; y++ )
      for( x = 0; x < 320; x++ )
         for( c = 0; c < 3; c++ )
         {
            double a = M_PI*((x*480.0 + y)*3.0 + (REAL)c)/160.0/480.0/3.0 ;

            __real__ colorComplexValue(spectrum,x,y,c) = cos(a);
            __imag__ colorComplexValue(spectrum,x,y,c) = sin(a);
         }

   if ( thread )
      [spectrum setOperatorsStrategy:ParallelizedStrategy];

   NSDate *start = [NSDate date];
   [spectrum multiplyWithScalar:2.0];
   NSLog( @"Processing time %f", -[start timeIntervalSinceNow] );

   for( y = 0; y < 480; y++ )
   {
      for( x = 0; x < 320; x++ )
      {
         for( c = 0; c < 3; c++ )
         {
            double a = M_PI*((x*480.0 + y)*3.0 + (REAL)c)/160.0/480.0/3.0 ;
            COMPLEX v = colorComplexValue(spectrum,x,y,c);

            STAssertEqualsWithAccuracy(__real__ v, (REAL)(2.0*cos(a)), 1e-5,
                                       @"at %d,%d", x, y );
            STAssertEqualsWithAccuracy(__imag__ v, (REAL)(2.0*sin(a)), 1e-5,
                                       @"at %d,%d", x, y );
         }
      }
   }

   if ( ! vect )
      hasSIMD = reallyHasSIMD;
}

- (void) testDivWithVect:(BOOL)vect withThreads:(BOOL)thread ;
{
   u_short x, y, c;
   BOOL reallyHasSIMD = hasSIMD;

   if ( vect )
   {
      if ( ! hasSIMD )
      {
         NSLog( @"This machine has no vector, skipping test" );
         return;
      }
   }
   else
      hasSIMD = NO;

   LynkeosFourierBuffer *spectrum1 =
        [[[LynkeosFourierBuffer alloc] initWithNumberOfPlanes:3
                                                        width:640
                                                       height:480
                                                     withGoal:0
                                                   isSpectrum:YES] autorelease];
   LynkeosFourierBuffer *spectrum2 =
        [[[LynkeosFourierBuffer alloc] initWithNumberOfPlanes:3
                                                        width:640
                                                       height:480
                                                     withGoal:0
                                                   isSpectrum:YES] autorelease];

   // Prepare the test spectrums
   for( y = 0; y < 480; y++ )
   {
      for( x = 0; x < 320; x++ )
      {
         for( c = 0; c < 3; c++ )
         {
            double a = M_PI*((x*480.0 + y)*3.0 + (REAL)c)/160.0/480.0/3.0 ;

            __real__ colorComplexValue(spectrum1,x,y,c) = cos(a);
            __imag__ colorComplexValue(spectrum1,x,y,c) = sin(a);
            __real__ colorComplexValue(spectrum2,x,y,c) = cos(2.0*M_PI-a);
            __imag__ colorComplexValue(spectrum2,x,y,c) = sin(2.0*M_PI-a);
         }
      }
   }

   if ( thread )
      [spectrum1 setOperatorsStrategy:ParallelizedStrategy];

   NSDate *start = [NSDate date];
   [spectrum1 divideBy:spectrum2 result:spectrum1];
   NSLog( @"Processing time %f", -[start timeIntervalSinceNow] );

   for( y = 0; y < 480; y++ )
   {
      for( x = 0; x < 320; x++ )
      {
         for( c = 0; c < 3; c++ )
         {
            double a = M_PI*((x*480.0 + y)*3.0 + (REAL)c)/160.0/480.0/3.0 ;
            COMPLEX v = colorComplexValue(spectrum1,x,y,c);

            STAssertEqualsWithAccuracy(__real__ v, (REAL)cos(2*a), 1e-5, @"at %d,%d", x, y );
            STAssertEqualsWithAccuracy(__imag__ v, (REAL)sin(2*a), 1e-5, @"at %d,%d", x, y );
         }
      }
   }

   if ( ! vect )
      hasSIMD = reallyHasSIMD;
}

- (void) testImageMulWithVect:(BOOL)vect withThreads:(BOOL)thread
{
   u_short x, y;
   BOOL reallyHasSIMD = hasSIMD;

   if ( vect )
   {
      if ( ! hasSIMD )
      {
         NSLog( @"This machine has no vector, skipping test" );
         return;
      }
   }
   else
      hasSIMD = NO;

   // Allocate our images
   // two in LynkeosStandardImageBuffer objects
   LynkeosStandardImageBuffer *image1 =
                 [LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:1 
                                                                     width:30
                                                                     height:20];
   LynkeosStandardImageBuffer *image2 =
   [LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:1 
                                                       width:30
                                                      height:20];

   // and the others in LynkeosFourierBuffer objects
   LynkeosFourierBuffer *spectrum1 =
          [[[LynkeosFourierBuffer alloc] initWithNumberOfPlanes:1
                                                          width:30
                                                         height:20
                                                       withGoal:0] autorelease];
   LynkeosFourierBuffer *spectrum2 =
          [[[LynkeosFourierBuffer alloc] initWithNumberOfPlanes:1
                                                          width:30
                                                         height:20
                                                       withGoal:0] autorelease];

   if ( thread )
   {
      [image1 setOperatorsStrategy:ParallelizedStrategy];
      [spectrum1 setOperatorsStrategy:ParallelizedStrategy];
   }

   // Initialise both kinds with the same contents
   for( y = 0; y < 20; y++ )
   {
      for( x = 0; x < 30; x++ )
      {
         colorValue(image1,x,y,0) = x/3.0 + y/20.0;
         colorValue(image2,x,y,0) = (30-x)/3.0 + (20-y)/20.0;
         colorValue(spectrum1,x,y,0) = x/3.0 + y/20.0;
         colorValue(spectrum2,x,y,0) = (30-x)/3.0 + (20-y)/20.0;
      }
   }

   // Perform the same operation on both kind
   [image1 multiplyWith:image2 result:image1];
   [spectrum1 multiplyWith:spectrum2 result:spectrum1];

   // Finally, verify both results are identical
   for( y = 0; y < 20; y++ )
   {
      for( x = 0; x < 30; x++ )
      {
         STAssertEqualsWithAccuracy(colorValue(image1,x,y,0),
                                    colorValue(spectrum1,x,y,0),
                                    1e-5, @"at %d,%d", x, y );
      }
   }

   if ( ! vect )
      hasSIMD = reallyHasSIMD;
}
- (void) testImageScaleWithVect:(BOOL)vect withThreads:(BOOL)thread
{
   u_short x, y;
   BOOL reallyHasSIMD = hasSIMD;

   if ( vect )
   {
      if ( ! hasSIMD )
      {
         NSLog( @"This machine has no vector, skipping test" );
         return;
      }
   }
   else
      hasSIMD = NO;

   // Allocate our images
   // one in a LynkeosStandardImageBuffer object
   LynkeosStandardImageBuffer *image =
                  [LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:1 
                                                                      width:30
                                                                     height:20];

   // and the other in a LynkeosFourierBuffer object
   LynkeosFourierBuffer *spectrum =
          [[[LynkeosFourierBuffer alloc] initWithNumberOfPlanes:1
                                                          width:30
                                                         height:20
                                                       withGoal:0] autorelease];

   if ( thread )
   {
      [image setOperatorsStrategy:ParallelizedStrategy];
      [spectrum setOperatorsStrategy:ParallelizedStrategy];
   }

   // Initialise both kinds with the same contents
   for( y = 0; y < 20; y++ )
   {
      for( x = 0; x < 30; x++ )
      {
         colorValue(image,x,y,0) = x/3.0 + y/20.0;
         colorValue(spectrum,x,y,0) = x/3.0 + y/20.0;
      }
   }

   // Perform the same operation on both kind
   [image multiplyWithScalar:3.0];
   [spectrum multiplyWithScalar:3.0];

   // Finally, verify both results are identical
   for( y = 0; y < 20; y++ )
   {
      for( x = 0; x < 30; x++ )
      {
         STAssertEqualsWithAccuracy(colorValue(image,x,y,0),
                                    colorValue(spectrum,x,y,0),
                                    1e-5, @"at %d,%d", x, y );
      }
   }

   if ( ! vect )
      hasSIMD = reallyHasSIMD;
}

- (void) testImageDivWithVect:(BOOL)vect withThreads:(BOOL)thread
{
   u_short x, y;
   BOOL reallyHasSIMD = hasSIMD;

   if ( vect )
   {
      if ( ! hasSIMD )
      {
         NSLog( @"This machine has no vector, skipping test" );
         return;
      }
   }
   else
      hasSIMD = NO;

   // Allocate our images
   // two in LynkeosStandardImageBuffer objects
   LynkeosStandardImageBuffer *image1 =
                  [LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:1 
                                                                      width:30
                                                                     height:20];
   LynkeosStandardImageBuffer *image2 =
                  [LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:1 
                                                                      width:30
                                                                     height:20];

   // and the others in LynkeosFourierBuffer objects
   LynkeosFourierBuffer *spectrum1 =
          [[[LynkeosFourierBuffer alloc] initWithNumberOfPlanes:1
                                                          width:30
                                                         height:20
                                                       withGoal:0] autorelease];
   LynkeosFourierBuffer *spectrum2 =
          [[[LynkeosFourierBuffer alloc] initWithNumberOfPlanes:1
                                                          width:30
                                                         height:20
                                                       withGoal:0] autorelease];

   if ( thread )
   {
      [image1 setOperatorsStrategy:ParallelizedStrategy];
      [spectrum1 setOperatorsStrategy:ParallelizedStrategy];
   }

   // Initialise both kinds with the same contents
   for( y = 0; y < 20; y++ )
   {
      for( x = 0; x < 30; x++ )
      {
         colorValue(image1,x,y,0) = x/3.0 + y/20.0;
         colorValue(image2,x,y,0) = (30-x)/3.0 + (20-y)/20.0;
         colorValue(spectrum1,x,y,0) = x/3.0 + y/20.0;
         colorValue(spectrum2,x,y,0) = (30-x)/3.0 + (20-y)/20.0;
      }
   }

   // Perform the same operation on both kind
   [image1 divideBy:image2 result:image1];
   [spectrum1 divideBy:spectrum2 result:spectrum1];

   // Finally, verify both results are identical
   for( y = 0; y < 20; y++ )
   {
      for( x = 0; x < 30; x++ )
      {
         STAssertEqualsWithAccuracy(colorValue(image1,x,y,0),
                                    colorValue(spectrum1,x,y,0),
                                    1e-5, @"at %d,%d", x, y );
      }
   }

   if ( ! vect )
      hasSIMD = reallyHasSIMD;
}
@end

@implementation LynkeosFourierBufferTest
+ (void) initialize
{
   if ( !testInitialized )
   {
      testInitialized = YES;
      // Initialize vector and multiprocessor stuff
      initializeProcessing();
   }
}

- (void) testMul_noVect_noThread
{
   [self testMulWithVect:NO withThreads:NO];
}

- (void) testMul_Vect_noThread
{
   [self testMulWithVect:YES withThreads:NO];
}

- (void) testMul_noVect_Thread
{
   [self testMulWithVect:NO withThreads:YES];
}

- (void) testMul_Vect_Thread
{
   [self testMulWithVect:YES withThreads:YES];
}

- (void) testDiv_noVect_noThread
{
   [self testDivWithVect:NO withThreads:NO];
}

- (void) testDiv_noVect_withThread
{
   [self testDivWithVect:NO withThreads:YES];
}

- (void) testDiv_withVect_noThread
{
   [self testDivWithVect:YES withThreads:NO];
}

- (void) testDiv_withVect_withThread
{
   [self testDivWithVect:YES withThreads:YES];
}

- (void) testScale_noVect_noThread
{
   [self testScaleWithVect:NO withThreads:NO];
}

- (void) testScale_noVect_withThread
{
   [self testScaleWithVect:NO withThreads:YES];
}

- (void) testScale_withVect_noThread
{
   [self testScaleWithVect:YES withThreads:NO];
}

- (void) testScale_withVect_withThread
{
   [self testScaleWithVect:YES withThreads:YES];
}

- (void) testImageMul_noVect_noThread
{
   [self testImageMulWithVect:NO withThreads:NO];
}

- (void) testImageMul_Vect_noThread
{
   [self testImageMulWithVect:YES withThreads:NO];
}

- (void) testImageMul_noVect_Thread
{
   [self testImageMulWithVect:NO withThreads:YES];
}

- (void) testImageMul_Vect_Thread
{
   [self testImageMulWithVect:YES withThreads:YES];
}

- (void) testImageScale_noVect_noThread
{
   [self testImageScaleWithVect:NO withThreads:NO];
}

- (void) testImageScale_noVect_withThread
{
   [self testImageScaleWithVect:NO withThreads:YES];
}

- (void) testImageScale_withVect_noThread
{
   [self testImageScaleWithVect:YES withThreads:NO];
}

- (void) testImageScale_withVect_withThread
{
   [self testImageScaleWithVect:YES withThreads:YES];
}

- (void) testImageDiv_noVect_noThread
{
   [self testImageDivWithVect:NO withThreads:NO];
}

- (void) testImageDiv_noVect_withThread
{
   [self testImageDivWithVect:NO withThreads:YES];
}

- (void) testImageDiv_withVect_noThread
{
   [self testImageDivWithVect:YES withThreads:NO];
}

- (void) testImageDiv_withVect_withThread
{
   [self testImageDivWithVect:YES withThreads:YES];
}
@end
