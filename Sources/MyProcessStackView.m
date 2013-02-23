//
//  Lynkeos
//  $Id: MyProcessStackView.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sat Oct 27 2007.
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

#include "MyProcessStackView.h"

#include "MyDocument.h"
#include "MyPluginsController.h"
#include "ProcessStackManager.h"

/*!
 * @abstract Custom cell used to place NSViews in the outline view cells
 */
@interface MyViewCell : NSTextFieldCell
{
   NSView *_view;    //!< The view to display in the outline view
}
@end

@interface MyButtonCell : NSButtonCell
{
   BOOL _isValid;
}
@end

@interface MyPopupButtonCell : NSPopUpButtonCell
{
   BOOL _isValid;
}
@end

@interface MyProcessStackView(Private)
- (void) tidyStack ;
- (void) reloadList ;
- (void) hilightChange:(NSNotification*)notif ;
- (void) processStarted:(NSNotification*)notif ;
- (void) processEnded:(NSNotification*)notif ;
- (void) processStackEnded:(NSNotification*)notif ;
- (void) deleteProcessing:(id <LynkeosProcessingView>)pView ;
- (void) addProcessing:(NSArray*)indexes ;
@end

@implementation MyViewCell
- (id) init
{
   if ( (self = [super init]) != nil )
      _view = nil;

   return( self );
}

- (void) setObjectValue:(id <NSCopying>)object
{
   id val = nil;

   if ( [(NSObject*)object isKindOfClass:[NSView class]] )
      _view = (NSView*)object ;

   else
   {
      val = object;
      _view = nil ;
   }

   [super setObjectValue:val];
}

- (id) objectValue
{
   if ( _view != nil )
      return( _view );
   else
      return( [super objectValue] );
}

- (void) drawWithFrame:(NSRect) cellFrame inView:(NSView *) controlView
{
   if ( _view != nil )
   {
      [_view setFrame: cellFrame];

      if ( [_view superview] != controlView )
         [controlView addSubview: _view];
   }
   [super drawWithFrame: cellFrame inView: controlView];
}
@end

@implementation MyButtonCell
- (void) setObjectValue:(id <NSCopying>)object
{
   _isValid = (object != nil);
   if ( _isValid )
      [super setObjectValue:object];
}

- (void) drawWithFrame:(NSRect) cellFrame inView:(NSView *) controlView
{
   if ( _isValid )
      [super drawWithFrame:cellFrame inView:controlView];
}
@end

@implementation MyPopupButtonCell
- (void) setObjectValue:(id <NSCopying>)object
{
   _isValid = (object != nil);
   [super setObjectValue:object];
}

- (void) drawWithFrame:(NSRect) cellFrame inView:(NSView *) controlView
{
   if ( _isValid )
      [super drawWithFrame:cellFrame inView:controlView];
}
@end

@implementation MyProcessStackView(Private)
- (void) tidyStack
{
   if ( _item != nil )
      [_item release];
   _item = nil;
   if ( _stack != nil )
      [_stack release];
   _stack = nil;

   NSEnumerator *procViewList = [_procViewControllers objectEnumerator];
   id <LynkeosProcessingView> v;
   while( (v = [procViewList nextObject]) != nil )
      [v setActiveView:NO];

   NSView *sub;
   while ( (sub = [[_view subviews] lastObject]) != nil )
      [sub removeFromSuperviewWithoutNeedingDisplay];

   [_procViewControllers removeAllObjects];
}

- (void) reloadList
{
   // Delete all processing views
   NSView *v;
   while ( (v = [[_view subviews] lastObject]) != nil )
      [v removeFromSuperviewWithoutNeedingDisplay];
   [_view reloadData];
}

