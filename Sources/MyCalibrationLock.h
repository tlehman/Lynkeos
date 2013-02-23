// 
//  Lynkeos
//  $Id: MyCalibrationLock.h 452 2008-09-14 12:35:29Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Mon Aug 16 2004.
//  Copyright (c) 2004-2008. Jean-Etienne LAMIAUD
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
 * @abstract Definitions for the locking of images characteristics with 
 *   respect to the use of calibration frames.
 */
#ifndef __MYCALIBRATIONLOCK_H
#define __MYCALIBRATIONLOCK_H

#import <Foundation/Foundation.h>

#include "LynkeosFileReader.h"

#include "LynkeosCommon.h"
#include "MyImageListItem.h"

/*!
 * @class MyCalibrationLock
 * @abstract This class locks the use of image/movie depending on the 
 *   state of calibration data.
 * @discussion This class enforces the use of images or movies compatible for 
 *   calibration purpose.
 * @ingroup Controlers
 */
@interface MyCalibrationLock : NSObject 
{
@private
   NSMutableArray    *_calibrationList;  //!< List of all calibration readers
   NSMutableArray    *_imageList;        //!< List of all "calibrable" readers
   LynkeosIntegerSize _size;             //!< Size of calibration frames
   //! Number of planes of calibration frames
   u_short            _nPlanes;
}

/*!
 * @method addCalibrationItem:
 * @abstract Add a new calibration item
 * @param item The new item
 * @result Did the add succeeded ?
 */
- (BOOL) addCalibrationItem :(MyImageListItem*)item ;

/*!
 * @method addImageItem:
 * @abstract Add a new image item to the list
 * @param item The new item
 * @result Did the add succeeded ?
 */
- (BOOL) addImageItem :(MyImageListItem*)item ;

/*!
 * @method removeItem:
 * @abstract Remove one item from the list.
 * @param item The item to be removed
 */
- (void) removeItem :(MyImageListItem*)item ;

/*!
 * @method calibrationSize
 * @abstract Get the size of the calibration frames
 * @result The calibration frames size (null size if no calibration frames)
 */
- (LynkeosIntegerSize) calibrationSize ;

/*!
 * @method calibrationLock
 * @abstract Constructor
 * @result An initialized instance of MyCalibrationLock
 */
+ (id) calibrationLock ;

@end

#endif
