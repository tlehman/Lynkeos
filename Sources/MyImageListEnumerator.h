//==============================================================================
//  Lynkeos 
//  $Id: MyImageListEnumerator.h 462 2008-10-05 21:31:44Z j-etienne $
//  Created by Jean-Etienne LAMIAUD on Tue Jul 27 2004.
//------------------------------------------------------------------------------
//  Copyright (c) 2003-2008. Jean-Etienne LAMIAUD
//------------------------------------------------------------------------------
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
//------------------------------------------------------------------------------

/*!
 * @header
 * @abstract Definitions for the image enumerator
 */
#ifndef __MYIMAGELISTENUM_H
#define __MYIMAGELISTENUM_H

#import <Foundation/Foundation.h>

#include "MyImageListItem.h"

/*!
 * @class MyImageListEnumerator
 * @abstract Enumerator on MyImageList
 * @discussion This enumerator scans all the MyImageListItem images in a 
 *    MyImageList. When the list contains a container, it scans each items 
 *    inside it.
 * @ingroup Models
 */
@interface MyImageListEnumerator : NSEnumerator
{
    NSArray*         _itemList;           //!< The list of items to enumerate
    int              _listSize;           //!< Number of first level items
    int              _itemIndex;          //!< Index of current first level item
    MyImageListItem* _currentContainer;   //!< Container being enumerated if any
    int              _containerSize;      //!< Number of items in the container
    int              _containerIndex;//!< Index of current item in the container
    int              _step;               //!< Sense of enumeration (1 or -1)
    BOOL             _skipUnselected;     //!< Do not enumerate unselected items
    NSRecursiveLock  *_lock;              //!< Lock for multithreads access
}

/*!
 * @method initWithImageList:startAt:directSense:
 * @abstract Base initializer
 * @discussion It initializes a MyImageListEnumerator whith a custom starting
 *    point and a custom scanning direction.
 * @param list The MyImageListItem array do scan
 * @param item The item to start with. If nil, the first or last (if reverse 
 *    enumerator) is taken
 * @param direct Direct or reverse enumerator
 * @param skip Whether to skip unselected images
 */
- (id) initWithImageList :(NSArray*)list startAt:(MyImageListItem*)item 
              directSense:(BOOL)direct skipUnselected:(BOOL)skip;

/*!
 * @method initWithImageList:
 * @discussion It initializes a direct enumerator for all items starting at the
 *    first item of the list.
 * @abstract Simplified initializer
 * @param list The MyImageListItem array to scan
 */
- (id) initWithImageList :(NSArray*)list ;

@end

#endif