- (void) hilightChange:(NSNotification*)notif
{
   LynkeosImageProcessingParameter *param;
   LynkeosProcessableImage *item;
   NSTableColumn *tableColumn = [_view tableColumnWithIdentifier:@"process"];
   double columnWidth = [tableColumn minWidth];

   // Get the new item
   [_window getItemToProcess:&item andParameter:&param forView:self];

   if ( item != _item )
   {
      // Tidy things before updating
      [self tidyStack];
      _item = item;

      // Retrieve the new stack if any
      if ( _item != nil )
      {
         [_item retain];
         _stack = (NSMutableArray*)[_item getProcessingParameterWithRef:
                                                             K_PROCESS_STACK_REF
                                                   forProcessing:nil goUp:NO];

         // Look for the new process views
         if ( _stack != nil )
         {
            NSArray *procViews =[[MyPluginsController defaultPluginController]
                                                            getProcessingViews];
            const int nProcViews = [procViews count];

            [_stack retain];
            NSEnumerator *procList = [_stack objectEnumerator];
            LynkeosImageProcessingParameter *param;

            while( (param = [procList nextObject]) != nil )
            {
               Class c = [param processingClass];
               id <NSObject> config = nil;
               LynkeosProcessingViewRegistry *pView = nil;
               int i;
               for( i = 0; i < nProcViews; i++ )
               {
                  pView = [procViews objectAtIndex:i];
                  if ( [pView->controller isViewControllingProcess:c
                                                        withConfig:&config] )
                     break;
               }

               // And instantiate each with ourself as window and document proxy
               NSAssert( i < nProcViews && pView != nil,
                         @"Process without view" );
               id <LynkeosProcessingView> view = [[(id <LynkeosProcessingView>)
                     [pView->controller alloc] initWithWindowController:self
                                                               document:self
                                                          configuration:config]
                                                                   autorelease];
               // Put it in the process view array
               [_procViewControllers addObject:view];
               [view setActiveView:YES];

               double viewWidth= [[view getProcessingView] frame].size.width;
               if ( viewWidth > columnWidth )
                  columnWidth = viewWidth;
            }
         }
      }

      // Finally, redisplay the outline view
      [self reloadList];
      [tableColumn setMinWidth:columnWidth];
      if ( [tableColumn maxWidth] < columnWidth )
         [tableColumn setMaxWidth:columnWidth];
      if ( [tableColumn width] < columnWidth )
         [tableColumn setWidth:columnWidth];
      // And the image
      [_imageView displayItem:_item];
   }
}

- (void) processStarted:(NSNotification*)notif
{
   // If the stack was created for this process, get it now
   if ( _stack == nil )
   {
      _stack = (NSMutableArray*)[_item getProcessingParameterWithRef:
                                                             K_PROCESS_STACK_REF
                                                     forProcessing:nil goUp:NO];
      if ( _stack != nil )
         [_stack retain];
   }
   _isProcessing = YES;

   // Propagate the notification to the "sub processing views"
   [[NSNotificationCenter defaultCenter] postNotificationName:[notif name]
                                                       object:self
                                                     userInfo:[notif userInfo]];
}

- (void) processEnded:(NSNotification*)notif
{
   // Propagate the notification to the "sub processing views"
   [[NSNotificationCenter defaultCenter] postNotificationName:[notif name]
                                                       object:self
                                                     userInfo:[notif userInfo]];
}

- (void) processStackEnded:(NSNotification*)notif
{
   _isProcessing = NO;

   // Propagate the notification to the "sub processing views"
   [[NSNotificationCenter defaultCenter] postNotificationName:[notif name]
                                                       object:self
                                                     userInfo:[notif userInfo]];

   [_imageView displayItem:_item];
}

- (void) deleteProcessing:(id <LynkeosProcessingView>)pView
{
   unsigned int idx = [_procViewControllers indexOfObject:pView];

   // Delete the processing
   [pView setActiveView:NO];
   NSView *v = [pView getProcessingView];
   if ( [[_view subviews] indexOfObject:v] != NSNotFound )
      [v removeFromSuperviewWithoutNeedingDisplay];
   [_procViewControllers removeObjectAtIndex:idx];
   [_stack removeObjectAtIndex:idx];
   [self reloadList];

   // Update the processings result
   if ( [_stack count] > 0 )
   {
      LynkeosImageProcessingParameter *param;
      if ( idx < [_stack count] )
         param = [_stack objectAtIndex:idx];
      else
         param = [_stack lastObject];
      [self startProcess:[param processingClass]
                 forItem:_item parameters:param];
   }
   else
   {
      [_item revertToOriginal];
      [self processStackEnded:nil];
   }
}

