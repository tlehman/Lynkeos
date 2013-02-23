//
//  Lynkeos
//  $Id: MyImageView.m 499 2010-12-29 16:57:39Z j-etienne $
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

#include <math.h>

#include "ProcessStackManager.h"
#include "MyImageView.h"

#define K_MAX_ZOOM 4.0

static const double MM_LN_10 = -M_LN10;

/*!
 * @abstract Zoom management part of MyImageView.
 */
@interface MyImageView(Zoom)

/*!
 * @method applyZoom:from:
 * @abstract Set the zoom factor to the required value.
 * @param newZoom The zoom factor to apply
 * @param sender The object asking for zoom
 */
- (void) applyZoom :(double)newZoom from:(id)sender ;

/*!
 * @method stepZoom:
 * @abstract Step the zoom factor to the nearest half integer power of two.
 * @param step The step to apply to the log2 of the zoom factor.
 */
- (void) stepZoom :(double)step;
@end

@implementation MyImageView(Zoom)

- (void) applyZoom :(double)newZoom from:(id)sender
{
    NSSize newFrameSize,
    newBoundsSize = _imageSize;
    NSRect visible = [self visibleRect];

    // Apply zoom
    if ( _imageSize.width != 0 )
    {
        newFrameSize.width = _imageSize.width*newZoom;
        newBoundsSize.width = _imageSize.width;
    }
    else
    {	// NSView don't like null sizes
        newFrameSize.width = 1;
        newBoundsSize.width = 1;
    }

    if ( _imageSize.height != 0 )
    {
        newFrameSize.height = _imageSize.height*newZoom;
        newBoundsSize.height = _imageSize.height;
    }
    else
    {	// NSView don't like null sizes
        newFrameSize.height = 1;
        newBoundsSize.height = 1;
    }

    [self setFrameSize:newFrameSize];
    [self setBoundsSize:newBoundsSize];

    // Adjust scroll to keep center still
    if ( _imageSize.width != 0 && _imageSize.height != 0 )
    {
        visible.origin.x += (1 - _zoom/newZoom)*visible.size.width/2;
        if ( visible.origin.x < 0 )
            visible.origin.x = 0;
        visible.origin.y += (1 - _zoom/newZoom)*visible.size.height/2;
        if ( visible.origin.y < 0 )
            visible.origin.y = 0;
        visible.size.width *= _zoom/newZoom;
        visible.size.height *= _zoom/newZoom;

        [self scrollRectToVisible:visible];
    }

    if ( newZoom != _zoom )
    {
       _zoom = newZoom;
       if ( sender != _zoomField )
          [_zoomField setDoubleValue:_zoom*100.0];
       if ( sender != _zoomSlider )
          [_zoomSlider setDoubleValue:log(_zoom)/log(K_MAX_ZOOM)];

       [[NSNotificationCenter defaultCenter] postNotificationName:
                                       LynkeosImageViewZoomDidChangeNotification
                                                           object:self];       
    }

    // Make me redraw
    [self setNeedsDisplay:YES];
}

- (void) stepZoom :(double)step
{
    double z = log(_zoom)/log(2);

    // Get the wanted half integer value
    if ( step < 0.0 && z > 0.0 )
        z += 0.49999999;
    else if ( step > 0.0 && z < 0.0 )
        z -= 0.49999999;
    z = (double)((int)((z+step)*2))/2.0;
    z = exp(log(2)*z);
    [self applyZoom: z from:nil];
}
@end

@implementation MyImageView

// Initializations and allocation stuff
- (id)initWithFrame:(NSRect)frameRect
{
   LynkeosIntegerRect nowhere = { {0,0}, {0,0} };

   [super initWithFrame:frameRect];

   _item = nil;
   _itemSequenceNumber = 0;
   _imageTransform = nil;
   _imageRep = nil;

   _zoom = 1.0;

   _multipleSelection = NO;
   _selectionOrigin = nowhere.origin;
   _lastPoint = nowhere.origin;
   _selection = [[NSMutableArray array] retain];
   _inProgressSelection = nowhere;
   _currentSelectionIndex = 0;
   _autoscrollTimer = nil;

   [self initCursors];

    return self;
}

