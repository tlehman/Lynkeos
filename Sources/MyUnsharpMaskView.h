//
//  Lynkeos
//  $Id: MyUnsharpMaskView.h 479 2008-11-23 14:28:07Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun Dec 2 2007.
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
 * @abstract View controller of the unsharp mask processing.
 */
#ifndef __MYUNSHARPMASKVIEW_H
#define __MYUNSHARPMASKVIEW_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "LynkeosProcessingView.h"
#include "LynkeosLogFields.h"
#include "MyUnsharpMask.h"

/*!
 * @abstract View controller of the deconvolution processing
 * @ingroup Processing
 */
@interface MyUnsharpMaskView : NSObject <LynkeosProcessingView>
{
   IBOutlet NSView      *_panel;            //!< Our view
   IBOutlet NSSlider    *_radiusSlider;     //!< Gaussian radius slider
   IBOutlet NSTextField *_radiusText;       //!< Gaussian radius text value
   IBOutlet NSSlider    *_gainSlider;       //!< Unsharp gain slider
   IBOutlet NSTextField *_gainText;         //!< Unsharp gain text value
   IBOutlet NSButton    *_gradientButton;   //!< Comute only the gradient
   IBOutlet NSProgressIndicator *_progress; //!< Progress bar

   id <LynkeosViewDocument> _document;     //!< Our document
   id <LynkeosWindowController> _window;   //!< Our window controller
   id <LynkeosImageView> _imageView;       //!< The view for result image
   NSOutlineView        *_textView;        //!< The items list view
   LynkeosLogFields     *_logRadius;       //!< Log slider / text combination

   LynkeosProcessableImage *_item;      //!< The item being processed
   MyUnsharpMaskParameters *_params;       //!< Unsharp mask parameters
   BOOL                  _isProcessing;    //!< Is a process running ?
   NSTimer              *_progressTimer;   //!< Timer for progress bar update
}

/*!
 * @abstract The gaussian radius was changed
 * @param sender The control which value has changed
 */
- (IBAction) radiusChange: (id)sender ;
/*!
 * @abstract The unsharp gain was changed
 * @param sender The control which value has changed
 */
- (IBAction) gainChange: (id)sender ;
/*!
 * @abstract Change between gradient only and full unsharp mask
 * @param sender The control which value has changed
 */
- (IBAction) gradientChange: (id)sender ;

@end

#endif