- (void) addProcessing:(NSArray*)indexes
{
   // Retrieve the indexes
   u_int stackIdx = [[indexes objectAtIndex:0] intValue];
   u_int processIndex = [[indexes objectAtIndex:1] intValue];

   // Allocate the processing view
   LynkeosProcessingViewRegistry *reg =
      [[[MyPluginsController defaultPluginController] getProcessingViews]
                                                    objectAtIndex:processIndex];
   id <LynkeosProcessingView> pView =
      [[[reg->controller alloc] initWithWindowController:self
                                                document:self
                                        configuration:reg->config] autorelease];

   // Insert it in the processing view array
   if ( stackIdx == NSNotFound )
      [_procViewControllers addObject:pView];
   else
      [_procViewControllers insertObject:pView atIndex:stackIdx];

   // Put a placeholder in the parameters stack (so that we give a nil parameter
   // to this processing view)
   if ( _stack == nil )
   {
      // Create a brand new one
      _stack = [[NSMutableArray array] retain];
      [_item setProcessingParameter:(id <LynkeosProcessingParameter>)_stack
                           withRef:K_PROCESS_STACK_REF forProcessing:nil];
   }   
   if ( stackIdx == NSNotFound )
   {
      [_stack addObject:[NSNull null]];
      stackIdx = [_stack count]-1;
   }
   else
      [_stack insertObject:[NSNull null] atIndex:stackIdx];

   // Activate the new view
   [pView setActiveView:YES];

   // Get the processing parameters and put them in the params array
   LynkeosImageProcessingParameter *param =
                 (LynkeosImageProcessingParameter*)[pView getCurrentParameters];
   [param setProcessingClass:[pView processingClass]];
   [_stack replaceObjectAtIndex:stackIdx withObject:param];

   // Reload the table
   [self reloadList];
}
@end

@implementation MyProcessStackView(OutlineView)
- (BOOL) outlineView:(NSOutlineView*)outlineView shouldSelectItem:(id)item
{
   return ( [item conformsToProtocol:@protocol(LynkeosProcessingView)]
            && !_isProcessing );
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item
{
   LynkeosImageProcessingParameter *params;

   return ( item != self 
            && [item conformsToProtocol:@protocol(LynkeosProcessingView)]
            && ( (params = (LynkeosImageProcessingParameter*)
                                             [item getCurrentParameters]) == nil
                 || ![params isExcluded] ) );
}

- (void)outlineViewItemDidExpand:(NSNotification *)notification
{
   // This may have pushed some cells out of the clip view,
   // which have not been redrawn and which view is still in the clip view
   NSRect outLineRect = [_view visibleRect];
   int r, nr = [_view numberOfRows];
   for ( r = 0; r < nr; r++ )
   {
      id item = [_view itemAtRow:r];
      if ( [item isKindOfClass:[NSView class]] // Views are second level items
           && !NSIntersectsRect([_view rectOfRow:r], outLineRect)
           && [item superview] != nil )
         [item removeFromSuperview];
   }
}

- (void)outlineViewItemDidCollapse:(NSNotification *)notification
{
   id <LynkeosProcessingView> v =
                             [[notification userInfo] objectForKey:@"NSObject"];
   NSAssert( [v conformsToProtocol:@protocol(LynkeosProcessingView)],
             @"Attempt to collapse a non view item" );
   [[v getProcessingView] removeFromSuperview];
}

- (id) outlineView:(NSOutlineView *)outlineView child:(int)index 
            ofItem:(id)item
{
   if ( item == nil )
   {
      int cnt = [_procViewControllers count];
      if ( index > 0 )
         return( [_procViewControllers objectAtIndex:cnt-index] );
      else
         return( self );
   }
   else
   {
      if ( item == self )
         return( nil );
      else
      {
         NSAssert( [item conformsToProtocol:@protocol(LynkeosProcessingView)],
                   @"First level item shall be a processing view");
         NSAssert( index == 0, @"No more than one process per pane" );
         return( [item getProcessingView] );
      }
   }
}

- (BOOL) outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
   return ( item != self 
            && [item conformsToProtocol:@protocol(LynkeosProcessingView)] );
}

