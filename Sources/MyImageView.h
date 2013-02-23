//
//  Lynkeos
//  $Id: MyImageView.h 499 2010-12-29 16:57:39Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Wed Sep 24 2003.
//  Copyright (c) 2003-2008. Jean-Etienne LAMIAUD
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
 * @abstract Definitions for the custom image view
 */
#ifndef __MYIMAGEVIEW_H
#define __MYIMAGEVIEW_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "SMDoubleSlider.h"

#include "LynkeosCommon.h"
#include "LynkeosProcessingView.h"

/*!
 * @abstract Position of a selection side or corner.
 * @discussion Preceding side is left or bottom and following is right or top.
 */
typedef enum
{
   PrecedingSide  = -1,
   MiddlePosition =  0,
   FollowingSide  =  1
} SelectionPosition_t;

/*!
 * @abstract Selection management model object
 */
@interface MyImageSelection : NSObject
{
@public
   BOOL                _resizable;
   BOOL                _movable;
   LynkeosIntegerRect  _rect;
   NSRect              _left, _right, _top, _bottom, 	// Cursor rectangles
                       _topLeft, _topRight, _bottomLeft, _bottomRight, _inside;
}

- (id) initWithRect:(LynkeosIntegerRect)rect movable:(BOOL)move resizable:(BOOL)resize;

- (void) processCursorRect:(NSRect*)r cursor:(NSCursor*)cur size:(float)s
           horizontalOrder:(SelectionPosition_t)hPos
             verticalOrder:(SelectionPosition_t)vPos
                   visible:(NSRect)v view:(NSView*)view;
@end

/*!
 * @abstract Selection dragging mode
 */
typedef enum { SelNone, SelNormal, SelH, SelV, SelMove } MySelectingMode;

/*!
 * @abstract The custom image view.
 * @ingroup Views
 */
@interface MyImageView : NSView <LynkeosImageView>
{
@private
   // For IB
   IBOutlet NSSlider*         _zoomSlider;
   IBOutlet NSTextField*      _zoomField;

   IBOutlet SMDoubleSlider*   _blackWhiteSlider; //!< Black and white levels
   IBOutlet NSSlider*         _gammaSlider;      //!< Level exponent
   IBOutlet NSTextField*      _blackText;
   IBOutlet NSTextField*      _whiteText;
   IBOutlet NSTextField*      _gammaText;

   IBOutlet id _delegate;

   id <LynkeosProcessableItem> _item;
   u_long                     _itemSequenceNumber;

   // Image management
   NSAffineTransform*  _imageTransform;
   NSImageRep*         _imageRep;
   NSSize              _imageSize;
   // Zoom control
   double              _zoom;
   // Selection management
   BOOL                _multipleSelection;
   NSMutableArray      *_selection;         // Contains MyImageSelection objects
   LynkeosIntegerRect  _inProgressSelection; //!< Selection being modified
   u_short             _currentSelectionIndex;
   LynkeosIntegerPoint _selectionOrigin, _lastPoint;
   unsigned int        _modifiers;
   NSCursor            *_crossCursor,                            // Cursors
                       *_leftCursor, *_rightCursor, 
                       *_topCursor, *_bottomCursor, 
                       *_topLeftCursor, *_topRightCursor, 
                       *_bottomLeftCursor, *_bottomRightCursor, 
                       *_insideCursor;
    MySelectingMode    _selectMode;
    NSTimer            *_autoscrollTimer;
}

//! \name IBActions
//! Methods connected to Interface builder actions
//!@{
/*!
 * @abstract Set the zoom according to the slider value
 * @param sender The slider.
 */
- (IBAction)doZoom:(id)sender;

/*!
 * @abstract Zoom in
 * @param sender The button.
 */
- (IBAction)moreZoom:(id)sender;

/*!
 * @abstract Zoom out
 * @param sender The button.
 */
- (IBAction)lessZoom:(id)sender;

/*!
 * @abstract Set the black and white levels for the image
 * @param sender the control that was changed
 */
- (IBAction) blackWhiteChange :(id)sender ;

/*!
 * @abstract Set the gamma correction exponent for the image
 * @param sender the control that was changed
 */
- (IBAction) gammaChange :(id)sender ;

//!@}

/*!
 * @abstract Retrieve the displayed image size
 * @result The image size
 */
- (NSSize) imageSize ;
@end

/*!
 * @abstract Selection handling in MyImageView
 */
@interface MyImageView(Selection)

/*!
 * @abstract Initialize all the selection related cursors
 * @result None 
 */
- (void) initCursors ;

@end

#endif
