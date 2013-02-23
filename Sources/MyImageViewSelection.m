//
//  Lynkeos
//  $Id: MyImageViewSelection.m 499 2010-12-29 16:57:39Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sat Nov 01 2003.
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

#import "MyImageView.h"

#define K_CURSRECT_SIZE 10

#define max(a,b) ((a) > (b) ? a : b )
#define min(a,b) ((a) > (b) ? b : a )

static const NSString
*crossImage = @"cross",
*leftImage = @"left",
*rightImage = @"right",
*topImage = @"top",
*bottomImage = @"bottom",
*topLeftImage = @"topLeft",
*topRightImage = @"topRight",
*bottomLeftImage = @"bottomLeft",
*bottomRightImage = @"bottomRight",
*insideImage = @"hand";

static const NSPoint
crossSpot = {8,8},
leftSpot = {1,7},
rightSpot = {14,7},
topSpot = {7,1},
bottomSpot = {7,14},
topLeftSpot = {1,1},
topRightSpot = {14,1},
bottomLeftSpot = {1,14},
bottomRightSpot = {14,14},
insideSpot = {8,8};

// Utility function to construct the new selection
static short processDrag( long mouse, u_short origin, u_short maximum, 
                          BOOL upright )
{
   long val;

   if ( upright )
      val = mouse > origin ? mouse : origin;
   else
      val = mouse > origin ? origin : mouse;

   if ( val < 0.0 )
      val = 0.0;
   if ( val > maximum )
      val = maximum;

   return( val );
}

@implementation MyImageSelection
- (id) initWithRect:(LynkeosIntegerRect)rect movable:(BOOL)move resizable:(BOOL)resize
{
   if ( (self = [self init]) != nil )
   {
      NSRect vide = { {0.0,0.0}, {0.0,0.0} };
      _rect = rect;

      _resizable = resize;
      _movable = move;

      _left = vide;
      _right = vide;
      _top = vide;
      _bottom = vide;
      _topLeft = vide;
      _topRight = vide;
      _bottomLeft = vide;
      _bottomRight = vide;
      _inside = vide;
   }

   return( self );
}

- (void) processCursorRect:(NSRect*)r cursor:(NSCursor*)cur size:(float)s
           horizontalOrder:(SelectionPosition_t)hPos
             verticalOrder:(SelectionPosition_t)vPos
                   visible:(NSRect)v view:(NSView*)view
{
   if ( hPos == PrecedingSide )
   {
      r->origin.x = (float)_rect.origin.x - s/2.0;
      r->size.width = s;
   }
   else if ( hPos == FollowingSide )
   {
      r->origin.x = (float)_rect.origin.x + (float)_rect.size.width - s/2.0;
      r->size.width = s;
   }
   else
   {
      r->origin.x = (float)_rect.origin.x + s/2.0;
      r->size.width = (float)_rect.size.width - s;
   }

   if ( vPos == PrecedingSide )
   {
      r->origin.y = (float)_rect.origin.y - s/2.0;
      r->size.height = s;
   }
   else if ( vPos == FollowingSide )
   {
      r->origin.y = (float)_rect.origin.y + (float)_rect.size.height - s/2.0;
      r->size.height = s;
   }
   else
   {
      r->origin.y = (float)_rect.origin.y + s/2.0;
      r->size.height = (float)_rect.size.height - s;
   }

   *r = NSIntersectionRect(*r,v);

   if ( r->size.width > 0.0 && r->size.height > 0.0 )
      [view addCursorRect:*r cursor:cur];
}

- (BOOL) isEqual:(id)anObj
{
   if ( ![anObj isKindOfClass:[MyImageSelection class]] )
      return( NO );

   LynkeosIntegerRect r = ((MyImageSelection*)anObj)->_rect;
   return( _rect.origin.x == r.origin.x
           && _rect.origin.y == r.origin.y
           && _rect.size.width == r.size.width
           && _rect.size.height == r.size.height );
}
@end

