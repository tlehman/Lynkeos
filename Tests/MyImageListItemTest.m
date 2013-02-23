//
//  Lynkeos
//  $Id: MyImageListItemTest.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Thu Sep 7 2006.
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

#import "MyImageListItemTest.h"

#include "LynkeosStandardImageBufferAdditions.h"
#include "MyPluginsController.h"
#include "LynkeosFileReader.h"
#include "MyImageListItem.h"

BOOL pluginsInitialized = NO;

NSString *basePath = nil;

// ============================================================================
// The reader that the item under test will use
@interface TestReader : NSObject <LynkeosImageFileReader>
{
   LynkeosStandardImageBuffer *buf;
}
// Test specific method
- (id) initWithImage:(LynkeosStandardImageBuffer*)image ;
@end

@implementation TestReader
+ (void) load {}

+ (void) lynkeosFileTypes:(NSArray**)fileTypes
{ *fileTypes = [NSArray arrayWithObject:@"tsturl"]; }

- (id) initWithURL:(NSURL*)url
{
   u_short x, y;
   LynkeosStandardImageBuffer *im = [LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:3
                                                             width:31
                                                            height:19];
   for( y = 0; y < 19; y++ )
   {
      for( x = 0; x < 31; x++ )
      {
         colorValue(im,x,y,0) = x/31.0;
         colorValue(im,x,y,1) = y/19.0;
         colorValue(im,x,y,2) = ((x+y)%10)/10.0;
      }
   }

   return [self initWithImage:im];
}

- (id) initWithImage:(LynkeosStandardImageBuffer*)image
{
   self = [super init];

   if ( self != nil )
   {
      buf = [image retain];
   }

   return self;
}

- (void) imageWidth:(u_short*)w height:(u_short*)h
{ *w = buf->_w; *h = buf->_h; }

- (u_short) numberOfPlanes { return( buf->_nPlanes ); }

- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax
{
   *vmin = 0.0;
   *vmax = 1.0;
}

- (NSDictionary*) getMetaData { return nil; }

+ (BOOL) hasCustomImageBuffer { return NO; }

- (BOOL) canBeCalibratedBy:(id <LynkeosFileReader>)reader
{
   return( [reader isMemberOfClass:[self class]]
           && ((TestReader*)reader)->buf->_w == buf->_w
           && ((TestReader*)reader)->buf->_h == buf->_h
           && ((TestReader*)reader)->buf->_nPlanes == buf->_nPlanes );
}

- (NSImage*) getNSImage
{
   NSImage *image = [[NSImage alloc] initWithSize:
                     NSSizeFromIntegerSize(LynkeosMakeIntegerSize(buf->_w,buf->_h))];
   double black[] = {0.0, 0.0, 0.0, 0.0 },
          white[] = {1.0, 1.0, 1.0, 1.0},
          gamma[] = {1.0, 1.0, 1.0, 1.0};

   if ( image != nil )
      [image addRepresentation:[buf getNSImageWithBlack:black white:white
                                                  gamma:gamma]];

   return( image );
}

- (void) getImageSample:(void * const * const)sample 
          withPrecision:(floating_precision_t)precision
             withPlanes:(u_short)nPlanes
                    atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
              lineWidth:(u_short)lineW
{
   NSAssert( precision == PROCESSING_PRECISION, @"Inconsistent precision" );
   NSAssert4( x < buf->_w && x+w <= buf->_w && y < buf->_h && y+h <= buf->_h,
                 @"Rectangle outside the image {%d,%d,%d,%d}",
                 x, y, w, h );
   [buf extractSample:sample atX:x Y:y withWidth:w height:h
           withPlanes:nPlanes lineWidth:lineW];
}

- (id <LynkeosImageBuffer>) getCustomImageSampleAtX:(u_short)x Y:(u_short)y 
                                                  W:(u_short)w H:(u_short)h
{ NSAssert( NO, @"getCustomImageSample was called"); return( nil ); }
@end

// A fake cache prefs class
@interface MyCachePrefs : NSObject
@end

@implementation MyCachePrefs
@end

// ============================================================================
// The tests
@implementation MyImageListItemTest

+ (void) initialize
{
   // Create the plugins controller singleton, and initialize it
   // Only if not already done by another test class
   if ( !pluginsInitialized )
   {
      [[[MyPluginsController alloc] init] awakeFromNib];
      pluginsInitialized = YES;
   }
}

