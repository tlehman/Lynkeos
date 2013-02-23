//  Lynkeos
//  $Id: MyListManagement.h 423 2008-05-16 21:37:14Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun Mar 4, 2007.
//  Copyright (c) 2007-2008. Jean-Etienne LAMIAUD
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
 * @abstract Pseudo processing view class which manages the lists of images
 */
#ifndef __MYLISTMANAGEMENT_H
#define __MYLISTMANAGEMENT_H

#import <Foundation/Foundation.h>

#include "LynkeosProcessingView.h"
#include "MyImageListWindow.h"

/*!
 * @abstract Pseudo "process view" that allows to build image lists.
 */
@interface MyListManagement : NSObject <LynkeosProcessingView>
{
   IBOutlet NSView*           _view;         //!< The list management NSView
   IBOutlet NSButton*	      _plusButton;   //!< Button that adds images
   IBOutlet NSButton*	      _minusButton;  //!< Delete images from the list
   IBOutlet NSButton*	      _prevButton;   //!< Go to the previous image
   IBOutlet NSButton*	      _nextButton;   //!< Go to the next image
   IBOutlet NSButton*	      _toggleButton; //!< Toggle image selection state

   IBOutlet MyImageListWindow* _windowController; //!< The main window ctrl
   id <LynkeosViewDocument>   _document;     //!< The document...

   NSOutlineView              *_textView;    //!< The outline text frame
   id <LynkeosImageView>      _imageView;   //!< The image frame
}

/*!
 * @abstract Add an image
 * @param sender The button
 */
- (IBAction) addAction :(id)sender ;

/*!
 * @abstract Delete an image from the list
 * @param sender The button
 */
- (IBAction) deleteAction :(id)sender ;

/*!
 * @abstract Toggle the selection state of an image
 * @param sender The button
 */
- (IBAction) toggleEntrySelection :(id)sender ;

/*!
 * @abstract Hilight the next image
 * @param sender The button
 */
- (IBAction) highlightNext :(id)sender ;

/*!
 * @abstract Hilight the previous image
 * @param sender The button
 */
- (IBAction) highlightPrevious :(id)sender ;
@end

#endif
