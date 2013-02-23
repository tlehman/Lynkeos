//
//  Lynkeos
//  $Id: MyLucyRichardsonView.h 479 2008-11-23 14:28:07Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sat Nov 3 2007.
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
 * @abstract View controller of the Lucy/Richardson deconvolution.
 */
#ifndef __MYLUCYRICHARDSONVIEW_H
#define __MYLUCYRICHARDSONVIEW_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "LynkeosProcessingView.h"
#include "LynkeosLogFields.h"
#include "MyLucyRichardson.h"

/*!
 * @abstract Kind of PSF
 * @ingroup Processing
 */
typedef enum
{
   GaussianPSF = 0,
   SelectionPSF,
   ImageFilePSF
} PsfKind_t;

/*!
 * @abstract Derived parameter type which stores also some view info
 * @ingroup Processing
 */
@interface MyLucyRichardsonViewParameters : MyLucyRichardsonParameters
{
@public
   PsfKind_t     _psfKind;          //!< The kind of PSF
   double        _gaussianRadius;   //!< Radius, for gaussian PSF
   LynkeosIntegerRect _selection;   //!< Selection rectangle, for selection PSF
   NSURL        *_psfURL;           //!< PSF file, for image file PSF
}
@end

/*!
 * @abstract View controller for Lucy/Richardson deconvolution
 * @ingroup Processing
 */
@interface MyLucyRichardsonView : NSObject <LynkeosProcessingView,
                                            MyLucyRichardsonDelegate>
{
   IBOutlet NSView      *_panel;                 //!< Our view
   IBOutlet NSTextField *_iterationText;         //!< Number of iterations
   IBOutlet NSStepper   *_iterationStepper; //!< Stepper for the nb of iterations
   IBOutlet NSPopUpButton *_psfPopup;            //!< Choice of the kind of PSF
   IBOutlet NSImageView *_psfImage;              //!< Display of the PSF
   IBOutlet NSBox       *_gaussBox;              //!< Show/Hide gauss param
   IBOutlet NSTextField *_radiusText;            //!< Gauss radius text value
   IBOutlet NSSlider    *_radiusSlider;          //!< Gauss radius slider
   IBOutlet NSBox       *_fileBox;               //!< Show/Hide file params
   IBOutlet NSButton    *_saveButton;            //!< For saving the PSF
   IBOutlet NSButton    *_loadButton;            //!< Load a PSF
   IBOutlet NSButton    *_startButton;           //!< Start the Lucy Richardson
   //! Whether to show intermediate images
   IBOutlet NSButton    *_progressButton;
   IBOutlet NSTextField *_counterText;           //!< Iteration counter display

   id <LynkeosViewDocument> _document;           //!< Our document
   id <LynkeosWindowController> _window;         //!< Our window controller
   id <LynkeosImageView>  _imageView;            //!< To display the result
   id <LynkeosImageView>  _realImageView;        //!< If the previous is a proxy
   NSOutlineView         *_textView;             //!< Items list outline view
   LynkeosLogFields      *_logRadius;            //!< Log slider / text combination

   LynkeosProcessableImage *_item;               //!< Item being processed
   MyLucyRichardsonViewParameters *_params;      //!< Lucy Richardson parameters
   BOOL                       _isProcessing;     //!< Is a process running
   u_short                    _currentIteration; //!< Iteration counter
}

/*!
 * @abstract The number of iterations was changed
 * @param sender The control which value has changed
 */
- (IBAction) iterationAction:(id)sender ;
/*!
 * @abstract The kind of PSF was changed
 * @param sender The control which value has changed
 */
- (IBAction) psfTypeAction:(id)sender ;
/*!
 * @abstract The gaussian PSF radius was changed
 * @param sender The control which value has changed
 */
- (IBAction) radiusAction:(id)sender ;
/*!
 * @abstract Load the PSF from a file
 * @param sender The button
 */
- (IBAction) loadAction:(id)sender ;
/*!
 * @abstract Save the current PSF in a file
 * @param sender The button
 */
- (IBAction) saveAction:(id)sender ;
/*!
 * @abstract Start processing the Lucy Richardson deconvolution
 * @param sender The button
 */
- (IBAction) startProcess:(id)sender ;
@end

#endif