/*!
 * @category MyImageView(SelectionPrivate)
 * @abstract Selection management part of MyImageView
 */
@interface MyImageView(SelectionPrivate)

/*!
 * @abstract Management of the "off view" scrolling.
 * @discussion This method gets called when the mouse stands still outside the
 *    view to continue auto-scrolling.
 * @param timer The timer which calls this method.
 */
- (void) timerDrag :(NSTimer*)timer ;

@end

@implementation MyImageView(SelectionPrivate)

- (void) timerDrag :(NSTimer*)timer
{
   // Extract the drag event in userInfo, and call drag selector
   [self mouseDragged:[timer userInfo]];
}
@end

@implementation MyImageView(Selection)

- (void) initCursors
{
   _crossCursor = [[[NSCursor alloc] initWithImage:
                                     [NSImage imageNamed: (NSString*)crossImage]
                                           hotSpot:crossSpot] retain];
   _leftCursor = [[[NSCursor alloc] initWithImage:
                                       [NSImage imageNamed:(NSString*)leftImage]
                                          hotSpot:leftSpot] retain];
   _rightCursor = [[[NSCursor alloc] initWithImage:
                                      [NSImage imageNamed:(NSString*)rightImage]
                                           hotSpot:rightSpot] retain];
   _topCursor = [[[NSCursor alloc] initWithImage:
                                        [NSImage imageNamed:(NSString*)topImage]
                                         hotSpot:topSpot] retain];
   _bottomCursor = [[[NSCursor alloc] initWithImage:
                                     [NSImage imageNamed:(NSString*)bottomImage]
                                            hotSpot:bottomSpot] retain];
   _topLeftCursor = [[[NSCursor alloc] initWithImage:
                                    [NSImage imageNamed:(NSString*)topLeftImage]
                                             hotSpot:topLeftSpot] retain];
   _topRightCursor = [[[NSCursor alloc] initWithImage:
                                   [NSImage imageNamed:(NSString*)topRightImage]
                                              hotSpot:topRightSpot] retain];
   _bottomLeftCursor = [[[NSCursor alloc] initWithImage:
                                 [NSImage imageNamed:(NSString*)bottomLeftImage]
                                                hotSpot:bottomLeftSpot] retain];
   _bottomRightCursor = [[[NSCursor alloc] initWithImage:
                                [NSImage imageNamed:(NSString*)bottomRightImage]
                                               hotSpot:bottomRightSpot] retain];
   _insideCursor = [[[NSCursor alloc] initWithImage:
                                    [NSImage imageNamed:(NSString*)insideImage]
                                            hotSpot:insideSpot] retain];
}

