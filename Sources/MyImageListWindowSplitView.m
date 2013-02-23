//
//  Lynkeos
//  $Id: MyImageListWindowSplitView.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Tue May 22 2007.
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

#include "MyGuiConstants.h"
#include "MyImageListWindow.h"

#define K_PROCESS_PANE_MIN_HEIGHT   100.0
#define K_LIST_PANE_MIN_HEIGHT      200.0
#define K_MARGIN_PANE_MIN_WIDTH     300.0
#define K_IMAGE_PANE_MIN_WIDTH      340.0

//! Recursive function that aborts any editing in the view that is about to be
//! removed from its container
static void abortEditingInView( NSView *v )
{
   NSEnumerator *l = [[v subviews] objectEnumerator];
   NSControl *c;

   while( (c = [l nextObject]) != nil )
   {
      if ( [c respondsToSelector:@selector(abortEditing)] )
         [c abortEditing];
      if ( [[c subviews] count] != 0 )
         abortEditingInView(c);
   }
}

@implementation MyImageListWindow(SplitView)

// Collapse and expand the splitviews for the new kind of display
- (void) updateSplitViewsForDisplay:(LynkeosProcessingViewFrame_t)display
{
   NSView *processPane, *listPane, *marginPane, *imagePane;
   NSRect r = NSMakeRect(0.0,0.0,0.0,0.0);

   listPane = [[_listSplit subviews] objectAtIndex:0];
   processPane = [[_listSplit subviews] objectAtIndex:1];
   marginPane = [[_imageSplit subviews] objectAtIndex:0];
   imagePane = [[_imageSplit subviews] objectAtIndex:1];

   // Manage the splitviews collapsing
   if ( _currentProcessDisplay != display )
   {
      NSSize newSize;

      switch ( _currentProcessDisplay  )
      {
         case BottomTab:
            switch ( display )
            {
               case SeparateView:
                  // Collapse the process pane
                  r.origin = [_processSubview frame].origin;
                  [_listSplit replaceSubview:_processSubview
                                        with:[[NSView alloc] initWithFrame:r]];
                  [_listSplit adjustSubviews];
                  break;
               case BottomTab_NoList:
                  // Collapse the list pane
                  r.origin = [_listSubview frame].origin;
                  [_listSplit replaceSubview:_listSubview
                                        with:[[NSView alloc] initWithFrame:r]];
                  [_listSplit adjustSubviews];
                  break;
               case SeparateView_NoList:
                  // Collapse the margin
                  r.origin = [_marginSubview frame].origin;
                  [_imageSplit replaceSubview:_marginSubview
                                         with:[[NSView alloc] initWithFrame:r]];
                  [_imageSplit adjustSubviews];
                  break;
               default:
                  NSAssert( NO, @"Unexpected process display transition" );
            }
            break;

         case BottomTab_NoList:
            switch ( display )
            {
               case BottomTab:
                  // Expand the list pane
                  [_listSplit replaceSubview:listPane with:_listSubview];
                  newSize = [processPane frame].size;
                  newSize.height -= [_listSubview frame].size.height;
                  if ( newSize.height < K_PROCESS_PANE_MIN_HEIGHT )
                     newSize.height = K_PROCESS_PANE_MIN_HEIGHT;
                     [processPane setFrameSize:newSize];
                  [_listSplit adjustSubviews];
                  break;
               case SeparateView:
                  // Collapse process and expand list
                  r.origin = [_processSubview frame].origin;
                  [_listSplit replaceSubview:_processSubview
                                        with:[[NSView alloc] initWithFrame:r]];
                  [_listSplit replaceSubview:listPane with:_listSubview];
                  [_listSplit adjustSubviews];
                  break;
               case SeparateView_NoList:
                  // Collapse the image margin
                  r.origin = [_marginSubview frame].origin;
                  [_imageSplit replaceSubview:_marginSubview
                                         with:[[NSView alloc] initWithFrame:r]];
                  [_imageSplit adjustSubviews];
                  break;
               default:
                  NSAssert( NO, @"Unexpected process display transition" );
            }
            break;

         case SeparateView:
            switch ( display )
            {
               case BottomTab:
                  // Expand the process pane
                  [_listSplit replaceSubview:processPane with:_processSubview];
                  newSize = [listPane frame].size;
                  newSize.height -= [_processSubview frame].size.height;
                  if ( newSize.height < K_LIST_PANE_MIN_HEIGHT )
                     newSize.height = K_LIST_PANE_MIN_HEIGHT;
                     [listPane setFrameSize:newSize];
                  [_listSplit adjustSubviews];
                  break;
               case BottomTab_NoList:
                  // Collapse list and expand the process
                  r.origin = [_listSubview frame].origin;
                  [_listSplit replaceSubview:_listSubview
                                        with:[[NSView alloc] initWithFrame:r]];
                  [_listSplit replaceSubview:processPane with:_processSubview];
                  [_listSplit adjustSubviews];
                  break;
               case SeparateView_NoList:
                  // Collapse the image margin pane
                  r.origin = [_marginSubview frame].origin;
                  [_imageSplit replaceSubview:_marginSubview
                                         with:[[NSView alloc] initWithFrame:r]];
                  [_imageSplit adjustSubviews];
                  break;
               default:
                  NSAssert( NO, @"Unexpected process display transition" );
            }
            break;

         case SeparateView_NoList:
            // Expand the margin pane
            [_imageSplit replaceSubview:marginPane with:_marginSubview];
            newSize = [imagePane frame].size;
            newSize.width -= [_marginSubview frame].size.width;
            if ( newSize.width < K_MARGIN_PANE_MIN_WIDTH )
               newSize.width = K_MARGIN_PANE_MIN_WIDTH;
               [imagePane setFrameSize:newSize];
            [_imageSplit adjustSubviews];

            switch ( display )
            {
               case BottomTab:
                  // Expand the process pane and the list pane
                  [_listSplit replaceSubview:processPane with:_processSubview];
                  [_listSplit replaceSubview:listPane with:_listSubview];
                  [_listSplit adjustSubviews];
                  break;
               case BottomTab_NoList:
                  // Expand the process pane and collapse the list pane
                  [_listSplit replaceSubview:processPane with:_processSubview];
                  r.origin = [_listSubview frame].origin;
                  [_listSplit replaceSubview:_listSubview
                                        with:[[NSView alloc] initWithFrame:r]];
                  [_listSplit adjustSubviews];
                  break;
               case SeparateView:
                  // Expand the list pane and collapse the process pane
                  [_listSplit replaceSubview:listPane with:_listSubview];
                  r.origin = [_processSubview frame].origin;
                  [_listSplit replaceSubview:_processSubview
                                        with:[[NSView alloc] initWithFrame:r]];
                  [_listSplit adjustSubviews];
                  break;
               default:
                  NSAssert( NO, @"Unexpected process display transition" );
            }
            break;
      }
   }
}