- (int) outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
   if ( item == nil )
      return( [_procViewControllers count]+1 );
   else if ( item != self
             && [item conformsToProtocol:@protocol(LynkeosProcessingView)] )
      return( 1 );
   else
      return( 0 );
}

- (id) outlineView:(NSOutlineView *)outlineView 
       objectValueForTableColumn:(NSTableColumn *)tableColumn
            byItem:(id)item
{
   id columnId = [tableColumn identifier];
   BOOL isTitle = [item conformsToProtocol:@protocol(LynkeosProcessingView)];

   if ( [columnId isEqual:@"outline"] )
   {
      if ( isTitle && item != self )
      {
         LynkeosImageProcessingParameter *param =
                  (LynkeosImageProcessingParameter*)[item getCurrentParameters];
         NSAssert( param != nil,
                   @"Inconsistent image processing without parameters" );

         return( [NSNumber numberWithBool:![param isExcluded]] );
      }
      else
         return( nil );
   }
   else if ( [columnId isEqual:@"process"] )
   {
      if ( item == self )
         return( nil );
      else if ( isTitle )
      {
         NSString *title, *toolTitle, *key, *tip;
         NSImage *icon;
         [[item class] getProcessingTitle:&title toolTitle:&toolTitle key:&key
                                     icon:&icon tip:&tip forConfig:nil];
         return( title );
      }
      else
         return( item );
   }
   else if ( [columnId isEqual:@"delete"] )
   {
      if ( isTitle && item != self )
         return( [NSNumber numberWithInt:NSOffState] );
      else
         return( nil );
   }
   else if ( [columnId isEqual:@"add"] )
   {
      if ( isTitle )
         return( [NSNumber numberWithInt:0] );
      else
         return( nil );
   }
   else
      return( nil );
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object
     forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
   // Do not change the stack while processing
   if ( _isProcessing )
      return;

   id columnId = [tableColumn identifier];
   NSAssert( [item conformsToProtocol:@protocol(LynkeosProcessingView)],
             @"setObjectValue not on a view" );

   if ( item != self && [columnId isEqual:@"outline"] )
   {
      BOOL excluded = ![object boolValue];
      // Mark whether this process is used
      LynkeosImageProcessingParameter *param =
                  (LynkeosImageProcessingParameter*)[item getCurrentParameters];
      [param setExcluded:excluded];
      if ( excluded )
         [outlineView collapseItem:item];

      // Update the processings result by restarting
      [self startProcess:[param processingClass]
                 forItem:_item parameters:param];
   }
   else if ( item != self && [columnId isEqual:@"delete"] )
   {
      // Delete the processing (after a while because deleting view content
      // inside one of its delegate method is not safe).
      [[NSRunLoop currentRunLoop] performSelector:@selector(deleteProcessing:)
                                           target:self
                                         argument:item
                                            order:0
                                            modes:
                                [NSArray arrayWithObject:NSDefaultRunLoopMode]];

   }
   else if ( [columnId isEqual:@"add"] )
   {
      // Insert a processing (same remark as above)
      [[NSRunLoop currentRunLoop] performSelector:@selector(addProcessing:)
                                           target:self
                                         argument:
                               [NSArray arrayWithObjects:
                                  [NSNumber numberWithInt:
                                     [_procViewControllers indexOfObject:item]],
                                  [NSNumber numberWithInt:
                                     [[[tableColumn dataCell] itemAtIndex:
                                                       [object intValue]] tag]],
                                  nil]
                                            order:0
                                            modes:
                                [NSArray arrayWithObject:NSDefaultRunLoopMode]];
   }
}

