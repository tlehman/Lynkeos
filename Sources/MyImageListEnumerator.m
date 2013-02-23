//
//  Lynkeos
//  $Id: MyImageListEnumerator.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun Nov 30 2003.
//  Copyright (c) 2003-2008. Jean-Etienne LAMIAUD
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

#include "MyImageListEnumerator.h"

@implementation MyImageListEnumerator

- (id) initWithImageList :(NSArray*)list startAt:(MyImageListItem*)item
              directSense:(BOOL)direct skipUnselected:(BOOL)skip
{
   [super init];

   _lock = [[NSRecursiveLock alloc] init];

   _itemList = [list retain];
   _listSize = [list count];
   _step = (direct ? 1 : -1);
   _skipUnselected = skip;

   if ( item != nil )
   {
      // Check that the item is in the list hierarchy
      MyImageListItem *parent, *topItem;
      for( parent = item, topItem = item;
           parent != nil ;
           parent = [topItem getParent] )
         topItem = parent;
      NSAssert( topItem != nil && [list containsObject:topItem],
                @"Initial item of enumerator is not in the list" );
      _currentContainer = [item getParent];
      if ( _currentContainer != nil )
      {
         _containerSize = [_currentContainer numberOfChildren];
         _itemIndex = [list indexOfObject:_currentContainer];
         _containerIndex = [_currentContainer indexOfItem:item]+_step;
         if ( (_step > 0 && _containerIndex >= _containerSize) || 
               (_step < 0 && _containerIndex < 0) )
            _itemIndex += _step;
      }
      else if ( (_containerSize = [item numberOfChildren]) != 0 )
      {
         _currentContainer = item;
         _itemIndex = [list indexOfObject:_currentContainer];
         _containerIndex = (direct ? 0 : -1);
      }
      else
      {
         _currentContainer = nil;
         _containerSize = 0;
         _itemIndex = [list indexOfObject:item]+_step;
         _containerIndex = 0;            
      }
   }
   else
   {
      _currentContainer = nil;
      _containerSize = 0;
      _itemIndex = (direct ? 0 : _listSize-1);
      _containerIndex = 0;
   }

   return( self );
}

- (id) initWithImageList :(NSArray*)list
{
   return( [self initWithImageList:list startAt:nil
                       directSense:YES skipUnselected:NO] );
}

- (void) dealloc
{
   [_lock release];
   [_itemList release];
   [super dealloc];
}

- (NSArray *) allObjects
{
   NSMutableArray *array = [NSArray array];
   id item;

   [_lock lock];

   while ( (item = [self nextObject]) != nil )
      [array addObject:item];

   [_lock unlock];

   return( array );
}

- (id) nextObject
{
   id item = nil;

   [_lock lock];

   while ( item == nil
           && ( ( _step > 0 && _itemIndex < _listSize ) || 
                ( _step < 0 && _itemIndex >= 0 ) ) )
   {
      // Look for an image item (inside a movie or self contained)
      if ( _currentContainer == nil ||
           (_step > 0 && _containerIndex >= _containerSize) || 
           (_step < 0 && _containerIndex < 0) )
      {
         // At first level
         item = [_itemList objectAtIndex:_itemIndex];
         if ( (_containerSize = [item numberOfChildren]) != 0 )
         {
            // First level item is a container, go down
            _currentContainer = item;
            item = nil;
            _containerIndex = (_step > 0 ? 0 : _containerSize-1);
         }
         else
            _itemIndex += _step;
      }

      if ( _currentContainer != nil )
      {
         // Inside a container
         if ( (_step > 0 && _containerIndex < _containerSize) || 
            (_step < 0 && _containerIndex >= 0) )
         {
            item = [_currentContainer getChildAtIndex:_containerIndex];
            _containerIndex += _step;
         }
         if ( (_step > 0 && _containerIndex >= _containerSize) || 
              (_step < 0 && _containerIndex < 0) )
            _itemIndex += _step;
      }

      // Do not iterate over unselected items if told so
      if ( _skipUnselected && [item getSelectionState] != NSOnState )
         item = nil;
   }

   [_lock unlock];

   return( item );
}

@end
