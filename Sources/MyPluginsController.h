//  Lynkeos
//  $Id: MyPluginsController.h 483 2008-12-15 23:08:44Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Mar 2, 2007.
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

/*!
 * @header
 * @abstract Plugin controller singleton class
 */
#ifndef __MYPLUGINSCONTROLLER_H
#define __MYPLUGINSCONTROLLER_H

#import <Foundation/Foundation.h>

#include "LynkeosProcessingView.h"

extern NSString * const LynkeosPluginHelpFile;

/*!
 * @abstract Utility class which registers a reader with its priority for one
 *    file type
 */
@interface LynkeosReaderRegistry : NSObject
{
@public
   //! The priority this reader has for opening this kind of file
   int   priority;
   Class reader;        //!< One file reader
}
@end

@interface LynkeosProcessingViewRegistry : NSObject
{
@public
   Class                controller; //!< The processing view controller
   id <NSObject>        config;     //!< Optional configuration object
   NSString*            ident;      //!< A class unique identifier
}
@end

/*!
 * @abstract This singleton loads every plugins and retrieves the helpers
 *    classes they provide.
 */
@interface MyPluginsController : NSObject
{
   //! The readers, organized by file type as arrays sorted by priority
   //! @{
   NSMutableDictionary *_imageReadersDict;
   NSMutableDictionary *_movieReadersDict;
   //! @}
   //! The writers classes
   //! @{
   NSMutableArray *_imageWritersList;
   NSMutableArray *_movieWritersList;
   //! @}
   //! The processing view classes
   NSMutableArray *_processingViewsList;
   //! The preference classes
   NSMutableArray *_preferencesList;
   //! Plugins bundle list
   NSMutableArray *_bundlesList;
}

/*!
 * @abstract Retrieves the singleton instance of MyPluginController
 * @result The lone instance
 */
+ (MyPluginsController*) defaultPluginController;

/*!
 * @abstract Register a processing view controller
 * @param c the processing view class
 * @param config a configuration object
 * @param ident a class unique identifier for this controller
 */
- (void) registerProcessingViewController:(Class)c
                        withConfiguration:(id)config
                               identifier:(NSString*)ident;

/*!
 * @abstract Access the list of image readers classes
 * @result The image readers class dictionary, organized by file type as arrays
 *    sorted by priority
 */
- (NSDictionary*) getImageReaders;

/*!
 * @abstract Access the list of movie readers classes
 * @result The movie readers class dictionary, organized by file type as arrays
 *    sorted by priority
 */
- (NSDictionary*) getMovieReaders;

/*!
 * @abstract Access the list of image writers classes
 * @result The image writer class array
 */
- (NSArray*) getImageWriters;

/*!
 * @abstract Access the list of movie writers classes
 * @result The movie writers class array
 */
- (NSArray*) getMovieWriters;

/*!
 * @abstract Access the list of processing view classes
 * @result The processing view class array
 */
- (NSArray*) getProcessingViews;

/*!
 * @abstract Access the list of user preference classes
 * @result The preferences class array
 */
- (NSArray*) getPreferencesPanes;

/*!
 * @abstract Access the list of loaded bundles
 * @result The bundles array
 */
- (NSArray*) getLoadedBundles;
@end

#endif