-  (void) mouseDown:(NSEvent *)theEvent
{
   NSPoint o = [self convertPoint:[theEvent locationInWindow] fromView:nil];

   // Find the "clicked" selection and where
   NSEnumerator *selectionList = [_selection objectEnumerator];
   MyImageSelection *sel;
   u_short selIndex = 0;

   _selectMode = SelNone;

   while( _selectMode == SelNone && (sel = [selectionList nextObject]) != nil )
   {
      if ( [self mouse:o inRect:sel->_bottomLeft] )
      {
         _selectionOrigin.x = sel->_rect.origin.x + sel->_rect.size.width;
         _selectionOrigin.y = sel->_rect.origin.y + sel->_rect.size.height;
         _lastPoint = sel->_rect.origin;
         _selectMode = SelNormal;
      }
      else if ( [self mouse:o inRect:sel->_bottomRight] )
      {
         _selectionOrigin.x = sel->_rect.origin.x;
         _selectionOrigin.y = sel->_rect.origin.y + sel->_rect.size.height;
         _lastPoint.x = sel->_rect.origin.x + sel->_rect.size.width;
         _lastPoint.y = sel->_rect.origin.y;
         _selectMode = SelNormal;
      }
      else if ( [self mouse:o inRect:sel->_topLeft] )
      {
         _selectionOrigin.x = sel->_rect.origin.x + sel->_rect.size.width;
         _selectionOrigin.y = sel->_rect.origin.y;
         _lastPoint.x = sel->_rect.origin.x;
         _lastPoint.y = sel->_rect.origin.y + sel->_rect.size.height;
         _selectMode = SelNormal;
      }
      else if ( [self mouse:o inRect:sel->_topRight] )
      {
         _selectionOrigin = sel->_rect.origin;
         _lastPoint.x = sel->_rect.origin.x + sel->_rect.size.width;
         _lastPoint.y = sel->_rect.origin.y + sel->_rect.size.height;
         _selectMode = SelNormal;
      }
      else if ( [self mouse:o inRect:sel->_left] )
      {
         _selectionOrigin.x = sel->_rect.origin.x + sel->_rect.size.width;
         _selectionOrigin.y = sel->_rect.origin.y;
         _lastPoint.x = sel->_rect.origin.x;
         _lastPoint.y = sel->_rect.origin.y + sel->_rect.size.height;
         _selectMode = SelH;
      }
      else if ( [self mouse:o inRect:sel->_right] )
      {
         _selectionOrigin = sel->_rect.origin;
         _lastPoint.x = sel->_rect.origin.x + sel->_rect.size.width;
         _lastPoint.y = sel->_rect.origin.y + sel->_rect.size.height;
         _selectMode = SelH;
      }
      else if ( [self mouse:o inRect:sel->_bottom] )
      {
         _selectionOrigin.x = sel->_rect.origin.x;
         _selectionOrigin.y = sel->_rect.origin.y + sel->_rect.size.height;
         _lastPoint.x = sel->_rect.origin.x + sel->_rect.size.width;
         _lastPoint.y = sel->_rect.origin.y;
         _selectMode = SelV;
      }
      else if ( [self mouse:o inRect:sel->_top] )
      {
         _selectionOrigin = sel->_rect.origin;
         _lastPoint.x = sel->_rect.origin.x + sel->_rect.size.width;
         _lastPoint.y = sel->_rect.origin.y + sel->_rect.size.height;
         _selectMode = SelV;
      }
      else if ( [self mouse:o inRect:sel->_inside] )
      {
         _selectionOrigin = sel->_rect.origin;
         _lastPoint = LynkeosIntegerPointFromNSPoint(o);
         _selectMode = SelMove;
      }
      else
         selIndex++;
   }

   if ( _selectMode == SelNone )
   {
      if ( _multipleSelection ||
           [_selection count] == 0 ||
           ((MyImageSelection*)[_selection objectAtIndex:0])->_resizable )
      {
         _selectionOrigin = LynkeosIntegerPointFromNSPoint(o);
         LynkeosIntegerRect r = { _selectionOrigin, {0,0} };
         _lastPoint = _selectionOrigin;
         _inProgressSelection = r;
         _selectMode = SelNormal;
         if ( _multipleSelection )
            // Add a new selection
            _currentSelectionIndex = [_selection count];
         else
            // Modify the only selection
            _currentSelectionIndex = 0;
      }
   }
   else
   {
      _currentSelectionIndex = selIndex;
      NSAssert( sel != nil, @"Modification of a nonexistent selection" );
      _inProgressSelection = sel->_rect;
   }

   if ( _selectMode != SelNone )
      [self setNeedsDisplay:YES];
}