- (void) dealloc
{
   if ( _imageRep != nil )
      [_imageRep release];
   if ( _item != nil )
      [_item release];
   if ( _imageTransform != nil )
      [_imageTransform release];

   [_selection release];
   [_crossCursor release];
   [_leftCursor release];
   [_rightCursor release];
   [_topCursor release];
   [_bottomCursor release];
   [_topLeftCursor release];
   [_topRightCursor release];
   [_bottomLeftCursor release];
   [_bottomRightCursor release];
   [_insideCursor release];

   [super dealloc];
}

- (void) awakeFromNib
{
   [_blackText setEnabled:NO];
   [_whiteText setEnabled:NO];
   [_blackWhiteSlider setEnabled:NO];
   [_gammaText setEnabled:NO];
   [_gammaSlider setEnabled:NO];
   [_blackText setStringValue:@""];
   [_whiteText setStringValue:@""];
   [_gammaText setStringValue:@""];   
}

// Image and zoom
- (IBAction)doZoom:(id)sender
{
    double z;

    if ( sender == _zoomSlider )
        z = exp(log(K_MAX_ZOOM)*[sender doubleValue]);
    else
        z = [sender doubleValue]/100.0;
    [self applyZoom: z from:sender];
}

- (IBAction)moreZoom:(id)sender
{
    if ( _zoom < K_MAX_ZOOM )
        [self stepZoom:0.5];
}

- (IBAction)lessZoom:(id)sender
{
    if ( _zoom > 1.0/K_MAX_ZOOM )
        [self stepZoom:-0.5];	// To be improved in stepZoom
}

- (IBAction) blackWhiteChange :(id)sender
{
   // Reconcile slider and text fields
   double black, white;
   if ( sender == _blackWhiteSlider )
   {
      black = [sender doubleLoValue];
      [_blackText setDoubleValue:black];
      white = [sender doubleHiValue];
      [_whiteText setDoubleValue:white];
   }
   else if ( sender == _blackText )
   {
      black = [sender doubleValue];
      white = [_blackWhiteSlider doubleHiValue];
      if ( black > white )
      {
         black = white;
         [sender setDoubleValue:black];
      }
      if ( black < [_blackWhiteSlider minValue] )
         [_blackWhiteSlider setMinValue:black];
      [_blackWhiteSlider setDoubleLoValue:black];
   }
   else if ( sender == _whiteText )
   {
      black = [_blackWhiteSlider doubleLoValue];
      white = [sender doubleValue];
      if ( white < black )
      {
         white = black;
         [sender setDoubleValue:white];
      }
      if ( white > [_blackWhiteSlider maxValue] )
         [_blackWhiteSlider setMaxValue:white];
      [_blackWhiteSlider setDoubleHiValue:white];
   }
   else
      NSAssert(NO,@"Unknown control in blackWhiteChange");

   // Set the levels in the item
   [_item setBlackLevel:black whiteLevel:white gamma:[_gammaText doubleValue]];

   // Refresh the image
   [self updateImage];
   // Make me redraw
   [self setNeedsDisplay:YES];
}

- (IBAction) gammaChange :(id)sender
{
   double gammaCorrect = 1.0;

   // Reconcile controls
   if ( sender == _gammaSlider )
   {
      gammaCorrect = exp(MM_LN_10*[sender doubleValue]);
      [_gammaText setDoubleValue:gammaCorrect];
   }
   else if ( sender == _gammaText )
   {
      gammaCorrect = [sender doubleValue];
      [_gammaSlider setDoubleValue:log(gammaCorrect)/MM_LN_10];
   }
   else
      NSAssert( NO, @"Unknown gamma control" );

   // Set the levels in the item
   [_item setBlackLevel:[_blackText doubleValue]
             whiteLevel:[_whiteText doubleValue]
                  gamma:gammaCorrect];

   // Refresh the image
   [self updateImage];
   // Make me redraw
   [self setNeedsDisplay:YES];
}

- (void) displayItem:(id <LynkeosProcessableItem>)item
{
   NSAffineTransform *transform = nil;
   if ( item != nil )
   {
      // Get the align transform if any
      id <LynkeosViewAlignResult> res =
         (id <LynkeosViewAlignResult>)[item getProcessingParameterWithRef:
                                                           LynkeosAlignResultRef
                                                            forProcessing:
                                                               LynkeosAlignRef];
      if ( res != nil )
         transform = [res alignTransform];
   }

   // Avoid useless updates
   if ( item == _item &&
        ( item == nil ||
          ( [item getSequenceNumber] == _itemSequenceNumber &&
            ( ( _imageTransform == nil && transform == nil )
              || [_imageTransform isEqual:transform] ) ) ) )
      return;

   // Save the parameters
   if ( _imageTransform != nil )
      [_imageTransform release];
   _imageTransform = transform;
   if ( _imageTransform != nil )
      [_imageTransform retain];

   if ( _item != item )
   {
      if ( _item != nil )
         [_item release];
      _itemSequenceNumber = 0;
      _item = item;
      if ( _item != nil )
         [_item retain];
   }
   if ( _item != nil )
      _itemSequenceNumber = [item getSequenceNumber];

   // Display that new image
   [self updateImage];
}