- (float)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
   if ( [item conformsToProtocol:@protocol(LynkeosProcessingView)] )
      // On this line, we display the process name
      return( _defaultRowHeight );
   else
      // This one is for displaying the process view (which is "item")
      return( [item frame].size.height );
}
@end

@implementation MyProcessStackView

#pragma mark = LynkeosWindowController protocol
- (NSDictionary*) windowSizes
{
   [self doesNotRecognizeSelector:_cmd];
   return( nil );
}
- (NSOutlineView*) getTextView { return( [_window getTextView] ); }
// We manage the image view, do not let the process controllers access it
- (id <LynkeosImageView>) getImageView { return( nil ); }
- (id <LynkeosImageView>) getRealImageView { return( _imageView ); }
- (id <LynkeosProcessableItem>) highlightedItem { return( [_window highlightedItem] ); }
- (void) highlightItem :(id <LynkeosProcessableItem>)item { [_window highlightItem:item]; }
- (void) setListSelectionAuthorization: (BOOL)auth { ; }
- (void) setDataModeSelectionAuthorization: (BOOL)auth { ; }
- (void) setItemSelectionAuthorization: (BOOL)auth { ; }
- (void) setItemEditionAuthorization: (BOOL)auth { ; }
- (void) setProcessing:(Class)c andIdent:(NSString*)ident
         authorization:(BOOL)auth
 { [_window setProcessing:c andIdent:ident authorization:auth]; }

- (void) getItemToProcess:(LynkeosProcessableImage**)item
             andParameter:(LynkeosImageProcessingParameter**)param
                  forView:(id <LynkeosProcessingView>)sender
{
   unsigned int idx = [_procViewControllers indexOfObject:sender];

   NSAssert( idx != NSNotFound, @"Calling process view not in the stack" );
   *item = _item;
   *param = [_stack objectAtIndex:idx];
   if ( [*param isEqual:[NSNull null]] )
      *param = nil;
}

- (void) saveImage:(LynkeosStandardImageBuffer*)image
         withBlack:(double*)black white:(double*)white gamma:(double*)gamma
{ [_window saveImage:image withBlack:black white:white gamma:gamma]; }
- (LynkeosStandardImageBuffer*) loadImage
{ return( [_window loadImage] ); }

#pragma mark = LynkeosViewDocument protocol
- (void) startProcess: (Class) processingClass
       withEnumerator: (NSEnumerator*)enumerator
           parameters:(id <NSObject>)params
{ [self doesNotRecognizeSelector:_cmd]; }

- (void) startProcess: (Class) processingClass
              forItem: (LynkeosProcessableImage*)item
           parameters: (LynkeosImageProcessingParameter*)params
{
   NSAssert( item == _item, @"Inconsistent item for processing");

   // Just pass it on to the document
   [_document startProcess:processingClass
                      forItem:item
                   parameters:params];
}

- (void) stopProcess { [_document stopProcess]; }
- (oneway void) itemWasProcessed:(id <LynkeosProcessableItem>)item
{ [self doesNotRecognizeSelector:_cmd]; }
- (id <LynkeosImageList>) imageList { return( [_document imageList] ); }
- (id <LynkeosImageList>) darkFrameList { return( [_document darkFrameList] ); }
- (id <LynkeosImageList>) flatFieldList { return( [_document flatFieldList] ); }
- (id <LynkeosImageList>) currentList { return( [_document currentList] ); }
- (ListMode_t) listMode { return( [_document listMode] ); }
- (DataMode_t) dataMode { return( [_document dataMode] ); }
- (id <LynkeosProcessingParameter>) getProcessingParameterWithRef:(NSString*)ref 
                                            forProcessing:(NSString*)processing
{
   return( [_document getProcessingParameterWithRef:ref
                                     forProcessing:processing
                                              goUp:YES] );
}
- (id <LynkeosProcessingParameter>) getProcessingParameterWithRef:(NSString*)ref 
                                             forProcessing:(NSString*)processing
                                                             goUp:(BOOL)goUp
{
   return( [_document getProcessingParameterWithRef:ref
                                      forProcessing:processing
                                               goUp:goUp] );
}
- (void) setProcessingParameter:(id <LynkeosProcessingParameter>)parameter
                        withRef:(NSString*)ref 
                  forProcessing:(NSString*)processing
{
   [_document setProcessingParameter:parameter
                             withRef:ref
                       forProcessing:processing];
}