- (void) validateSplitControls
{
   switch( _currentProcessDisplay )
   {
      case BottomTab:
         [_listMarginButton setEnabled:
                       (_authorizedProcessDisplays & SeparateView_NoList) != 0];
         [_listSplitButton setEnabled:NO];
         [_procMarginButton setEnabled:
                       (_authorizedProcessDisplays & SeparateView_NoList) != 0];
         [_expandProcessButton setEnabled:
                          (_authorizedProcessDisplays & BottomTab_NoList) != 0];
         [_processSplitButton setEnabled:NO];
         [_detachProcessButton setEnabled:
                              (_authorizedProcessDisplays & SeparateView) != 0];
         break;
      case BottomTab_NoList:
         [_listMarginButton setEnabled:NO];
         [_listSplitButton setEnabled:NO];
         [_procMarginButton setEnabled:
                       (_authorizedProcessDisplays & SeparateView_NoList) != 0];
         [_expandProcessButton setEnabled:NO];
         [_processSplitButton setEnabled:
                                 (_authorizedProcessDisplays & BottomTab) != 0];
         [_detachProcessButton setEnabled:
                       (_authorizedProcessDisplays & SeparateView_NoList) != 0];
         break;
      case SeparateView:
         [_listMarginButton setEnabled:
                       (_authorizedProcessDisplays & SeparateView_NoList) != 0];
         [_listSplitButton setEnabled:
                                 (_authorizedProcessDisplays & BottomTab) != 0];
         [_procMarginButton setEnabled:NO];
         [_expandProcessButton setEnabled:NO];
         [_processSplitButton setEnabled:NO];
         [_detachProcessButton setEnabled:NO];
         break;
      case SeparateView_NoList:
         [_listMarginButton setEnabled:NO];
         [_listSplitButton setEnabled:NO];
         [_procMarginButton setEnabled:NO];
         [_expandProcessButton setEnabled:NO];
         [_processSplitButton setEnabled:NO];
         [_detachProcessButton setEnabled:NO];
         break;
   }
}