-  (void) mouseDragged:(NSEvent *)theEvent
{
   NSPoint where = [self convertPoint:[theEvent locationInWindow] fromView:nil];
   NSRect inval;
   LynkeosIntegerRect prevSelection;
   float delta;

   // Cancel the autoscroll timer if a regular drag happens
   if ( _autoscrollTimer != nil && [_autoscrollTimer isValid] && 
        [_autoscrollTimer userInfo] != theEvent )
      [_autoscrollTimer invalidate];
   // One way or the other, _autoscrollTimer validity ends at this selector
   _autoscrollTimer = nil;

   if ( _selectMode != SelNone  &&
        ((u_short)where.x != _lastPoint.x || (u_short)where.y != _lastPoint.y) )
   {
      //Adjust scroll to follow mouse if needed
      [self autoscroll:theEvent];

      prevSelection = _inProgressSelection;

      switch ( _selectMode )
      {
         case SelNormal :
            _inProgressSelection.origin.x =
                            processDrag( where.x, _selectionOrigin.x, 
                                          _imageSize.width, NO );
            _inProgressSelection.size.width =
                            processDrag( where.x, _selectionOrigin.x, 
                                         _imageSize.width, YES )
                            - _inProgressSelection.origin.x;
            _inProgressSelection.origin.y =
                            processDrag( where.y, _selectionOrigin.y, 
                                         _imageSize.height, NO );
            _inProgressSelection.size.height =
                            processDrag( where.y, _selectionOrigin.y, 
                                         _imageSize.height, YES )
                            - _inProgressSelection.origin.y;
            break;
         case SelH :
            _inProgressSelection.origin.x =
                                       processDrag( where.x, _selectionOrigin.x,
                                                    _imageSize.width, NO );
            _inProgressSelection.size.width =
                                       processDrag( where.x, _selectionOrigin.x,
                                                    _imageSize.width, YES )
                                       - _inProgressSelection.origin.x;
            break;
         case SelV :
            _inProgressSelection.origin.y =
                                       processDrag( where.y, _selectionOrigin.y,
                                                    _imageSize.height, NO );
            _inProgressSelection.size.height =
                                       processDrag( where.y, _selectionOrigin.y,
                                                    _imageSize.height, YES )
                                       - _inProgressSelection.origin.y;
            break;
         case SelMove :
            delta = where.x - _lastPoint.x;
            if ( delta < - _inProgressSelection.origin.x )
               delta = -_inProgressSelection.origin.x;
            else if ( delta > _imageSize.width - _inProgressSelection.origin.x
                              - _inProgressSelection.size.width )
               delta = _imageSize.width - _inProgressSelection.origin.x
                       - _inProgressSelection.size.width;
            _inProgressSelection.origin.x += delta;
            delta = where.y - _lastPoint.y;
            if ( delta < -_inProgressSelection.origin.y )
               delta = -_inProgressSelection.origin.y;
            else if ( delta > _imageSize.height - _inProgressSelection.origin.y
                              - _inProgressSelection.size.height )
               delta = _imageSize.height - _inProgressSelection.origin.y
                       - _inProgressSelection.size.height;
            _inProgressSelection.origin.y += delta;
            break;
         default:
            break;
      }

      // Invalidate what needs to be redrawn
      if ( _inProgressSelection.origin.x != prevSelection.origin.x )
      {
         inval.origin.x = min( _inProgressSelection.origin.x,
                               prevSelection.origin.x )
                          - 1.0/_zoom;
         inval.size.width = max( _inProgressSelection.origin.x,
                                 prevSelection.origin.x )
                            - inval.origin.x + 1/_zoom;
         inval.origin.y = min( _inProgressSelection.origin.y,
                               prevSelection.origin.y )
                          - 1.0/_zoom;
         inval.size.height = max( _inProgressSelection.origin.y
                                  + _inProgressSelection.size.height,
                                  prevSelection.origin.y
                                  + prevSelection.size.height )
                             - inval.origin.y + 1/_zoom;
         [self setNeedsDisplayInRect:inval];
      }
      if ( _inProgressSelection.origin.x + _inProgressSelection.size.width !=
                             prevSelection.origin.x + prevSelection.size.width )
      {
         inval.origin.x = min( _inProgressSelection.origin.x
                               + _inProgressSelection.size.width,
                               prevSelection.origin.x
                               + prevSelection.size.width )
                          - 1.0/_zoom;
         inval.size.width = max( _inProgressSelection.origin.x
                                 + _inProgressSelection.size.width,
                                 prevSelection.origin.x
                                 + prevSelection.size.width )
                            - inval.origin.x + 1/_zoom;
         inval.origin.y = min( _inProgressSelection.origin.y,
                               prevSelection.origin.y )
                          - 1.0/_zoom;
         inval.size.height = max( _inProgressSelection.origin.y
                                  + _inProgressSelection.size.height,
                                  prevSelection.origin.y
                                  + prevSelection.size.height )
                           - inval.origin.y + 1/_zoom;
         [self setNeedsDisplayInRect:inval];
      }
      if ( _inProgressSelection.origin.y != prevSelection.origin.y )
      {
         inval.origin.x = min( _inProgressSelection.origin.x,
                               prevSelection.origin.x )
                          - 1.0/_zoom;
         inval.size.width = max( _inProgressSelection.origin.x
                                 + _inProgressSelection.size.width,
                                 prevSelection.origin.x
                                 + prevSelection.size.width )
                            - inval.origin.x + 1/_zoom;
         inval.origin.y = min( _inProgressSelection.origin.y,
                               prevSelection.origin.y )
                          - 1.0/_zoom;
         inval.size.height = max( _inProgressSelection.origin.y,
                                  prevSelection.origin.y )
                             - inval.origin.y + 1/_zoom;
         [self setNeedsDisplayInRect:inval];
      }
      if ( _inProgressSelection.origin.y + _inProgressSelection.size.height !=
                            prevSelection.origin.y + prevSelection.size.height )
      {
         inval.origin.x = min( _inProgressSelection.origin.x,
                               prevSelection.origin.x )
                          - 1.0/_zoom;
         inval.size.width = max( _inProgressSelection.origin.x
                                 + _inProgressSelection.size.width,
                                 prevSelection.origin.x
                                 + prevSelection.size.width )
                            - inval.origin.x + 1/_zoom;
         inval.origin.y = min( _inProgressSelection.origin.y
                               + _inProgressSelection.size.height,
                               prevSelection.origin.y
                               + prevSelection.size.height )
                          - 1.0/_zoom;
         inval.size.height = max( _inProgressSelection.origin.y
                                  + _inProgressSelection.size.height,
                                  prevSelection.origin.y
                                  + prevSelection.size.height )
                             - inval.origin.y + 1/_zoom;
         [self setNeedsDisplayInRect:inval];
      }
      _lastPoint = LynkeosIntegerPointFromNSPoint(where);
   }

   // Arm a timer for autoscrolling while mouse stands still
   if ( _selectMode != SelNone )
   {
      _autoscrollTimer = [NSTimer timerWithTimeInterval:0.1 target:self 
                                               selector:@selector(timerDrag:)
                                               userInfo: theEvent
                                                repeats:NO];
      [[NSRunLoop currentRunLoop] addTimer:_autoscrollTimer 
                                   forMode:NSDefaultRunLoopMode];
   }
}

