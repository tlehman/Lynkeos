//
//  Lynkeos
//  $Id: MyDeconvolutionView.h 479 2008-11-23 14:28:07Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Mon Oct 1 2007.
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
 * @abstract View controller of the deconvolution processing.
 */
#ifndef __MYDECONVOLUTIONVIEW_H
#define __MYDECONVOLUTIONVIEW_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "LynkeosProcessingView.h"
#include "LynkeosLogFields.h"
#include "MyDeconvolution.h"

/*!
 * @abstract View controller of the deconvolution processing
 * @ingroup Processing
 */
@interface MyDeconvolutionView : NSObject <LynkeosProcessingView>
{
   IBOutlet NSView      *_panel;           //!< Our view
   IBOutlet NSSlider    *_radiusSlider;    //!< Gaussian radius slider
   IBOutlet NSTextField *_radiusText;      //!< Gaussian radius text value
   IBOutlet NSSlider    *_thresholdSlider; //!< Noise threshold value slider
   IBOutlet NSTextField *_thresholdText;   //!< Noise threshold value text
   IBOutlet NSProgressIndicator *_progress; //!< Progress bar

   id <LynkeosViewDocument> _document;     //!< Our document
   id <LynkeosWindowController> _window;   //!< Our window controller
   id <LynkeosImageView> _imageView;       //!< The view for result image
   NSOutlineView        *_textView;        //!< The items list view
   LynkeosLogFields     *_logRadius;       //!< Log slider / text combination

   LynkeosProcessableImage *_item;         //!< The item being processed
   MyDeconvolutionParameters *_params;     //!< Deconvolution parameters
   BOOL                  _isProcessing;    //!< Is a process running ?
   //! To reduce progress bar updating overhead
   NSTimer              *_progressTimer;
}

/*!
 * @abstract The gaussian radius was changed
 * @param sender The control which value has changed
 */
- (IBAction) radiusChange: (id)sender ;

/*!
 * @abstract The noise threshold was chaged
 * @param sender The control which value has changed
 */
- (IBAction) thresholdChange: (id)sender ;

@end

#endif
