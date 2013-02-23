//
//  Lynkeos
//  $Id: MyImageList.h 451 2008-09-13 22:06:01Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Wed Sep 24 2003.
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
 * @abstract Definitions for the generic image list.
 */
#ifndef __MYIMAGELIST_H
#define __MYIMAGELIST_H

#import <Foundation/Foundation.h>

#include "LynkeosProcessing.h"
#include "LynkeosProcessableImage.h"
#include "MyImageListItem.h"

/*!
 * @abstract Base model of a list of images to process
 * @discussion The images in the list share a common goal (dark frame, flat 
 *    field or object images).
 * @ingroup Models
 */
@interface MyImageList : LynkeosProcessableImage <LynkeosImageList,NSCoding>
{
@protected
   NSMutableArray*	_list;           //!< The list of images
}

/// \name Actions
//@{
// List data
/*!
 * @abstract Add a new item to the list
 * @param item A new image or movie
 * @result Wether the document content has changed
 */
- (BOOL) addItem :(MyImageListItem*)item ;

/*!
 * @abstract Deletes the given item from the list
 * @param item The item to delete
 * @result Wether the document content has changed
 */
- (BOOL) deleteItem :(MyImageListItem*)item ;

/*!
 * @abstract Change the selection state of the given item
 * @param item The item for which to change the selection state
 * @param v The new selection state
 * @result Wether the document content has changed
 */
- (BOOL) changeItemSelection :(MyImageListItem*)item value:(BOOL)v ;

/*!
 * @abstract Set the parent object for parameters chain
 * @param parent The parent of this item in the parameter chain
 */
- (void) setParametersParent :(LynkeosProcessingParameterMgr*)parent;
//@}

/// \name Initializers and constructors
//@{

/*!
 * @abstract Initialize an instance with a given initial image list
 * @param list An existing image list
 * @result The initialized instance
 */
- (id) initWithArray :(NSArray*)list ;


/*!
 * @abstract Convenience creator with a given initial image list
 * @param list An existing image list
 * @result The allocated and initialized instance
 */
+ (id) imageListWithArray :(NSArray*)list ;
//@}

@end

#endif
