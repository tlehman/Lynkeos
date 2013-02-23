//
//  Lynkeos
//  $Id: MyImageStackerView.h 506 2011-03-26 18:40:46Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sat Jun 21 2007.
//  Copyright (c) 2007-2011. Jean-Etienne LAMIAUD
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
 * @abstract Definitions of the "stacker" view.
 */
#ifndef __MYIMAGE_STACKER_VIEW_H
#define __MYIMAGE_STACKER_VIEW_H

#import <AppKit/AppKit.h>

#include "LynkeosProcessingView.h"

#include "MyDocument.h"

/*!
 * @abstract View controller of the image stacking
 * @ingroup Processing
 */
@interface MyImageStackerView : NSObject <LynkeosProcessingView>
{
   IBOutlet NSTextField*      _cropX;            //!< X origin of the crop rect
   IBOutlet NSTextField*      _cropY;            //!< Y origin of the crop rect
   IBOutlet NSTextField*      _cropW;            //!< Width of the crop rect
   IBOutlet NSTextField*      _cropH;            //!< Height of the crop rect
   IBOutlet NSButton*	      _doubleSizeCheckBox; //!< Expand the stack
   IBOutlet NSButton*	      _monochromeCheckBox; //!< Stack in monochrome
   IBOutlet NSPopUpButton*    _methodPopup;
   IBOutlet NSTabView*        _methodPane;           //!< Pane for mode parameters
   // Mode panes items
   IBOutlet NSTextField*      _sigmaRejectText;   //!< Text level
   IBOutlet NSSlider*         _sigmaRejectSlider; //!< Slider level
   //! Selection between min/max stacking
   IBOutlet NSMatrix*         _minMaxMatrix;

   IBOutlet NSButton*	      _stackButton;       //!< Start stacking
   IBOutlet NSView*           _panel;             //!< Our view

   id <LynkeosWindowController> _window;          //!< Our window controller
   MyDocument*                _document;          //!< Our document
   NSOutlineView*             _textView;          //!< The items list view
   id <LynkeosImageView>      _imageView;         //!< The view for result image

   BOOL                       _isStacking;        //!< Stacking under process
   //! Whether to refresh each image once processed in the stack
   BOOL                       _imageUpdate;
   BOOL                       _stackedImagesNb;   //!< Number of stacked images
}

/*!
 * @abstract The crop rectangle characteristics were changed
 * @param sender The control which value has changed
 */
- (IBAction) cropRectangleChange :(id)sender ;
/*!
 * @abstract Toggle between regular and double sized stack
 * @param sender The control which value has changed
 */
- (IBAction) doubleSizeAction :(id)sender ;
/*!
 * @abstract Toggle between RGB and grayscale stack
 * @param sender The control which value has changed
 */
- (IBAction) monochromeAction :(id)sender ;
/*!
 * @abstract Change the stacking mode
 * @param sender The popup button
 */
- (IBAction) methodChange:(id)sender ;
/*!
 * @abstract Change the number of standard deviations for rejection
 * @param sender The control originating the change
 */
- (IBAction) sigmaChange:(id)sender ;
/*!
 * @abstract Choose between min or max stacking
 * @param sender The control originating the change
 */
- (IBAction) minMaxChange:(id)sender ;
/*!
 * @abstract Start stacking
 * @param sender The button
 */
- (IBAction) stackAction :(id)sender ;
@end

#endif
