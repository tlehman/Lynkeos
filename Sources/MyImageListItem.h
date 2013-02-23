//
//  Lynkeos
//  $Id: MyImageListItem.h 475 2008-11-09 10:14:42Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Tue Sep 30 2003.
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

/*!
 * @header
 * @abstract Image list item classes
 */
#ifndef __MYIMAGELISTITEM_H
#define __MYIMAGELISTITEM_H

#import <Foundation/Foundation.h>

#ifdef GNUSTEP
#import "LynkeosCommon.h"
#import <AppKit/NSImage.h>
#endif

#include "LynkeosFileReader.h"

#include "LynkeosCommon.h"
#include "processing_core.h"
#include "LynkeosProcessableImage.h"

/** Access to processing parameters related only to the item */
extern NSString * const myImageListItemRef;
/* Predefined keys for calibration frames */
extern NSString * const myImageListItemDarkFrame;   ///< Dark frame param key
extern NSString * const myImageListItemFlatField;   ///< Flat field param key

/*! Index value for non movie image items */
#define NON_SIGNIFICANT_INDEX 0xFFFFFFFF

/*!
 * @abstract Common class for all image list items
 * @discussion It provides a unique interface to the outline view, and the 
 *    common data and methods for the image list items.
 * @ingroup Models
 */
@interface MyImageListItem : LynkeosProcessableImage <LynkeosProcessingParameter>
{
@protected
   //!< The associated file reader
   id <LynkeosImageFileReader,LynkeosMovieFileReader> _reader;
   NSURL*           _itemURL;             //!< Image or movie URL
   NSString*        _itemName;            //!< To be displayed to user
   NSMutableArray*  _childList;           //!< Array of childs, if any
   MyImageListItem* _parent;              //!< Parent item, if any
   u_long           _index;               //!< Our index, if any
   //! Current selection state, can be tri state
   int              _selection_state;

   id <LynkeosImageBuffer> _flat;         //!< Cached flat field
   id <LynkeosImageBuffer> _dark;         //!< Cached dark frame
}

/*!
 * @method initWithURL:
 * @abstract Initialization
 * @param url Image or movie associated with this item.
 */
- (id) initWithURL :(NSURL*)url ;

/// \name Read
/// Read accessors to the class attributes
//@{
/*!
 * @method getURL
 * @abstract Read the URL of the associated file
 * @result The URL
 */
- (NSURL*) getURL ;

/*!
 * @method getSelectionState
 * @abstract Read the item current selection state
 * @result Tristate selection state.
 */
- (int) getSelectionState;

/*!
 * @method selectionState
 * @abstract Get the item current selection state as a NSNumber
 * @result Tristate selection state in a NSNumber
 */
- (NSNumber*) selectionState;

/*!
 * @abstract Read the name of the associated file
 * @result The name
 */
- (NSString*)name;

/*!
 * @abstract Read the movie image index (nil if not in a movie)
 * @result The index or nil
 */
- (NSNumber*) index;

/*!
 * @method getParent
 * @abstract Get the parent item if there is one
 * @result The parent item or nil
 */
- (MyImageListItem*) getParent;

/*!
 * @method numberOfChildren
 * @abstract Return the number of children, 0 for leaf items.
 * @result Number of children.
 */
- (u_long) numberOfChildren ;

/*!
 * @method getChildAtIndex:
 * @abstract Get the asked item
 * @param index The index of item to get.
 * @result The child item.
 */
- (MyImageListItem*) getChildAtIndex:(u_long)index ;

/*!
 * @method indexOfItem:
 * @abstract Get the index of the given item in the child list (different from 
 *   the item index which is the index of its frame in the movie)
 * @param item The item which index we need
 * @result The index
 */
- (unsigned) indexOfItem :(MyImageListItem*)item ;

/*!
 * @method getReader
 * @abstract Get the file reader for that item.
 * @result The file reader associated with this item.
 */
- (id <LynkeosFileReader>) getReader;
//@}

/// \name Write
/// Write accessors to the class attributes
//@{
/*!
 * @method addChild:
 * @abstract Add the given child in the children list
 * @param item The item to add
 */
- (void) addChild:(MyImageListItem*)item ;

   /*!
 * @method deleteChild:
 * @abstract Delete the given child from the children list
 * @param item The item to delete
 */
- (void) deleteChild:(MyImageListItem*)item ;

/*!
 * @method setSelected:
 * @abstract Set the selection state (no tristate)
 * @param value The new selection state
 */
- (void) setSelected :(BOOL)value;

/*!
 * @abstract Set the parent object for parameters chain
 * @param parent The parent of this item in the parameter chain
 */
- (void) setParametersParent :(LynkeosProcessingParameterMgr*)parent;
//@}

/*!
 * @method imageListItemWithURL:
 * @abstract Creator
 * @param url The URL from which the item shall be created.
 * @result The allocated and intialized item.
 */
+ (id) imageListItemWithURL :(NSURL*)url;

/*!
 * @method imageListItemFileTypes
 * @abstract File types and subclasses registering
 * @result The file types array.
 */
+ (NSArray*) imageListItemFileTypes ;

@end

#endif