-  (void) mouseUp:(NSEvent *)theEvent
{
   if ( _selectMode != SelNone )
   {
      // Process "clicks"
      NSPoint o = [self convertPoint:[theEvent locationInWindow] fromView:nil];
      if ( _selectMode == SelNormal &&
           o.x == _selectionOrigin.x && o.y == _selectionOrigin.y )
      {
         _inProgressSelection.origin.x = 0;
         _inProgressSelection.origin.y = 0;
         if ( [_selection count] == 0 )
            _inProgressSelection.size = LynkeosIntegerSizeFromNSSize(_imageSize);
         else
         {
            _inProgressSelection.size.width = 0;
            _inProgressSelection.size.height = 0;
            [_selection removeObjectAtIndex:_currentSelectionIndex];
            if ( _currentSelectionIndex >= [_selection count] )
               _currentSelectionIndex = [_selection count] - 1;
         }
      }

      // Set the new selection
      if ( _inProgressSelection.size.width != 0
           || _inProgressSelection.size.height != 0 )
      {
         if ( _currentSelectionIndex < [_selection count] )
         {
            MyImageSelection *sel =
                              [_selection objectAtIndex:_currentSelectionIndex];
            sel->_rect = _inProgressSelection;
         }
         else
         {
            MyImageSelection *sel =
               [[[MyImageSelection alloc] initWithRect:_inProgressSelection
                                        movable:YES resizable:YES] autorelease];
            [_selection addObject:sel];
         }
         _inProgressSelection.size.width = 0;
         _inProgressSelection.size.height = 0;
      }

      _selectMode = SelNone;

      // Delete any running autoscroll timer
      if ( _autoscrollTimer != nil && [_autoscrollTimer isValid] )
      {
         [_autoscrollTimer invalidate];
         _autoscrollTimer = nil;
      }

      // Save the modifiers
      _modifiers = [theEvent modifierFlags];

      // Notify
      [[NSNotificationCenter defaultCenter] postNotificationName:
                              LynkeosImageViewSelectionRectDidChangeNotification
                                                          object: self
                                                        userInfo:
                             [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithInt:_currentSelectionIndex],
                                 LynkeosImageViewSelectionRectIndex,
                                 nil]];

      // Set up all the cursor rectangles
      [[self window] invalidateCursorRectsForView:self];

      [self setNeedsDisplay:YES];
   }
}

