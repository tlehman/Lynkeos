//
//  Lynkeos
//  $Id: MyImageAlignerTest.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Sep 29 2006.
//  Copyright (c) 2006-2008. Jean-Etienne LAMIAUD
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

#include "LynkeosProcessing.h"
#include "MyPluginsController.h"
#include "LynkeosThreadConnection.h"
#include "MyProcessingThread.h"
#include "MyImageAligner.h"
#include "LynkeosStandardImageBuffer.h"
#include "LynkeosStandardImageBufferAdditions.h"
#include "MyDocument.h"

#include "MyImageAlignerTest.h"

BOOL processTestInitialized = NO;

NSString * const K_PREF_END_PROCESS_SOUND = @"End of processing sound";
NSString * const K_PREF_ALIGN_MULTIPROC = @"Multiprocessor align";
NSString * const K_PREF_ALIGN_CHECK = @"Align check";

// Notification flag
NSString *K_ITEM_ALIGNED_REF = @"ItemAlignedFlag";
@interface ItemAlignedFlag : NSObject <LynkeosProcessingParameter>
{
@public
   BOOL aligned;
}
@end

// Notification observer shall be separate from the test class
@interface TestObserver :NSObject
{
@public
   BOOL alignStarted;
   BOOL alignDone;
}
- (void) alignStarted:(NSNotification*)notif ;
- (void) itemAligned:(NSNotification*)notif ;
- (void) alignEnded:(NSNotification*)notif ;
@end

// Fake reader
@interface TestReader : NSObject <LynkeosImageFileReader>
{
   LynkeosStandardImageBuffer *_image;
}
@end

// A fake cache prefs class
@interface MyCachePrefs : NSObject
@end

@implementation MyCachePrefs
@end

// Fake window controller
@interface MyImageListWindow : NSObject
@end

@implementation MyImageListWindow
@end

@implementation ItemAlignedFlag : NSObject
- (void)encodeWithCoder:(NSCoder *)encoder
{ [self doesNotRecognizeSelector:_cmd]; }
- (id) initWithCoder:(NSCoder *)decoder
{
   [self doesNotRecognizeSelector:_cmd];
   return( nil );
}
@end

@implementation TestObserver
- (id) init
{
   if ( (self = [super init]) != nil )
   {
      alignStarted = NO;
      alignDone = NO;
   }
   return( self );
}

- (void) alignStarted:(NSNotification*)notif
{
   alignStarted = YES;
}

- (void) itemAligned:(NSNotification*)notif
{
   MyImageListItem *item = [[notif userInfo] objectForKey:LynkeosUserInfoItem];

   // We will receive a notification for our own setProcessingParameter
   // Therefore, don't repeat it if it's done
   if ( [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                              forProcessing:nil] == nil )
   {
      ItemAlignedFlag *param = [[ItemAlignedFlag alloc] init];

      param->aligned = YES;
      [item setProcessingParameter:param withRef:K_ITEM_ALIGNED_REF
                     forProcessing:nil];
   }
}

- (void) alignEnded:(NSNotification*)notif
{
   alignDone = YES;
}
@end