- (void) updateImage
{
   NSImage *image = nil;

   // Cleanup before else
   _imageSize.width = 0.0;
   _imageSize.height = 0.0;
   if ( _imageRep != nil )
   {
      [_imageRep release];
      _imageRep = nil;
   }

   // Get the new image
   if ( _item != nil )
   {
      image = [_item getNSImage];
      _imageRep = [[image bestRepresentationForDevice:nil] retain];
      if ( _imageRep != nil )
      {
         _imageSize.width = [_imageRep pixelsWide];
         _imageSize.height = [_imageRep pixelsHigh];
         [_imageRep setSize:_imageSize];
      }
   }

   double vmin, vmax, black, white, gamma;
   BOOL validRange = NO, validLevels = NO;
   if ( _item != nil )
   {
      validRange = [_item isProcessed]
                   && [_item getMinLevel:&vmin maxLevel:&vmax];
      validLevels= [_item getBlackLevel:&black whiteLevel:&white gamma:&gamma];
   }

   [_blackText setEnabled:(validRange && validLevels)];
   [_whiteText setEnabled:(validRange && validLevels)];
   [_blackWhiteSlider setEnabled:(validRange && validLevels)];
   [_gammaText setEnabled:(validRange && validLevels)];
   [_gammaSlider setEnabled:(validRange && validLevels)];

   if ( validRange )
   {
      [_blackWhiteSlider setMinValue:fmin(vmin,black)];
      [_blackWhiteSlider setMaxValue:fmax(vmax,white)];
      [_blackWhiteSlider setDoubleLoValue:black];
      [_blackWhiteSlider setDoubleHiValue:white];
      [_gammaSlider setDoubleValue:log(gamma)/MM_LN_10];
   }

   if ( validLevels )
   {
      [_blackText setDoubleValue:black];
      [_whiteText setDoubleValue:white];
      [_gammaText setDoubleValue:gamma];
   }
   else
   {
      [_blackText setStringValue:@""];
      [_whiteText setStringValue:@""];
      [_gammaText setStringValue:@""];
   }

   [self applyZoom:_zoom from:nil];
   [[self window] invalidateCursorRectsForView:self];
}

// Drawing
- (void)drawRect:(NSRect)rect
{
   NSGraphicsContext *g = [NSGraphicsContext currentContext];

   if ( _imageRep != nil )
   {
      NSRect r = [self bounds];
      [g saveGraphicsState];
      if ( _imageTransform != nil )
         [_imageTransform concat];
      [_imageRep drawInRect:r];
      [g restoreGraphicsState];
   }

   if ( _selectMode != SelNone || [_selection count] != 0 )
   {
      [g saveGraphicsState];
      [[NSColor orangeColor] set];

      NSEnumerator *selectionList = [_selection objectEnumerator];
      MyImageSelection *sel = nil;
      int i = -1;

      do
      {
         LynkeosIntegerRect r;

         if ( sel == nil )
            r = _inProgressSelection;
         else
            r = sel->_rect;

         if ( r.size.width != 0 && r.size.height != 0 )
         {
            if ( i == _currentSelectionIndex
                 && (_inProgressSelection.size.width != 0
                     || _inProgressSelection.size.height != 0) )
               // Do not display the active selection during modification
               continue;
            if ( sel == nil || i == _currentSelectionIndex )
            {
               [g saveGraphicsState];
               [[NSColor redColor] set];
            }
            [NSBezierPath strokeRect:NSRectFromIntegerRect(r)];
            if ( sel == nil || i == _currentSelectionIndex )
               [g restoreGraphicsState];
         }
         i++;
      } while ( (sel = [selectionList nextObject]) != nil );

      [g restoreGraphicsState];
   }

   // Give an opportunity to add drawings
   [[NSNotificationCenter defaultCenter] postNotificationName:
                                              LynkeosImageViewRedrawNotification
                                                       object:self];
}