- (void)resetCursorRects
{
   NSRect v = [self visibleRect];
   float s = K_CURSRECT_SIZE/_zoom;

   NSEnumerator *selectionList = [_selection objectEnumerator];
   MyImageSelection *sel;

   while ( (sel = [selectionList nextObject]) != nil )
   {
      if ( sel->_rect.size.width != 0 && sel->_rect.size.height != 0 )
      {
         if ( sel->_resizable )
         {
            [sel processCursorRect:&sel->_bottomLeft cursor:_bottomLeftCursor
                              size:s
                   horizontalOrder:PrecedingSide verticalOrder:PrecedingSide
                           visible:v view:self];
            [sel processCursorRect:&sel->_left cursor:_leftCursor size:s
                   horizontalOrder:PrecedingSide verticalOrder:MiddlePosition
                           visible:v view:self];
            [sel processCursorRect:&sel->_topLeft cursor:_topLeftCursor size:s
                   horizontalOrder:PrecedingSide verticalOrder:FollowingSide
                           visible:v view:self];
            [sel processCursorRect:&sel->_top cursor:_topCursor size:s
                   horizontalOrder:MiddlePosition verticalOrder:FollowingSide
                           visible:v view:self];
            [sel processCursorRect:&sel->_topRight cursor:_topRightCursor size:s
                   horizontalOrder:FollowingSide verticalOrder:FollowingSide
                           visible:v view:self];
            [sel processCursorRect:&sel->_right cursor:_rightCursor size:s
                   horizontalOrder:FollowingSide verticalOrder:MiddlePosition
                           visible:v view:self];
            [sel processCursorRect:&sel->_bottomRight cursor:_bottomRightCursor
                              size:s
                   horizontalOrder:FollowingSide verticalOrder:PrecedingSide
                           visible:v view:self];
            [sel processCursorRect:&sel->_bottom cursor:_bottomCursor size:s
                   horizontalOrder:MiddlePosition verticalOrder:PrecedingSide
                           visible:v view:self];
         }
         if ( sel->_movable )
            [sel processCursorRect:&sel->_inside cursor:_insideCursor size:s
                   horizontalOrder:MiddlePosition verticalOrder:MiddlePosition
                           visible:v view:self];
      }
   }

   if ( v.size.width != 0 && v.size.height != 0 )
      [self addCursorRect:v cursor:_crossCursor];
}

@end