- (void) setListMode :(ListMode_t)mode
{ [_document setListMode:mode]; }

- (void) setDataMode:(DataMode_t)mode
{ [_document setDataMode:mode]; }

#pragma mark = LynkeosProcessingView protocol

+ (BOOL) isStandardProcessingViewController { return(YES); }

+ (ProcessingViewKind_t) processingViewKindForConfig:(id <NSObject>)config
{
   NSAssert( config == nil,
             @"Process stack manager does not support configuration" );
   return(OtherProcessingKind);
}

+ (BOOL) isViewControllingProcess:(Class)processingClass
                       withConfig:(id <NSObject>*)config
{
   *config = nil;
   return( NO );
}

+ (void) getProcessingTitle:(NSString**)title
                  toolTitle:(NSString**)tooTitle
                        key:(NSString**)key
                       icon:(NSImage**)icon
                        tip:(NSString**)tip
                  forConfig:(id <NSObject>)config
{
   NSAssert( config == nil,
             @"Process stack manager does not support configuration" );
   *title = NSLocalizedString(@"ProcessStackMenu",
                              @"Process stack menu title");
   *tooTitle = NSLocalizedString(@"ProcessStackTool",
                                 @"Process stack tool title");
   *key = @"p";
   *icon = [NSImage imageNamed:@"ProcessStack"];
   *tip = NSLocalizedString(@"ProcessStackTip",@"Process Stack tooltip");
}

+ (unsigned int) allowedDisplaysForConfig:(id <NSObject>)config
{
   NSAssert( config == nil,
             @"Process stack manager does not support configuration" );
   return( BottomTab|BottomTab_NoList|SeparateView|SeparateView_NoList );
}

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _window = nil;
      _document = nil;
      _imageView = nil;
      _item = nil;
      _stack = nil;
      _procViewControllers = [[NSMutableArray array] retain];
      _isProcessing = NO;

      [NSBundle loadNibNamed:@"MyProcessStackView" owner:self];

      // Detach the outline view from the original scrollview (it will be put
      // inside another one)
      [_view removeFromSuperviewWithoutNeedingDisplay];
      [_view retain];

      // Set the custom cell for the process column
      NSTableColumn *tableColumn = [_view tableColumnWithIdentifier:@"process"];
      MyViewCell *cell = [[[MyViewCell alloc] initTextCell:@""] autorelease];
      [tableColumn setDataCell:cell];

      // Set the custom cell for the delete column
      tableColumn = [_view tableColumnWithIdentifier:@"delete"];
      MyButtonCell *bCell =
                         [[[MyButtonCell alloc] initTextCell:@"-"] autorelease];
      [bCell setButtonType: NSMomentaryPushInButton];
      [bCell setBezelStyle:NSCircularBezelStyle];
      [bCell setControlSize:NSSmallControlSize];
      [tableColumn setDataCell:bCell];

      // And set the custom popup cell for the add column
      tableColumn = [_view tableColumnWithIdentifier:@"add"];
      MyPopupButtonCell *pCell =
                     [[[MyPopupButtonCell alloc] initTextCell:@""] autorelease];
      [pCell addItemWithTitle:NSLocalizedString(@"AddProcess",
                                              @"Process stack add menu title")];
      NSEnumerator *procViews =
         [[[MyPluginsController defaultPluginController] getProcessingViews]
                                                              objectEnumerator];
      u_int pViewIndex = 0;
      LynkeosProcessingViewRegistry *procView;
      while ( (procView = [procViews nextObject]) != nil )
      {
         NSString *title, *toolTitle, *key, *tip;
         NSImage *icon;
         if ( [procView->controller processingViewKindForConfig:
                                     procView->config] == ImageProcessingKind )
         {
            [procView->controller getProcessingTitle:&title
                                           toolTitle:&toolTitle key:&key
                                                icon:&icon tip:&tip
                                           forConfig:nil];
            [pCell addItemWithTitle:title];
            [[pCell lastItem] setTag:pViewIndex];
         }
         pViewIndex++;
      }
      [pCell setControlSize:NSSmallControlSize];
      [pCell setFont:[NSFont menuFontOfSize:10.0]];
      [tableColumn setDataCell:pCell];

      // Set the custom cell for the outline column
      tableColumn = [_view tableColumnWithIdentifier:@"outline"];
      bCell = [[[MyButtonCell alloc] initTextCell:@""] autorelease];
      [bCell setEditable: YES];
      [bCell setAllowsMixedState: NO];
      [bCell setButtonType: NSSwitchButton];
      [bCell setControlSize:NSSmallControlSize];
      [tableColumn setDataCell:bCell];

      _defaultRowHeight = [_view rowHeight];
   }

   return( self );
}