@implementation TestReader
+ (void) lynkeosFileTypes:(NSArray**)fileTypes
{
   *fileTypes = [NSArray arrayWithObject:@"tst"];
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
   if ( (self = [self init]) != nil )
   {
      u_short x, y;
      double dx, dy;
      if ( [[url path] isEqual:@"/image1.tst"] )
         { dx = 15.0; dy = 15.0; }
      else if ( [[url path] isEqual:@"/image2.tst"] )
         { dx = 15.25; dy = 15.0; }
      else if ( [[url path] isEqual:@"/image3.tst"] )
         { dx = 15.0; dy = 15.5; }
      else if ( [[url path] isEqual:@"/image4.tst"] )
         { dx = 14.0; dy = 14.0; }
      else if ( [[url path] isEqual:@"/image5.tst"] )
         { dx = 35.0; dy = 35.0; }
      else if ( [[url path] isEqual:@"/image6.tst"] )
         { dx = 15.0; dy = 35.0; }
      else if ( [[url path] isEqual:@"/image7.tst"] )
         { dx = 35.0; dy = 15.0; }

      // Build a pseudo star
      for( y = 0; y < 60; y++ )
      {
         for( x = 0; x < 60; x++ )
         {
            colorValue(_image,x,y,0) = exp( -(((double)x-dx)*((double)x-dx)
                                              +((double)y-dy)*((double)y-dy))
                                            /2.0 );
         }
      }
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

@implementation MyImageAlignerTest
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

- (void) testAlign_0_025_050_1
{
   // Create the document
   MyDocument *doc = [[MyDocument alloc] init];

   // Prepare the parameters
   MyImageAlignerListParameters *listParams = 
                                    [[MyImageAlignerListParameters alloc] init];
   listParams->_referenceItem = [[MyImageListItem alloc] initWithURL:
                                   [NSURL URLWithString:@"file:///image1.tst"]];
   listParams->_alignOrigin = LynkeosMakeIntegerPoint(11,42);
   listParams->_alignSize = LynkeosMakeIntegerSize(7,7);
   listParams->_cutoff = 0.707;
   listParams->_precisionThreshold = 0.125;
   listParams->_checkAlignResult = NO;
   listParams->_refSpectrumLock = [[NSLock alloc] init];
   listParams->_referenceSpectrum = nil;

   // Add all the items to the document
   [doc addEntry:(MyImageListItem*)listParams->_referenceItem];
   [doc addEntry:[[MyImageListItem alloc] initWithURL:
                                  [NSURL URLWithString:@"file:///image2.tst"]]];
   [doc addEntry:[[MyImageListItem alloc] initWithURL:
                                  [NSURL URLWithString:@"file:///image3.tst"]]];
   MyImageListItem *item = [[MyImageListItem alloc] initWithURL:
                                   [NSURL URLWithString:@"file:///image4.tst"]];
   [item setSelected:NO];
   [doc addEntry:item];
   [doc addEntry:[[MyImageListItem alloc] initWithURL:
                                  [NSURL URLWithString:@"file:///image4.tst"]]];

   // Set the parameters in the list
   [[doc imageList] setProcessingParameter:listParams
                                   withRef:myImageAlignerParametersRef
                             forProcessing:myImageAlignerRef];

   // Register for doc notifications
   TestObserver *obs = [[TestObserver alloc] init];
   [[NSNotificationCenter defaultCenter] addObserver:obs
                                            selector:@selector(alignStarted:)
                                                name:
                                             LynkeosProcessStartedNotification
                                              object:doc];
   [[NSNotificationCenter defaultCenter] addObserver:obs
                                            selector:@selector(itemAligned:)
                                                name:
                                             LynkeosItemChangedNotification
                                              object:doc];
   [[NSNotificationCenter defaultCenter] addObserver:obs
                                            selector:@selector(alignEnded:)
                                                name:
                                             LynkeosProcessEndedNotification
                                              object:doc];

   obs->alignDone = NO;

   // Get an enumerator on the images
   NSEnumerator *strider =[[doc imageList] imageEnumeratorStartAt:nil
                                                       directSense:YES
                                                    skipUnselected:YES];

   // Ask the doc to align
   [doc startProcess:[MyImageAligner class] withEnumerator:strider
          parameters:listParams];

   // Wait for process end
   NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:2.0];
   while ( [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                    beforeDate:timeout]
           && [timeout compare:[NSDate date]] == NSOrderedDescending
           && ! obs->alignDone )
      ;

   // Verify the results
   STAssertTrue( obs->alignStarted, @"No notification of align start" );
   STAssertTrue( obs->alignDone, @"Align not performed after delay" );

   strider = [[doc imageList] imageEnumerator];

   // First item
   item = [strider nextObject];

   ItemAlignedFlag *alignFlag =
                          [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                                                forProcessing:nil];
   STAssertNotNil( alignFlag, @"No notification flag for item 0" );
   if ( alignFlag != nil )
      STAssertTrue( alignFlag->aligned, @"Bad notification flag state for item 0" );

   id <LynkeosAlignResult> res =
      (id <LynkeosAlignResult>)[item getProcessingParameterWithRef:
                                                         LynkeosAlignResultRef
                                                     forProcessing:
                                                        LynkeosAlignRef];
   STAssertNotNil( res, @"No alignment result for item 0" );
   if ( res != nil )
   {
      STAssertEqualsWithAccuracy( (double)[res offset].x, 0.0, 1e-2,
                                  @"x item 0" );
      STAssertEqualsWithAccuracy( (double)[res offset].y, 0.0, 1e-2,
                                  @"y item 0" );
   }

   // Second item
   item = [strider nextObject];

   alignFlag = [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                                     forProcessing:nil];
   STAssertNotNil( alignFlag, @"No notification flag for item 1" );
   if ( alignFlag != nil )
      STAssertTrue( alignFlag->aligned, @"Bad notification flag state for item 1" );

   res = (id <LynkeosAlignResult>)
                       [item getProcessingParameterWithRef:LynkeosAlignResultRef
                                             forProcessing:LynkeosAlignRef];
   STAssertNotNil( res, @"No alignment result for item 1" );
   if ( res != nil )
   {
      STAssertEqualsWithAccuracy( (double)[res offset].x, -0.25, 1e-2,
                                  @"x item 1" );
      STAssertEqualsWithAccuracy( (double)[res offset].y, 0.0, 1e-2,
                                  @"y item 1" );
   }

   // Third item
   item = [strider nextObject];

   alignFlag = [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                                     forProcessing:nil];
   STAssertNotNil( alignFlag, @"No notification flag for item 2" );
   if ( alignFlag != nil )
      STAssertTrue( alignFlag->aligned, @"Bad notification flag state for item 2" );

   res = (id <LynkeosAlignResult>)
                       [item getProcessingParameterWithRef:LynkeosAlignResultRef
                                             forProcessing:LynkeosAlignRef];
   STAssertNotNil( res, @"No alignment result for item 2" );
   if ( res != nil )
   {
      STAssertEqualsWithAccuracy( (double)[res offset].x, 0.0, 1e-2,
                                  @"x item 2" );
      STAssertEqualsWithAccuracy( (double)[res offset].y, 0.5, 1e-2,
                                  @"y item 2" );
   }

   // Fourth item (not selected)
   item = [strider nextObject];

   alignFlag = [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                                     forProcessing:nil];
   STAssertNil( alignFlag, @"No notification flag for item 3" );

   res = (id <LynkeosAlignResult>)
                       [item getProcessingParameterWithRef:LynkeosAlignResultRef
                                             forProcessing:LynkeosAlignRef];
   STAssertNil( res, @"Unexpected alignment result for item 3" );

   // Fifth and last item
   item = [strider nextObject];

   alignFlag = [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                                     forProcessing:nil];
   STAssertNotNil( alignFlag, @"No notification flag for item 4" );
   if ( alignFlag != nil )
      STAssertTrue( alignFlag->aligned, @"Bad notification flag state for item 4" );

   res = (id <LynkeosAlignResult>)
                       [item getProcessingParameterWithRef:LynkeosAlignResultRef
                                             forProcessing:LynkeosAlignRef];
   STAssertNotNil( res, @"No alignment result for item 4" );
   if ( res != nil )
   {
      STAssertEqualsWithAccuracy( (double)[res offset].x, 1.0, 1e-2,
                                  @"x item 4" );
      STAssertEqualsWithAccuracy( (double)[res offset].y, -1.0, 1e-2,
                                  @"y item 4" );
   }

   [[NSNotificationCenter defaultCenter] removeObserver:obs];
   [obs release];
   [doc release];
}

// Verify offset greater than half size
- (void) testSpuriousAlign
{
   // Create the document
   MyDocument *doc = [[MyDocument alloc] init];

   // Prepare the parameters
   MyImageAlignerListParameters *listParams = 
                                    [[MyImageAlignerListParameters alloc] init];
   listParams->_referenceItem = [[MyImageListItem alloc] initWithURL:
                                   [NSURL URLWithString:@"file:///image1.tst"]];
   listParams->_alignOrigin = LynkeosMakeIntegerPoint(10,20);
   listParams->_alignSize = LynkeosMakeIntegerSize(30,30);
   listParams->_cutoff = 0.707;
   listParams->_precisionThreshold = 0.125;
   listParams->_checkAlignResult = YES;
   listParams->_refSpectrumLock = [[NSLock alloc] init];
   listParams->_referenceSpectrum = nil;

   // Add all the items to the document
   [doc addEntry:(MyImageListItem*)listParams->_referenceItem];
   [doc addEntry:[[MyImageListItem alloc] initWithURL:
                                  [NSURL URLWithString:@"file:///image5.tst"]]];
   [doc addEntry:[[MyImageListItem alloc] initWithURL:
                                  [NSURL URLWithString:@"file:///image6.tst"]]];
   [doc addEntry:[[MyImageListItem alloc] initWithURL:
                                  [NSURL URLWithString:@"file:///image7.tst"]]];

   // Set the parameters in the list
   [[doc imageList] setProcessingParameter:listParams
                                   withRef:myImageAlignerParametersRef
                             forProcessing:myImageAlignerRef];

   // Register for doc notifications
   TestObserver *obs = [[TestObserver alloc] init];
   [[NSNotificationCenter defaultCenter] addObserver:obs
                                            selector:@selector(alignStarted:)
                                                name:
                                               LynkeosProcessStartedNotification
                                              object:doc];
   [[NSNotificationCenter defaultCenter] addObserver:obs
                                            selector:@selector(itemAligned:)
                                                name:
                                                  LynkeosItemChangedNotification
                                              object:doc];
   [[NSNotificationCenter defaultCenter] addObserver:obs
                                            selector:@selector(alignEnded:)
                                                name:
                                                 LynkeosProcessEndedNotification
                                              object:doc];

   obs->alignDone = NO;

   // Get an enumerator on the images
   NSEnumerator *strider =[[doc imageList] imageEnumeratorStartAt:nil
                                                      directSense:YES
                                                   skipUnselected:YES];

   // Ask the doc to align
   [doc startProcess:[MyImageAligner class] withEnumerator:strider
          parameters:listParams];

   // Wait for process end
   NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:2.0];
   while ( [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                    beforeDate:timeout]
           && [timeout compare:[NSDate date]] == NSOrderedDescending
           && ! obs->alignDone )
      ;

   // Verify the results
   STAssertTrue( obs->alignStarted, @"No notification of align start" );
   STAssertTrue( obs->alignDone, @"Align not performed after delay" );

   strider = [[doc imageList] imageEnumerator];

   // First item
   MyImageListItem *item = [strider nextObject];

   ItemAlignedFlag *alignFlag =
      [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                            forProcessing:nil];
   STAssertNotNil( alignFlag, @"No notification flag for item 0" );
   if ( alignFlag != nil )
      STAssertTrue( alignFlag->aligned,
                    @"Bad notification flag state for item 0" );

   id <LynkeosAlignResult> res =
      (id <LynkeosAlignResult>)[item getProcessingParameterWithRef:
                                                         LynkeosAlignResultRef
                                                     forProcessing:
                                                             LynkeosAlignRef];
   STAssertNotNil( res, @"No alignment result for item 0" );
   if ( res != nil )
   {
      STAssertEqualsWithAccuracy( (double)[res offset].x, 0.0, 1e-2,
                                  @"x item 0" );
      STAssertEqualsWithAccuracy( (double)[res offset].y, 0.0, 1e-2,
                                  @"y item 0" );
   }

   // Second item
   item = [strider nextObject];

   alignFlag = [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                                     forProcessing:nil];
   STAssertNotNil( alignFlag, @"No notification flag for item 1" );
   if ( alignFlag != nil )
      STAssertTrue( alignFlag->aligned,
                    @"Bad notification flag state for item 1" );

   res = (id <LynkeosAlignResult>)
                       [item getProcessingParameterWithRef:LynkeosAlignResultRef
                                             forProcessing:LynkeosAlignRef];
   STAssertNotNil( res, @"No alignment result for item 1" );
   if ( res != nil )
   {
      STAssertEqualsWithAccuracy( (double)[res offset].x, -20.0, 1e-2,
                                  @"x item 1" );
      STAssertEqualsWithAccuracy( (double)[res offset].y, 20.0, 1e-2,
                                  @"y item 1" );
   }

   // Third item
   item = [strider nextObject];

   alignFlag = [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                                     forProcessing:nil];
   STAssertNotNil( alignFlag, @"No notification flag for item 2" );
   if ( alignFlag != nil )
      STAssertTrue( alignFlag->aligned,
                    @"Bad notification flag state for item 2" );

   res = (id <LynkeosAlignResult>)
                       [item getProcessingParameterWithRef:LynkeosAlignResultRef
                                             forProcessing:LynkeosAlignRef];
   STAssertNotNil( res, @"No alignment result for item 2" );
   if ( res != nil )
   {
      STAssertEqualsWithAccuracy( (double)[res offset].x, 0.0, 1e-2,
                                  @"x item 2" );
      STAssertEqualsWithAccuracy( (double)[res offset].y, 20.0, 1e-2,
                                  @"y item 2" );
   }

   // Fourth and last item
   item = [strider nextObject];

   alignFlag = [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                                     forProcessing:nil];
   STAssertNotNil( alignFlag, @"No notification flag for item 3" );
   if ( alignFlag != nil )
      STAssertTrue( alignFlag->aligned,
                    @"Bad notification flag state for item 3" );

   res = (id <LynkeosAlignResult>)
                       [item getProcessingParameterWithRef:LynkeosAlignResultRef
                                             forProcessing:LynkeosAlignRef];
   STAssertNotNil( res, @"No alignment result for item 3" );
   if ( res != nil )
   {
      STAssertEqualsWithAccuracy( (double)[res offset].x, -20.0, 1e-2,
                                  @"x item 3" );
      STAssertEqualsWithAccuracy( (double)[res offset].y, -0.0, 1e-2,
                                  @"y item 3" );
   }

   [[NSNotificationCenter defaultCenter] removeObserver:obs];
   [obs release];
   [doc release];
}
@end
