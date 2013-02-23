//
//  Lynkeos
//  $Id: MyProcessingThread.h 462 2008-10-05 21:31:44Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun Nov 13 2005.
//  Copyright (c) 2005-2008. Jean-Etienne LAMIAUD
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
 * @abstract Thread controller definitions
 */

#ifndef __MYPROCESSINGTHREAD_H
#define __MYPROCESSINGTHREAD_H

#import <Foundation/Foundation.h>

#include "LynkeosProcessing.h"
#include "LynkeosThreadConnection.h"

@class MyDocument;

extern NSString * const K_PROCESS_CONNECTION;     ///< Connection with main thread
extern NSString * const K_PROCESS_CLASS_KEY;      ///< Class of the "processor"
extern NSString * const K_PROCESS_ENUMERATOR_KEY; ///< Process items enumerator
extern NSString * const K_PROCESS_ITEM_KEY;       ///< Alternate form: only item
extern NSString * const K_PROCESS_PARAMETERS_KEY; ///< Direct parameter

/*!
 * @class MyProcessingThread
 * @abstract The thread controller for image list processing
 * @discussion When the thread is started, the controller :
 *    <ul>
 *      <li>creates and initializes a processing instance.
 *      <li>iterates over the item list and calls the processing instance for 
 *      each item. 
 *      <li>Calls the "end of processing" method of processing instance when
 *      all items have been processed.
 *      <li>Free all the resources and terminates the thread.
 *   </ul> 
 */
@interface MyProcessingThread : NSObject
{
@protected
   id <LynkeosProcessing>  _processingInstance;    //!< The processing object !
   MyDocument*             _document;              //!< The document controller
   NSEnumerator*           _itemList;  //!< Enumerator given at thread creation
   id <LynkeosProcessableItem> _item;        //!< Alternate form: only one item
   BOOL                    _processEnded;          //!< Controls the run loop
   NSProxy*                _proxy;             //!< Our proxy in the main thread
}

/*!
 * @method threadWithAttributes:
 * @abstract Thread creation 
 * @discussion This method creates the thread, establishes the connection 
 *   with the calling thread, starts a run loop and handle its autorelease pool.
 * @param attr Thread attributes : communication ports in a dictionary
 */
+ (void) threadWithAttributes:(NSDictionary*)attr ;

/*!
 * @method stopProcessing
 * @abstract Force the thread to exit when next item is processed
 * @result None
 */
- (oneway void) stopProcessing ;

@end

#endif
