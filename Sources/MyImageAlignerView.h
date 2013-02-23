//
//  Lynkeos
//  $Id: MyImageAlignerView.h 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sat Nov 4 2006.
//  Copyright (c) 2006-2008. Jean-Etienne LAMIAUD
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
 * @abstract Definitions of the "align" view.
 */
#ifndef __MYIMAGEALIGNERVIEW_H
#define __MYIMAGEALIGNERVIEW_H

#import <AppKit/AppKit.h>

#include "LynkeosProcessingView.h"

/*!
 * @abstract Aligner view controller class
 * @ingroup Processing
 */
@interface MyImageAlignerView : NSObject <LynkeosProcessingView>
{
   IBOutlet NSTextField       *_searchFieldX;  //!< X coordinate of the square
   IBOutlet NSTextField       *_searchFieldY;  //!< Y coordinate of the square
   IBOutlet NSPopUpButton*    _searchSideMenu; //!< Search square side
   IBOutlet NSButton*         _privateSearch;  //!< Square private to the item
   IBOutlet NSButton*	      _refCheckBox;    //!< Reference item selection
   IBOutlet NSButton*	      _cancelButton;   //!< Delete selected align result
   IBOutlet NSButton*	      _alignButton;    //!< Start alignment
   IBOutlet NSView*           _panel;          //!< Our view

   id <LynkeosWindowController> _window;       //!< Our window controller
   id <LynkeosViewDocument>   _document;       //!< Our document
   id <LynkeosImageList>      _list;           //!< The current list

   NSOutlineView             *_textView;       //!< Items list display
   id <LynkeosImageView>      _imageView;      //!< For dislaying the images

   unsigned int               _sideMenuLimit;  //!< Upper limit for square side
   BOOL                       _isAligning;     //!< Alignment is under process
   //! Whether to update image display after aligning each item
   BOOL                       _imageUpdate;
}

/*!
 * @abstract The origin of the search square was changed
 * @param sender The control which value was changed
 */
- (IBAction) searchSquareChange :(id)sender ;
/*!
 * @abstract The size of the search square was changed
 * @param sender The control which value was changed
 */
- (IBAction) squareSizeChange: (id)sender ;
/*!
 * @abstract The search becomes or is no more specific to the selected item
 * @param sender The control which value was changed
 */
- (IBAction) specificSquareChange: (id)sender ;
/*!
 * @abstract The reference item was changed
 * @param sender The control which value was changed
 */
- (IBAction) referenceAction :(id)sender ;
/*!
 * @abstract Delete the selected item's align result
 * @param sender The button
 */
- (IBAction) cancelAction :(id)sender ;
/*!
 * @abstract Start aligning
 * @param sender The button
 */
- (IBAction) alignAction :(id)sender ;

@end

#endif