- (id) initWithWindowController: (id <LynkeosWindowController>)window
                       document: (id <LynkeosViewDocument>)document
                  configuration: (id <NSObject>)config
{
   NSAssert( config == nil,
             @"Process stack manager does not support configuration" );

   if ( (self = [self init]) != nil )
   {
      // Register the document and window
      _window = (MyImageListWindow*)window;
      _document = document;
      _imageView = [_window getImageView];
   }

   return( self );
}

- (void) dealloc
{
   if (_item != nil )
      [_item release];
   if ( _stack != nil )
      [_stack release];
   [_procViewControllers release];
   [_view release];
   [super dealloc];
}

- (NSView*) getProcessingView { return( _view ); }

- (LynkeosProcessingViewFrame_t) preferredDisplay { return( SeparateView ); }

- (void) setActiveView:(BOOL)active
{
   NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

   if ( active )
   {
      // Authorize the selections
      [_window setListSelectionAuthorization:NO];
      [_window setDataModeSelectionAuthorization:YES];
      [_window setItemSelectionAuthorization:YES];
      [_window setItemEditionAuthorization:NO];

      // Delete the selection rectangle
      [_imageView setSelection:LynkeosMakeIntegerRect(0,0,0,0)
                     resizable:NO movable:NO];

      // Register for notifications
      [center addObserver:self
                 selector:@selector(hilightChange:)
                     name: NSOutlineViewSelectionDidChangeNotification
                   object:[_window getTextView]];
      [center addObserver:self
                 selector:@selector(processStarted:)
                     name: LynkeosProcessStartedNotification
                   object:_document];
      [center addObserver:self
                 selector:@selector(processEnded:)
                     name: LynkeosProcessEndedNotification
                   object:_document];
      [center addObserver:self
                 selector:@selector(processStackEnded:)
                     name: LynkeosProcessStackEndedNotification
                   object:_document];
      [center addObserver:self
                 selector:@selector(hilightChange:)
                     name: LynkeosDataModeChangeNotification
                   object:_document];

      // Synchronize the display
      [self hilightChange:nil];
   }
   else
   {
      // Stop receiving notifications
      [center removeObserver:self];
      // And get rid of all the processing controllers
      [self tidyStack];
      [_view reloadData];
   }
}

- (id <LynkeosProcessingParameter>) getCurrentParameters
{
   // This is not a real processing view
   [self doesNotRecognizeSelector:_cmd];
   return( nil );
}

- (Class) processingClass
{
   // This is not a real processing view
   [self doesNotRecognizeSelector:_cmd];
   return( nil );
}
@end
