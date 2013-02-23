//
//  Lynkeos
//  $Id: MyDocument.h 479 2008-11-23 14:28:07Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Thu Jul 29 2004.
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

/*! \defgroup Controlers Controler classes
*
* The controler classes manage the interactions between the view classes and 
* the model classes
*/

/*!
 * @header
 * @abstract Definitions of the document controller.
 */
#ifndef __MYDOCUMENT_H
#define __MYDOCUMENT_H

#import <Foundation/Foundation.h>

#include "LynkeosProcessing.h"
#include "LynkeosProcessingView.h"
#include "MyImageListItem.h"
#include "MyImageList.h"
#include "MyCalibrationLock.h"
#include "MyProcessingThread.h"
#include "ProcessStackManager.h"

/*!
 * @abstract The document controler
 * @discussion This class controls the actions on the document.
 *   It dialogs with MyImageListWindow for GUI interactions and
 *   the Models classes for document contents change.
 * @ingroup Controlers
 */
@interface MyDocument : NSDocument <LynkeosViewDocument>
{
@private
   // Document data
   MyImageList*		_darkFrameList;   //!< Thermal noise images
   MyImageList*		_flatFieldList;   //!< Optical attenuations
   MyImageList*         _imageList;       //!< Images to be processed

   MyCalibrationLock*    _calibrationLock;//!< Enforces calibration restrictions
   NSDictionary*         _windowSizes;     //!< Saved window sizes and placement

   // Lists management
   MyImageList*         _currentList;     //!< List being used
   DataMode_t           _dataMode;      //!< Which data to use

   // Multithread control
   NSMutableArray      *_threads;         //!< Living threads
   Class               _currentProcessingClass; //!< What processing is running
   //! Item being processed, nil if it is a list processing
   id <LynkeosProcessableItem> _processedItem;
   u_long               _imageListSequenceNumber; //!< To detect original change
   ProcessStackManager *_processStackMgr; //!< Manager for the stack
   //! Used at document loading to apply the processings
   NSEnumerator         *_initialProcessEnum;
   BOOL                 _isInitialProcessing;

#if !defined GNUSTEP
   io_connect_t         _rootPort;        //!< Sleep control
#endif

   NSWindowController <LynkeosWindowController> *_myWindow; //!< Document window controller

   LynkeosProcessingParameterMgr* _parameters;    //!< Aggregate class for parameters

   // Stuff to help notifying
   NSNotificationCenter* _notifCenter;    //!< Our notification center
   NSNotificationQueue* _notifQueue;      //!< For asynchronous notifications
}

/// \name Accessors
/// Read accessors to the class attributes
//@{
- (LynkeosIntegerSize) calibrationSize ;
- (NSDictionary*) savedWindowSizes ;
//@}

/// \name GUIActions
/// Coming from window controllers
//@{
/*!
 * @abstract Add the item to the current list
 * @discussion The undo manager is updated for undoing the add
 * @param item item to add to the list
 */
- (void) addEntry :(MyImageListItem*)item ;
/*!
 * @abstract Remove the item from the current list
 * @discussion The undo manager is updated for undoing the remove
 * @param item item to remove from the list
 */
- (void) deleteEntry :(MyImageListItem*)item ;
- (void) changeEntrySelection :(MyImageListItem*)entry value:(BOOL)v ;
//@}

/// \name Process management
//@{
/*!
 * @abstract Inform the document of the thread creation.
 * @discussion The "obj" proxy cannot be retained. The process ended call will
 *    inform of the proxy release.
 * @param proxy Proxy for the created process thread.
 * @param cnx The connection for this thread.
 */
- (oneway void) processStarted: (id)proxy connection:(LynkeosThreadConnection*)cnx;

/*!
 * @abstract Inform the document of the thread termination.
 * @discussion This method is synchronous to wait execution before terminating
 *    the thread.
 * @param obj The proxy for the thread that is ending.
 */
- (void) processEnded: (id)obj ;
//@}
@end

#endif
