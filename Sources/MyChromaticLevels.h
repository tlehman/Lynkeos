//
//  Lynkeos
//  $Id: MyChromaticLevels.h 479 2008-11-23 14:28:07Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Wed Apr 23 2008.
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
 * @abstract View controller for chromatic levels and gamma correction.
 */
#ifndef __MYCHROMATICLEVELSVIEW_H
#define __MYCHROMATICLEVELSVIEW_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "LynkeosProcessingView.h"

#include "LynkeosStandardImageBuffer.h"

/*!
 * @abstract View and process for modifying an image levels and gamma
 * @ingroup Processing
 */
@interface MyChromaticLevelsView : NSObject <LynkeosProcessingView>
{
   IBOutlet NSView      *_panel;               //!< Our view
   IBOutlet NSMatrix    *_planeNames;          //!< Name of the color planes
   IBOutlet NSMatrix    *_levelsNames;         //!< Name of the levels
   IBOutlet NSMatrix    *_blackGammaTextFields; //!< Alternatively black / gamma
   IBOutlet NSMatrix    *_blackGammaSteppers;   //!< Same with steppers
   IBOutlet NSMatrix    *_whiteTextFields;      //!< White level
   IBOutlet NSMatrix    *_whiteSteppers;        //!< Steppers for white level
   IBOutlet NSMatrix    *_levelsSliders;        //!< Sliders for white levels
   IBOutlet NSComboBox  *_levelStep;            //!< Step to be applied to levels
   IBOutlet NSComboBox  *_gammaStep;            //!< Step to be applied to gamma

   id <LynkeosViewDocument> _document;          //!< Our document
   id <LynkeosWindowController> _window;        //!< Our window controller
   id <LynkeosImageView> _imageView;            //!< Where the image is displayed
   NSOutlineView        *_textView;             //!< Item list outline view

   LynkeosProcessableImage *_item;              //!< The item being tuned
}

/*!
 * @abstract Black, white or gamma level for a plane has been changed
 * @param sender The control which value has been modified
 */
- (IBAction) changeLevel:(id)sender ;

/*!
 * @abstract The step for black and white levels has been changed
 * @param sender The control which value has been modified
 */
- (IBAction) changeLevelStep:(id)sender ;

/*!
 * @abstract The step for gamma has been changed
 * @param sender The control which value has been modified
 */
- (IBAction) changeGammaStep:(id)sender ;

@end

#endif
