//
//  Lynkeos
//  $Id: MyChromaticAlignerView.h 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun Mar 30 2008.
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
 * @abstract View controller for the chromatic alignment.
 */
#ifndef __MYCHROMATICALIGNERVIEW_H
#define __MYCHROMATICALIGNERVIEW_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "LynkeosProcessingView.h"

#include "LynkeosStandardImageBuffer.h"
#include "MyImageStackerView.h"

/*!
 * @abstract Reference string for this process
 * @ingroup Processing
 */
extern NSString * const myChromaticAlignerRef;

/*!
 * @abstract Reference for reading/setting the chromatic dispersion results.
 * @ingroup Processing
 */
extern NSString * const myChromaticAlignerOffsetsRef;

/*!
 * @abstract Chromatic alignment offsets
 * @ingroup Processing
 */
@interface MyChromaticAlignParameter : NSObject <LynkeosProcessingParameter>
{
@public
   u_short             _numOffsets;  //!< Number of offsets (or planes)
   NSPointArray        _offsets;     //!< Offsets for each color plane
}

/*!
 * @abstract Dedicated initializer
 * @param size The number of plane offsets
 */
- (id) initWithOffsetNumber:(u_short)size;
@end

/*!
 * @abstract View controlling the chromatic alignment 
 * @ingroup Processing
 */
@interface MyChromaticAlignerView : NSObject <LynkeosProcessingView>
{
   IBOutlet NSView      *_panel;                   //!< The view
   IBOutlet NSMatrix    *_offsetNames;             //!< Name of color planes
   IBOutlet NSMatrix    *_offsetTextFields;        //!< Offset value text fields
   IBOutlet NSMatrix    *_offsetSliders;           //!< Offset value sliders
   IBOutlet NSButton    *_automaticOffsetsButton;  //!< To auto align colors
   //! Stack again, taking the chromatic correction into account
   IBOutlet NSButton    *_reStackButton; 
   IBOutlet NSButton    *_originalCheckBox;        //!< Blink with the original

   id <LynkeosViewDocument> _document;             //!< The doc we belong to
   id <LynkeosWindowController> _window;           //!< Our window controller
   id <LynkeosImageView> _imageView;               //!< To display the image
   NSOutlineView        *_textView;                //!< The list of items

   LynkeosProcessableImage *_item;                 //!< The item being corrected
   MyChromaticAlignParameter *_params;             //!< The color offsets
   LynkeosStandardImageBuffer *_originalImage;     //!< Uncorrected image
   LynkeosStandardImageBuffer *_processedImage;    //!< Corrected image
   //! Initial offsets, when starting the item
   NSPointArray          _originalOffsets;
   //! Expansion that was used during stacking
   u_short               _stackingFactor;

   MyImageStackerView   *_stacker;               //!< To instruct it to re-stack
}

/*!
 * @abstract A plane offset was manually changed
 * @param sender The control which value was modified
 */
- (IBAction) changeOffset:(id)sender ;

/*!
 * @abstract Blink between orinal and corrected images
 * @param sender The control which value was modified
 */
- (IBAction) showOriginal:(id)sender ;

/*!
 * @abstract Try to align the planes automatically
 * @param sender The control which value was modified
 */
- (IBAction) automaticOffsets:(id)sender ;

/*!
 * @abstract Stack the images again, taking the chromatic correction into account
 * @param sender The control which value was modified
 */
- (IBAction) reStack:(id)sender ;

@end

#endif