- (void) setProcessView:(NSView*)newView
            withDisplay:(LynkeosProcessingViewFrame_t)display
{
   NSScrollView *processView = nil;

   if ( _processingView != nil )
   {
      // Abort any editing
      abortEditingInView(_processingView);
      NSScrollView *enclosing = (NSScrollView*)[_processingView superview];
      [enclosing setDocumentView:[[[NSView alloc] initWithFrame:
                                     NSMakeRect(0.0,0.0,1.0,1.0)] autorelease]];
   }

   // Select the correct process view (embedded in the main window or
   // in a separate window)
   if ( display == SeparateView || display == SeparateView_NoList )
   {
      processView = _detachedProcessPane;
      if ( _currentProcessDisplay == BottomTab ||
           _currentProcessDisplay == BottomTab_NoList )
      {
         // Open the separate window
         [_processWindow makeKeyAndOrderFront:self];
         [NSApp addWindowsItem:_processWindow title:[_processWindow title]
                      filename:NO];
      }
   }
   else if ( display == BottomTab || display == BottomTab_NoList )
   {
      processView = _processPane;
      if ( _currentProcessDisplay == SeparateView ||
           _currentProcessDisplay == SeparateView_NoList )
      {
         // Close the separate window
         [_processWindow orderOut:self];
         [NSApp removeWindowsItem:_processWindow];
      }
   }

   // Collapse and expand splitviews
   [self updateSplitViewsForDisplay:display];

   _currentProcessDisplay = display;
   if ( _processingView != newView )
      _processingView = newView;
   else
      // For processing view change, the validation is done by
      // activateProcessingView after having updated the authorization
      [self validateSplitControls];

   // Add the subview in its container
   [processView setDocumentView:newView];

   // Set the menus title
   NSString *showHideTitle, *attachDetachTitle;

   if ( _currentProcessDisplay == BottomTab ||
        _currentProcessDisplay == SeparateView )
      showHideTitle = NSLocalizedString(@"Hide list",@"Hide list menu");
   else
      showHideTitle = NSLocalizedString(@"Show list",@"Show list menu");

   if ( _currentProcessDisplay == BottomTab ||
        _currentProcessDisplay == BottomTab_NoList )
      attachDetachTitle = NSLocalizedString(@"Detach process",
                                            @"Detach process menu");
   else
      attachDetachTitle = NSLocalizedString(@"Attach process",
                                            @"Attach process menu");

   NSMenu *viewMenu = [[[NSApp mainMenu]itemWithTag:K_VIEW_MENU_TAG] submenu];
   [[viewMenu itemWithTag:K_HIDE_LIST_TAG] setTitle:showHideTitle];
   [[viewMenu itemWithTag:K_DETACH_PROCESS_TAG] setTitle:attachDetachTitle];
}

- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin
       ofSubviewAt:(int)offset
{
   float size = 0.0;

   // Minimum size is for left or upper subview
   NSAssert1( offset == 0, @"constrainMinCoordinate called for subview %d",
              offset );
   if ( sender == _imageSplit )
   {
      if( _currentProcessDisplay == BottomTab
          || _currentProcessDisplay ==  SeparateView )
         size = K_MARGIN_PANE_MIN_WIDTH;
   }
   else if ( sender == _listSplit )
   {
      switch( _currentProcessDisplay )
      {
         case BottomTab:
            size = K_LIST_PANE_MIN_HEIGHT;
            break;
         case SeparateView: // List subview cannot be shrinked
            size = [[[sender subviews] objectAtIndex:0] frame].size.height;
            break;
         default: NSAssert( NO, @"List splitview resize while collapsed" );
      }
   }
   else
      NSAssert( NO, @"Unexpected splitview in constrainMinCoordinate" );

   return( proposedMin + size );
}

- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax
       ofSubviewAt:(int)offset
{
   float size = 0.0;

   // Maximum size is used to set the minimum size of the right or bottom subview
   NSAssert1( offset == 0, @"constrainMaxCoordinate called for subview %d",
              offset );
   if ( sender == _imageSplit )
   {
      if( _currentProcessDisplay == BottomTab
          || _currentProcessDisplay ==  SeparateView )
         size = K_IMAGE_PANE_MIN_WIDTH;
      else
         // Image subview cannot be shrinked
         size = [[[sender subviews] objectAtIndex:1] frame].size.width;
   }
   else if ( sender == _listSplit )
   {
      switch( _currentProcessDisplay )
      {
         case BottomTab:
            size = K_PROCESS_PANE_MIN_HEIGHT;
            break;
         case SeparateView: // Process subview cannot be expanded
            size = 0;
            break;
         default: NSAssert( NO, @"List splitview resize while collapsed" );
      }
   }
   else
      NSAssert( NO, @"Unexpected splitview in constrainMaxCoordinate" );

   return( proposedMax - size );
}

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
   BOOL collapse = NO;

   // Disable standard splitview collapsing as it is not programatically expandable
   // The following code will be activated when NSSplitView is upgraded
#if 0
   if ( sender == _imageSplit )
   {
      collapse = ( subview == [[sender subviews] objectAtIndex:0]
                   && (_authorizedProcessDisplays & SeparateView_NoList) != 0 );
   }
   else if ( sender == _listSplit )
   {
      collapse = ( (subview == [[sender subviews] objectAtIndex:0]
                    && (_authorizedProcessDisplays & BottomTab_NoList)) ||
                   (subview == [[sender subviews] objectAtIndex:1]
                    && (_authorizedProcessDisplays & SeparateView)) );
   }
   else
      NSAssert( NO, @"Unexpected splitview in canCollapseSubview" );
#endif

   return( collapse );
}
@end