- (void) testSimpleRead
{
   // Create an item
   MyImageListItem *item = [MyImageListItem imageListItemWithURL:
                                             [NSURL URLWithString:@"1.tsturl"]];

   // Read a sample
   LynkeosStandardImageBuffer *testBuf = nil;
   [item getImageSample:&testBuf inRect:LynkeosMakeIntegerRect(10,5,10,10)];

   STAssertNotNil( testBuf, @"Test image not read" );

   u_short x, y;
   for( y = 0; y < 5; y++ )
   {
      for( x = 0; x < 10; x++ )
      {
         STAssertEqualsWithAccuracy((double)colorValue(testBuf,x,y,0),
                                    (x+10)/31.0,1e-5,
                                    @"red at %d,%d", x, y );
         STAssertEqualsWithAccuracy((double)colorValue(testBuf,x,y,1),
                                    (y+5)/19.0, 1e-5,
                                    @"green at %d,%d", x, y );
         STAssertEqualsWithAccuracy((double)colorValue(testBuf,x,y,2),
                                    ((x+y+15)%10)/10.0,1e-5,
                                    @"blue at %d,%d", x, y );
      }
   }  
}

- (void) testReadOutside
{
   // Create an item
   MyImageListItem *item = [MyImageListItem imageListItemWithURL:
                                             [NSURL URLWithString:@"1.tsturl"]];

   // Read a sample enclosing the image
   LynkeosStandardImageBuffer *testBuf = nil;
   [item getImageSample:&testBuf inRect:LynkeosMakeIntegerRect(-5,-4,40,30)];

   STAssertNotNil( testBuf, @"Test image not read" );

   u_short x, y;
   for( y = 0; y < 30; y++ )
   {
      for( x = 0; x < 40; x++ )
      {
         if ( (x >= 5 && x < 36) && (y >= 4 && y < 23) )
         {
            STAssertEqualsWithAccuracy((double)colorValue(testBuf,x,y,0),
                                       (x-5)/31.0,1e-5,
                                       @"red at %d,%d", x, y );
            STAssertEqualsWithAccuracy((double)colorValue(testBuf,x,y,1),
                                       (y-4)/19.0, 1e-5,
                                       @"green at %d,%d", x, y );
            STAssertEqualsWithAccuracy((double)colorValue(testBuf,x,y,2),
                                       ((x+y-9)%10)/10.0,1e-5,
                                       @"blue at %d,%d", x, y );
         }
         else
         {
            STAssertEquals( (double)colorValue(testBuf,x,y,0), 0.0,
                            @"red at %d,%d", x, y );
            STAssertEquals( (double)colorValue(testBuf,x,y,1), 0.0,
                            @"green at %d,%d", x, y );
            STAssertEquals( (double)colorValue(testBuf,x,y,2), 0.0,
                            @"blue at %d,%d", x, y );
         }
      }
   }  
}

// Test for a bug discovered in V2
- (void) testReadDisjoint
{
   // Create an item
   MyImageListItem *item = [MyImageListItem imageListItemWithURL:
                                             [NSURL URLWithString:@"1.tsturl"]];

   // Read samples totally outside the image
   short ox, oy;
   for( oy = -50 ; oy <= 50; oy += 50 )
   {
      for( ox = -40; ox <= 40; ox += 40 )
      {
         if ( ox == 0 && oy == 0 )
            continue;

         LynkeosStandardImageBuffer *testBuf = nil;
         [item getImageSample:&testBuf inRect:LynkeosMakeIntegerRect(ox,oy,40,30)];

         STAssertNotNil( testBuf, @"Test image not read" );

         u_short x, y, c;
         for( c = 0; c < 3; c++ )
            for( y = 0; y < 30; y++ )
               for( x = 0; x < 40; x++ )
                  STAssertEqualsWithAccuracy((double)colorValue(testBuf,x,y,c),
                                             0.0,1e-5,
                                             @"color %d at %d,%d", c, x, y );
      }
   }  
}

- (void) testMonochromeRead
{
   // Create an item
   MyImageListItem *item = [MyImageListItem imageListItemWithURL:
                                             [NSURL URLWithString:@"1.tsturl"]];

   // Read a sample
   LynkeosStandardImageBuffer *testBuf = [LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:1
                                                                   width:10
                                                                  height:10];
   [item getImageSample:&testBuf inRect:LynkeosMakeIntegerRect(10,5,10,10)];

   STAssertNotNil( testBuf, @"Test image not read" );

   u_short x, y;
   for( y = 0; y < 5; y++ )
   {
      for( x = 0; x < 10; x++ )
      {
         STAssertEqualsWithAccuracy((double)colorValue(testBuf,x,y,0),
                                    (x+10)/93.0+(y+5)/57.0+((x+y+15)%10)/30.0,
                                    1e-5,
                                    @"monochrome at %d,%d", x, y );
      }
   }  
}