- (NSSize) imageSize { return( _imageSize ); }

- (double) getZoom { return ( _zoom ); }

- (void) setZoom:(double)zoom
{
   [self applyZoom:zoom from:nil];
}

- (LynkeosIntegerRect) getSelection
{ return( [self getSelectionAtIndex:_currentSelectionIndex] ); }

- (LynkeosIntegerRect) getSelectionAtIndex:(u_short)index
{
   if ( [_selection count] > 0 )
   {
      MyImageSelection *sel = [_selection objectAtIndex:index];
      NSAssert( sel != nil, @"No selection in non nil selection list" );
      return( sel->_rect );
   }
   else
      return( LynkeosMakeIntegerRect(0, 0, 0, 0) );
}

- (unsigned int) getModifiers { return( _modifiers ); }

- (void) setSelection :(LynkeosIntegerRect)selection
             resizable:(BOOL)resize
               movable:(BOOL)move
{
   LynkeosIntegerRect curSel = [self getSelectionAtIndex:_currentSelectionIndex];

   if (    curSel.origin.x != selection.origin.x
        || curSel.origin.y != selection.origin.y
        || curSel.size.width != selection.size.width
        || curSel.size.height != selection.size.height )
   {
      [_selection removeAllObjects];
      _currentSelectionIndex = 0;

      [self setSelection:selection atIndex:0
               resizable:resize movable:move];
      _multipleSelection = NO;
   }
}

- (void) setSelection :(LynkeosIntegerRect)selection
               atIndex:(u_short)index
             resizable:(BOOL)resize
               movable:(BOOL)move
{
   LynkeosIntegerRect selRect = selection;
   LynkeosIntegerRect oldRect = [self getSelectionAtIndex:_currentSelectionIndex];

   // Do not allow selection to be outside image, even partly
   if ( _imageSize.width == 0 || _imageSize.height == 0 )
   {
      selRect.origin.x = 0;
      selRect.origin.y = 0;
      selRect.size.width = 0;
      selRect.size.height = 0;
   }
   else
   {
      if ( selRect.origin.x < 0 )
         selRect.origin.x = 0;
      else if ( selRect.origin.x+selRect.size.width > _imageSize.width )
         selRect.origin.x = _imageSize.width - selRect.size.width - 1;
      if ( selRect.origin.y < 0 )
         selRect.origin.y = 0;
      else if ( selRect.origin.y+selRect.size.height > _imageSize.height)
         selRect.origin.y = _imageSize.height - selRect.size.height - 1;
   }

   if ( selRect.size.width == 0 || selRect.size.height == 0 )
   {
      if ( index < [_selection count] )
         [_selection removeObjectAtIndex:index];
      u_short newCount = [_selection count];
      if ( _currentSelectionIndex >= newCount )
      {
         if ( newCount != 0 )
            _currentSelectionIndex = [_selection count] - 1;
         else
            _currentSelectionIndex = 0;
      }
   }
   else
   {
      u_short selectionsCount = [_selection count];
      NSAssert( index <= selectionsCount,
                @"Trying to add a selection at an invalid index" );
      MyImageSelection *sel =
                  [[[MyImageSelection alloc] initWithRect:selRect
                                                  movable:move
                                                 resizable:resize] autorelease];

      _multipleSelection = YES;
      _modifiers = 0;

      if ( index < selectionsCount )
      {
         if ( [sel isEqual:[_selection objectAtIndex:index]] )
            return; // Nothing to do
         [_selection replaceObjectAtIndex:index withObject:sel];
      }
      else
         [_selection addObject:sel];
      _currentSelectionIndex = index;
   }

   [self setNeedsDisplay:YES];
   [[self window] invalidateCursorRectsForView:self];

   // If the selection was adjusted, notify it
   if (    selRect.origin.x != oldRect.origin.x
        || selRect.origin.y != oldRect.origin.y
        || selRect.size.width != oldRect.size.width
        || selRect.size.height != oldRect.size.height )
   {
      [[NSNotificationCenter defaultCenter] postNotificationName:
                              LynkeosImageViewSelectionRectDidChangeNotification
                                                            object: self
                                                         userInfo:
                                    [NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithInt:index],
                                             LynkeosImageViewSelectionRectIndex,
                                             nil]];
   }
}
@end
