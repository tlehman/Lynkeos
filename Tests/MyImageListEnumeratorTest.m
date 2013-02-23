//
//  Lynkeos
//  $Id: MyImageListEnumeratorTest.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Wed Jan 16 2008.
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

#include "MyImageListEnumeratorTest.h"

#include "MyImageListEnumerator.h"
#include "MyPluginsController.h"
#include "MyImageListItem.h"

extern BOOL pluginsInitialized;

// Fake reader
@interface EnumTestReader : NSObject <LynkeosMovieFileReader>
{
   int _numberOfChildren;
}
@end

@implementation EnumTestReader
+ (void) lynkeosFileTypes:(NSArray**)fileTypes
{
   *fileTypes = [NSArray arrayWithObject:@"enum"];
}

- (id) initWithURL:(NSURL*)url
{
   if ( (self = [self init]) != nil )
   {
      if ( [[url path] isEqual:@"1.enum"] )
      {
         // No child
         _numberOfChildren = 0;
      }
      else if ( [[url path] isEqual:@"2.enum"] )
      {
         // 4 Children
         _numberOfChildren = 4;
      }
    }

   return( self );
}

- (u_long) numberOfFrames
{
   return( _numberOfChildren );
}

- (u_short) numberOfPlanes
{
   return( 0 );
}

- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax
{
   *vmin = 0.0;
   *vmax = 1.0;
}

- (void) imageWidth:(u_short*)w height:(u_short*)h
{
   *w = 0;
   *h = 0;
}

- (NSDictionary*) getMetaData { return( nil ); }
+ (BOOL) hasCustomImageBuffer { return( NO ); }
- (BOOL) canBeCalibratedBy:(id <LynkeosFileReader>)reader 
{ return( NO ); }

- (NSImage*) getNSImageAtIndex:(u_long)index { return( nil ); }

- (void) getImageSample:(void * const * const)sample atIndex:(u_long)index
          withPrecision:(floating_precision_t)precision
             withPlanes:(u_short)nPlanes
                    atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
              lineWidth:(u_short)lineW ;
{
   [self doesNotRecognizeSelector:_cmd];
}

- (id <LynkeosImageBuffer>) getCustomImageSampleAtIndex:(u_long)index
                                                    atX:(u_short)x Y:(u_short)y 
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

@implementation MyImageListEnumeratorTest
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

- (void) testDefaultIterator
{
   NSMutableArray *list = [NSMutableArray array];
   MyImageListItem *topItem;

   // Construct a hierarchical list
   [list addObject:[[[MyImageListItem alloc] init] autorelease]];
   topItem = [[[MyImageListItem alloc] initWithURL:
                                  [NSURL URLWithString:@"2.enum"]] autorelease];
   [list addObject:topItem];

   // Create an enumerator, with the default initializer
   MyImageListEnumerator *enumerator =
           [[[MyImageListEnumerator alloc] initWithImageList:list] autorelease];

   // Enumerate and check
   MyImageListItem *item = [enumerator nextObject];
   STAssertEquals(item,[list objectAtIndex:0],@"Bad element at first iteration");
   int i;
   for( i = 0; i < 4; i++ )
   {
      item = [enumerator nextObject];
      STAssertEquals(item,[topItem getChildAtIndex:i],
                     @"Bad child %d at iteration", i);
   }
   item = [enumerator nextObject];
   STAssertNil(item,@"List not ended");
}

- (void) testLastNotSelected
{
   NSMutableArray *list = [NSMutableArray array];
   MyImageListItem *item;

   // Construct a flat list with the last item not selected
   int i;
   for( i = 0; i < 4; i++ )
   {
      item = [[[MyImageListItem alloc] init] autorelease];
      [item setSelected:( i == 0 || i == 2 )];
      [list addObject:item];
   }

   // Create an enumerator, which skips unselected items
   MyImageListEnumerator *enumerator =
      [[[MyImageListEnumerator alloc] initWithImageList:list
                                                startAt:nil
                                            directSense:YES
                                         skipUnselected:YES] autorelease];

   // Enumerate and check
   item = [enumerator nextObject];
   STAssertEquals(item,[list objectAtIndex:0],@"Bad element at first iteration");
   item = [enumerator nextObject];
   STAssertEquals(item,[list objectAtIndex:2],@"Bad element at second iteration");
   item = [enumerator nextObject];
   STAssertNil(item,@"List not ended at third iteration");
}

- (void) testTopPredecessor
{
   NSMutableArray *list = [NSMutableArray array];
   MyImageListItem *topItem, *item;

   // Construct a hierarchical list
   [list addObject:[[[MyImageListItem alloc] init] autorelease]];
   topItem = [[[MyImageListItem alloc] initWithURL:
                                  [NSURL URLWithString:@"2.enum"]] autorelease];
   [list addObject:topItem];

   // Create a backward enumerator starting at top item
   MyImageListEnumerator *enumerator =
            [[[MyImageListEnumerator alloc] initWithImageList:list
                                                      startAt:topItem
                                                  directSense:NO
                                               skipUnselected:YES] autorelease];

   // Enumerate and check
   item = [enumerator nextObject];
   STAssertEquals(item,[topItem getChildAtIndex:3],
                  @"Predecessor of top item is not the last child");
}

- (void) testTopSuccessor
{
   NSMutableArray *list = [NSMutableArray array];
   MyImageListItem *topItem, *item;

   // Construct a hierarchical list
   [list addObject:[[[MyImageListItem alloc] init] autorelease]];
   topItem = [[[MyImageListItem alloc] initWithURL:
      [NSURL URLWithString:@"2.enum"]] autorelease];
   [list addObject:topItem];

   // Create a backward enumerator starting at top item
   MyImageListEnumerator *enumerator =
      [[[MyImageListEnumerator alloc] initWithImageList:list
                                                startAt:topItem
                                            directSense:YES
                                         skipUnselected:YES] autorelease];

   // Enumerate and check
   item = [enumerator nextObject];
   STAssertEquals(item,[topItem getChildAtIndex:0],
                  @"Successor of top item is not the first child");
}
@end