- (void) testCalibratedRead
{
   // Create an item
   MyImageListItem *item = [MyImageListItem imageListItemWithURL:
                                             [NSURL URLWithString:@"1.tsturl"]];
   // And calibration frames
   LynkeosStandardImageBuffer *dark = [LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:3
                                                                width:31
                                                               height:19];
   LynkeosStandardImageBuffer *flat = [LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:3
                                                                width:31
                                                               height:19];
   u_short x, y;

   // Fill the calibration frames
   // Dark frame doubles the "glide" and adds an offset
   for( y = 0; y < 19; y++ )
   {
      for( x = 0; x < 31; x++ )
      {
         colorValue(dark,x,y,0) = -1.0-x/31.0;
         colorValue(dark,x,y,1) = -1.0-y/19.0;
         colorValue(dark,x,y,2) = -1.0-((x+y)%10)/10.0;
      }
   }
   // Flat field makes the result a uniform 3
   for( y = 0; y < 19; y++ )
   {
      for( x = 0; x < 31; x++ )
      {
         colorValue(flat,x,y,0) = (1.0+2.0*x/31.0)/3.0;
         colorValue(flat,x,y,1) = (1.0+2.0*y/19.0)/3.0;
         colorValue(flat,x,y,2) = (1.0+2.0*((x+y)%10)/10.0)/3.0;
      }
   }

   // Attach the calibration frames to the item
   [item setProcessingParameter:dark withRef:myImageListItemDarkFrame
                  forProcessing:nil];
   [item setProcessingParameter:flat withRef:myImageListItemFlatField
                  forProcessing:nil];

   // Read a sample
   LynkeosStandardImageBuffer *testBuf = nil;
   [item getImageSample:&testBuf inRect:LynkeosMakeIntegerRect(10,5,10,10)];

   STAssertNotNil( testBuf, @"Test image not read" );

   for( y = 0; y < 5; y++ )
   {
      for( x = 0; x < 10; x++ )
      {
         STAssertEqualsWithAccuracy((double)colorValue(testBuf,x,y,0),
                                    3.0,1e-5,
                                    @"red at %d,%d", x, y );
         STAssertEqualsWithAccuracy((double)colorValue(testBuf,x,y,1),
                                    3.0, 1e-5,
                                    @"green at %d,%d", x, y );
         STAssertEqualsWithAccuracy((double)colorValue(testBuf,x,y,2),
                                    3.0,1e-5,
                                    @"blue at %d,%d", x, y );
      }
   }  
}

- (void) testModifiedItem
{
   // Create an item
   MyImageListItem *item = [MyImageListItem imageListItemWithURL:
                                             [NSURL URLWithString:@"1.tsturl"]];
   // And an image
   LynkeosStandardImageBuffer *image = [LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:3
                                                                 width:31
                                                                height:19];
   u_short x, y;

   // Fill the image
   for( y = 0; y < 19; y++ )
   {
      for( x = 0; x < 31; x++ )
      {
         colorValue(image,x,y,0) = (30-x)/31.0;
         colorValue(image,x,y,1) = (18-y)/19.0;
         colorValue(image,x,y,2) = ((48-x-y)%10)/10.0;
      }
   }

   // Set the image as the item modified image
   [item setImage:image];

   // Read a sample
   LynkeosStandardImageBuffer *testBuf = nil;
   [item getImageSample:&testBuf inRect:LynkeosMakeIntegerRect(10,5,10,10)];

   STAssertNotNil( testBuf, @"Test image not read" );

   for( y = 0; y < 5; y++ )
   {
      for( x = 0; x < 10; x++ )
      {
         STAssertEqualsWithAccuracy((double)colorValue(testBuf,x,y,0),
                                    (20-x)/31.0,1e-5,
                                    @"red at %d,%d", x, y );
         STAssertEqualsWithAccuracy((double)colorValue(testBuf,x,y,1),
                                    (13-y)/19.0, 1e-5,
                                    @"green at %d,%d", x, y );
         STAssertEqualsWithAccuracy((double)colorValue(testBuf,x,y,2),
                                    ((33-x-y)%10)/10.0,1e-5,
                                    @"blue at %d,%d", x, y );
      }
   }

   // Revert the item to "original"
   [item revertToOriginal];

   // Read again the sample
   testBuf = nil;
   [item getImageSample:&testBuf inRect:LynkeosMakeIntegerRect(10,5,10,10)];

   STAssertNotNil( testBuf, @"Test image not read" );

   for( y = 0; y < 5; y++ )
   {
      for( x = 0; x < 10; x++ )
      {
         STAssertEqualsWithAccuracy((double)colorValue(testBuf,x,y,0),
                                    (x+10)/31.0,1e-5,
                                    @"red at %d,%d", x, y );
         STAssertEqualsWithAccuracy((double)colorValue(testBuf,x,y,1),
                                    (y+5)/19.0, 1e-5,
                                    @"green at %d,%d", x, y );
         STAssertEqualsWithAccuracy((double)colorValue(testBuf,x,y,2),
                                    ((x+y+15)%10)/10.0,1e-5,
                                    @"blue at %d,%d", x, y );
      }
   }  
}

@end
