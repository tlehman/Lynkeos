//
//  Lynkeos
//  $Id: MyImageAlignerView.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Wed Nov 11 2006.
//  Copyright (c) 2006-2008. Jean-Etienne LAMIAUD
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

#include "MyUserPrefsController.h"
#include "LynkeosColumnDescriptor.h"
#include "MyImageListItem.h"
#include "MyImageAligner.h"
#include "MyImageAlignerPrefs.h"
#include "MyImageAlignerView.h"

static NSMutableDictionary *monitorDictionary = nil;

/*!
 * @abstract Lightweight object for validating and redraw
 * @discussion This object monitors the document for validating the process
 *    activation, and the window controller for drawing the outline view cells
 * @ingroup Processing
 */
@interface MyImageAlignerMonitor : NSObject
{
   NSObject <LynkeosViewDocument>      *_document; //!< Our document
   NSObject <LynkeosWindowController>  *_window;   //!< Our window controller
}

/*!
 * @abstract Process the notification of a new document creation
 * @discussion It will be used to create a monitor object for the document.
 * @param notif The notification
 */
+ (void) documentDidOpen:(NSNotification*)notif;
/*!
 * @abstract Process the notification of document closing
 * @param notif The notification
 */
+ (void) documentWillClose:(NSNotification*)notif;

/*!
 * @abstract Dedicated initializer
 * @param document The document to monitor
 * @param window The window controller to monitor
 * @result Initialized 
 */
- (id) initWithDocument:(NSObject <LynkeosViewDocument>*)document
       windowController:(NSObject <LynkeosWindowController> *)window;
/*!
 * @abstract The document current list was changed
 * @param notif The notification
 */
- (void) changeOfList:(NSNotification*)notif;
/*!
 * @abstract Process the display of aligned items
 * @param notif The notification
 */
- (void) textViewWillDisplayCell:(NSNotification*)notif;
@end

@implementation MyImageAlignerMonitor
+ (void) documentDidOpen:(NSNotification*)notif
{
   id <LynkeosViewDocument> document = [notif object];
   id <LynkeosWindowController> windowCtrl =
                [[notif userInfo] objectForKey:LynkeosUserinfoWindowController];

   // Create a monitor object for this document
   [monitorDictionary setObject:
      [[[MyImageAlignerMonitor alloc] initWithDocument:document
                                      windowController:windowCtrl] autorelease]
                         forKey:[NSData dataWithBytes:&document
                                               length:sizeof(id)]];
}

+ (void) documentWillClose:(NSNotification*)notif
{
   id <LynkeosViewDocument> document = [notif object];

   // Delete the monitor object
   [monitorDictionary removeObjectForKey:[NSData dataWithBytes:&document
                                                        length:sizeof(id)]];
}

- (id) initWithDocument:(NSObject <LynkeosViewDocument>*)document
       windowController:(NSObject <LynkeosWindowController> *)window
{
   if ( (self = [self init]) != nil )
   {
      _document = document;
      _window = window;

      NSNotificationCenter *notif = [NSNotificationCenter defaultCenter];

      // Register for outline view redraw
      [notif addObserver:self
                selector:@selector(textViewWillDisplayCell:)
                    name:LynkeosOutlineViewWillDisplayCellNotification
                  object:[_window getTextView]];

      // Register for list change notifications
      [notif addObserver:self
                selector:@selector(changeOfList:)
                    name: LynkeosItemAddedNotification
                  object:_document];
      [notif addObserver:self
                selector:@selector(changeOfList:)
                    name: LynkeosItemRemovedNotification
                  object:_document];

      // And set initial authorization
      [self changeOfList:nil];
   }

   return( self );
}

- (void) dealloc
{
   // Unregister for all notifications
   [[NSNotificationCenter defaultCenter] removeObserver:self];

   [super dealloc];
}

- (void) textViewWillDisplayCell:(NSNotification*)notif
{
   NSDictionary *dict = [notif userInfo];
   NSString* column = [[dict objectForKey:LynkeosOutlineViewColumn]  identifier];
   id <LynkeosProcessable> item = [dict objectForKey:LynkeosOutlineViewItem];
   id cell = [dict objectForKey:LynkeosOutlineViewCell];

   if ( [column isEqual:@"index"] || [column isEqual:@"name"] )
   {
      NSColor *color;
      if ( [item getProcessingParameterWithRef:LynkeosAlignResultRef
                                 forProcessing:LynkeosAlignRef] != nil )
         color = [NSColor greenColor];
      else
         color = [NSColor textColor];
      [cell setTextColor:color];
   }
}

- (void) changeOfList:(NSNotification*)notif
{
   [_window setProcessing:[MyImageAlignerView class] andIdent:nil
            authorization:([[[_document imageList] imageArray] count] != 0)];
}
@end

@interface MyImageAlignerView(Private)
- (void) highlightChange:(NSNotification*)notif ;
- (void) selectionRectChanged:(NSNotification*)notif ;
- (void) processStarted:(NSNotification*)notif ;
- (void) processEnded:(NSNotification*)notif ;
- (void) itemChanged:(NSNotification*)notif ;
- (void) listModified:(NSNotification*)notif ;
@end

@implementation MyImageAlignerView(Private)

- (void) highlightChange:(NSNotification*)notif
{
   if ( _isAligning && ! _imageUpdate )
      return;

   id <LynkeosProcessableItem> item = [_window highlightedItem];
   LynkeosIntegerRect selRect = LynkeosMakeIntegerRect(0,0,0,0);
   BOOL privateSquare = NO;

   [_imageView displayItem:item];

   if ( !_isAligning )
   {
      MyImageAlignerListParameters *params;

      if ( item != nil )
      {
         params =[item getProcessingParameterWithRef:myImageAlignerParametersRef
                                       forProcessing:myImageAlignerRef];
         NSAssert( params != nil, @"No alignment parameters found" );

         selRect.origin = params->_alignOrigin;

         [_searchFieldX setFloatValue:selRect.origin.x];
         [_searchFieldX setEnabled:YES];
         [_searchFieldY setFloatValue:selRect.origin.y];
         [_searchFieldY setEnabled:YES];

         [_privateSearch setEnabled:YES];
         privateSquare = [params isMemberOfClass:
                                              [MyImageAlignerParameters class]];
         [_privateSearch setIntValue: (privateSquare ? NSOnState : NSOffState)];

         [_refCheckBox setIntValue:
            (item==params->_referenceItem ? NSOnState : NSOffState)];
         [_refCheckBox setEnabled:YES];

         id <LynkeosAlignResult> align = (id <LynkeosAlignResult>)
                       [item getProcessingParameterWithRef:LynkeosAlignResultRef
                                             forProcessing:LynkeosAlignRef
                                                      goUp:NO];
         [_cancelButton setEnabled:(align != nil)];
      }
      else
      {
         [_searchFieldX setStringValue:@""];
         [_searchFieldX setEnabled:NO];
         [_searchFieldY setStringValue:@""];
         [_searchFieldY setEnabled:NO];
         [_privateSearch setIntValue:NSOffState];
         [_privateSearch setEnabled:NO];
         [_refCheckBox setIntValue:NSOffState];
         [_refCheckBox setEnabled:NO];
         [_cancelButton setEnabled:YES];
      }

      params =
            [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                                       forProcessing:myImageAlignerRef];
      if ( params != nil )
         selRect.size = params->_alignSize;

      // Display the selection rectangle, if there is an image for it
      if ( item != nil && [(MyImageListItem*)item numberOfChildren] == 0 )
         [_imageView setSelection:selRect resizable:!privateSquare movable:YES];
   }
}

- (void) selectionRectChanged:(NSNotification*)notif
{
   NSAssert( !_isAligning, @"Search rect changed while aligning" );

   LynkeosIntegerRect r = [_imageView getSelection];
   id <LynkeosProcessableItem> item = [_window highlightedItem];
   MyImageAlignerListParameters *params =
      [item getProcessingParameterWithRef:myImageAlignerParametersRef
                                 forProcessing:myImageAlignerRef];
   NSAssert( params != nil, @"Update of inexistent alignment parameters" );

   // Update the parameters
   if ( ![params isMemberOfClass:[MyImageAlignerParameters class]]
        && ([_imageView getModifiers] & NSAlternateKeyMask) == 0 )
   {
      // Regular update, in the document
      params->_alignOrigin = r.origin;

      // Adjust the size to the power of two which yields the closest surface
      unsigned int size =
             (unsigned int)(log2((double)r.size.width*r.size.height)/2.0 + 0.5);
      size = (unsigned int)(exp2((double)size) + 0.5);
      if ( size > _sideMenuLimit )
         size = _sideMenuLimit;
      params->_alignSize.width = size;
      params->_alignSize.height = size;

      [_list setProcessingParameter:params
                            withRef:myImageAlignerParametersRef
                      forProcessing:myImageAlignerRef];
   }
   else
   {
      // Item update
      params = [[[MyImageAlignerParameters alloc] init] autorelease];

      params->_alignOrigin = r.origin;

      [item setProcessingParameter:params
                           withRef:myImageAlignerParametersRef
                     forProcessing:myImageAlignerRef];
   }
}

- (void) processStarted:(NSNotification*)notif
{
   // Change the button title
   [_alignButton setTitle:NSLocalizedString(@"Stop",@"Stop button")];
   [_alignButton setEnabled:YES];
   _isAligning = YES;
}

- (void) processEnded:(NSNotification*)notif
{
   // Change the button title
   [_alignButton setTitle:NSLocalizedString(@"Align",@"Align tool")];
   [_alignButton setEnabled:YES];

   // Reset the hilight
   MyImageAlignerListParameters *params = 
      [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                             forProcessing:myImageAlignerRef];
   [_window highlightItem:(MyImageListItem*)params->_referenceItem];

   // Register again for notifications
   [[NSNotificationCenter defaultCenter] addObserver:self
                   selector:@selector(selectionRectChanged:)
                       name:LynkeosImageViewSelectionRectDidChangeNotification
                     object:_imageView];

   // Enable all other controls
   _isAligning = NO;
   [self highlightChange:nil];
   [_searchSideMenu setEnabled:(_sideMenuLimit > 0)];

   // Clean up parameters
   [params->_referenceSpectrum release];
   params->_referenceSpectrum = nil;
}

- (void) itemChanged:(NSNotification*)notif
{
   if ( _isAligning )
   {
         MyImageListItem *item =
                            [[notif userInfo] objectForKey:LynkeosUserInfoItem];
         if ( item != nil )
            [_window highlightItem:item];
   }
   else
   {
      id <LynkeosProcessable> curItem = [_window highlightedItem];
      id <LynkeosProcessable> item =
                            [[notif userInfo] objectForKey:LynkeosUserInfoItem];
      MyImageAlignerListParameters *listParams =
                [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                                       forProcessing:myImageAlignerRef];
      LynkeosIntegerRect newSel = LynkeosMakeIntegerRect(-1,-1,0,0);
      BOOL privateSquare = NO, selRectNeedsUpdate = NO;;

      NSAssert( listParams != nil, @"Update of align item without parameters" );

      if ( item == _list )
      {
         // Process the update from the list
         if ( [[_searchSideMenu selectedItem] tag] !=
                                                  listParams->_alignSize.width )
            [_searchSideMenu selectItemWithTag:listParams->_alignSize.width];
         newSel.size = listParams->_alignSize;
         [_alignButton setEnabled:(listParams->_alignSize.width != 0
                                   && listParams->_alignSize.height != 0)];

         // Update the align origin (with the item's value if any)
         MyImageAlignerParameters *params = listParams;
         if ( curItem != nil )
            params = [curItem getProcessingParameterWithRef:
                                                     myImageAlignerParametersRef
                                          forProcessing:myImageAlignerRef];
         NSAssert( params != nil,
                   @"Update of align item parameters without parameters" );

         newSel.origin = params->_alignOrigin;
      }
      else if ( item == curItem )
      {
         // Process update from the item
         MyImageAlignerParameters *params =
                 [item getProcessingParameterWithRef:myImageAlignerParametersRef
                                       forProcessing:myImageAlignerRef];
         if ( params != nil )
         {
            newSel.origin = params->_alignOrigin;
            newSel.size.width = [[_searchSideMenu selectedItem] tag];
            newSel.size.height = newSel.size.width;
         }

         privateSquare = [params isMemberOfClass:
                                              [MyImageAlignerParameters class]];
         int privState = (privateSquare ? NSOnState : NSOffState);
         if ( [_privateSearch intValue] != privState )
         {
            selRectNeedsUpdate = YES;
            [_privateSearch setIntValue:privState];
         }
      }

      // Make reference item coherent if needed
      if ( [(MyImageListItem*)listParams->_referenceItem getSelectionState] !=
                                                                     NSOnState )
         listParams->_referenceItem = [_list firstItem];

      // And update the reference checkbox
      int state = (curItem==listParams->_referenceItem ? NSOnState : NSOffState);
      if ( [_refCheckBox state] != state )
         [_refCheckBox setState:state];

      if ( newSel.origin.x >= 0.0 && newSel.origin.y >= 0.0 )
      {
         if ( [_searchFieldX floatValue] != newSel.origin.x )
            [_searchFieldX setFloatValue:newSel.origin.x];
         if ( [_searchFieldY floatValue] != newSel.origin.y )
            [_searchFieldY setFloatValue:newSel.origin.y];

         // Update the selection in the image view if needed
         LynkeosIntegerRect r = [_imageView getSelection];

         if ( selRectNeedsUpdate ||
              r.origin.x != newSel.origin.x || r.origin.y != newSel.origin.y ||
              r.size.width != newSel.size.width ||
              r.size.height != newSel.size.height )
         {
            r = newSel;
            [_imageView setSelection:r resizable:!privateSquare movable:YES];
         }
      }
   }
}

- (void) listModified:(NSNotification*)notif
{
   MyImageAlignerListParameters *params =
            [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                                       forProcessing:myImageAlignerRef];
   id <LynkeosProcessableItem> ref = nil;

   // Modify the list of allowed values in the size popup
   NSEnumerator* list;
   MyImageListItem* item;
   long limit = -1;
   int side;

   // Check the minimum size from the list (and try to find the reference)
   if ( _list != nil )
   {
      ref = [_list firstItem];

      list = [[_list imageArray] objectEnumerator];
      while ( (item = [list nextObject]) != nil )
      {
         LynkeosIntegerSize size = [item imageSize];
         if ( size.width < limit || limit < 0 )
            limit = size.width;
         if ( size.height < limit )
            limit = size.height;

         if ( item == params->_referenceItem ||
              ( [item numberOfChildren] != 0 &&
                [item indexOfItem:
                     (MyImageListItem*)params->_referenceItem] != NSNotFound ) )
            ref = params->_referenceItem;
      }
   }

   // Optimization : reconstruct only on size change
   if ( (unsigned)limit <= _sideMenuLimit/2
        || (unsigned)limit >= _sideMenuLimit*2 )
   {
      [_searchSideMenu removeAllItems];
      for ( side = 16; side <= limit; side *= 2 )
      {
	 NSString* label = [NSString stringWithFormat:@"%d",side];
	 [_searchSideMenu addItemWithTitle:label];
         [[_searchSideMenu itemWithTitle:label] setTag:side];
      }
      _sideMenuLimit = side/2;

      [_searchSideMenu setEnabled:(_sideMenuLimit > 0)];

      if ( params != nil && params->_alignSize.width > 0 )
	 [_searchSideMenu selectItemWithTag:params->_alignSize.width];
      else
	 [_searchSideMenu selectItem:nil];
      [_alignButton setEnabled:(params->_alignSize.width != 0
                                && params->_alignSize.height != 0)];

   }

   // Update reference item if needed
   if ( params->_referenceItem != ref )
   {
      params->_referenceItem = ref;
      [_list setProcessingParameter:params
                                 withRef:myImageAlignerParametersRef
                           forProcessing:myImageAlignerRef];
   }
}
@end

@implementation MyImageAlignerView

+ (void) initialize
{
   // Register the monitor for document notifications
   NSNotificationCenter *notif = [NSNotificationCenter defaultCenter];

   monitorDictionary = [[NSMutableDictionary alloc] initWithCapacity:1];

   [notif addObserver:[MyImageAlignerMonitor class]
             selector:@selector(documentDidOpen:)
                 name:LynkeosDocumentDidOpenNotification
               object:nil];
   [notif addObserver:[MyImageAlignerMonitor class]
             selector:@selector(documentWillClose:)
                 name:LynkeosDocumentWillCloseNotification
               object:nil];

   // Register the result as displayable in a column
   [[LynkeosColumnDescriptor defaultColumnDescriptor] registerColumn:@"dx"
                                                     forProcess:LynkeosAlignRef
                                                parameter:LynkeosAlignResultRef
                                                          field:@"dx"
                                                         format:@"%.1f"];
   [[LynkeosColumnDescriptor defaultColumnDescriptor] registerColumn:@"dy"
                                                     forProcess:LynkeosAlignRef
                                                parameter:LynkeosAlignResultRef
                                                          field:@"dy"
                                                         format:@"%.1f"];
}

+ (BOOL) isStandardProcessingViewController { return(YES); }

+ (ProcessingViewKind_t) processingViewKindForConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"Image aligner does not support configuration" );
   return(ListProcessingKind);
}

+ (BOOL) isViewControllingProcess:(Class)processingClass
                       withConfig:(id <NSObject>*)config
{
   *config = nil;
   return( NO );
}

+ (void) getProcessingTitle:(NSString**)title
                  toolTitle:(NSString**)toolTitle
                        key:(NSString**)key
                       icon:(NSImage**)icon
                        tip:(NSString**)tip
                  forConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"Image aligner does not support configuration" );
   *title = NSLocalizedString(@"Align",@"Align tool");
   *toolTitle = NSLocalizedString(@"Align",@"Align tool");
   *key = @"a";
   *icon = [NSImage imageNamed:@"Align"];
   *tip = NSLocalizedString(@"AlignTip",@"Align tooltip");;
}

+ (unsigned int) allowedDisplaysForConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"Image aligner does not support configuration" );
   return( BottomTab|SeparateView );
}

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _document = nil;
      _list = nil;
      _textView = nil;
      _imageView = nil;
      _sideMenuLimit = -1;
      _isAligning = NO;

      [NSBundle loadNibNamed:@"MyImageAligner" owner:self];
   }

   return( self );
}

- (id) initWithWindowController: (id <LynkeosWindowController>)window
                       document: (id <LynkeosViewDocument>)document
                  configuration: (id <NSObject>)config
{
   NSAssert( config == nil, @"Image aligner does not support configuration" );

   if ( (self = [self init]) != nil )
   {
      _window = window;
      _textView = [_window getTextView];
      _imageView = [_window getImageView];

      _document = document;
      _list = [document imageList];

      // Create the align parameters if needed
      MyImageAlignerListParameters *params =
                [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                                       forProcessing:myImageAlignerRef];

      if ( params == nil )
      {
         params = [[MyImageAlignerListParameters alloc] init];

         params->_alignOrigin = LynkeosMakeIntegerPoint(0,0);
         params->_alignSize = LynkeosMakeIntegerSize(0,0);
         params->_referenceItem = nil;
         params->_cutoff = 0.0;
         params->_precisionThreshold = 0.0;
         params->_refSpectrumLock = [[NSLock alloc] init];
         params->_referenceSpectrum = nil;

         [_list setProcessingParameter:params
                                   withRef:myImageAlignerParametersRef
                             forProcessing:myImageAlignerRef];
      }
   }

   return( self );
}

- (NSView*) getProcessingView
{
   return( _panel );
}

- (Class) processingClass
{
   return( nil );
}

- (void) setActiveView:(BOOL)active
{
   NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];

   if ( active )
   {
      // Authorize the selections
      [_window setListSelectionAuthorization:NO];
      [_window setDataModeSelectionAuthorization:NO];
      [_window setItemSelectionAuthorization:YES];
      [_window setItemEditionAuthorization:YES];

      // Register for notifications
      [notifCenter addObserver:self
                     selector:@selector(highlightChange:)
                         name: NSOutlineViewSelectionDidChangeNotification
                       object:_textView];
      [notifCenter addObserver:self
                      selector:@selector(selectionRectChanged:)
                          name:LynkeosImageViewSelectionRectDidChangeNotification
                        object:_imageView];
      [notifCenter addObserver:self
                      selector:@selector(processStarted:)
                          name: LynkeosProcessStartedNotification
                        object:_document];
      [notifCenter addObserver:self
                      selector:@selector(processEnded:)
                          name: LynkeosProcessEndedNotification
                        object:_document];
      [notifCenter addObserver:self
                      selector:@selector(itemChanged:)
                          name: LynkeosItemChangedNotification
                        object:_document];
      [notifCenter addObserver:self
                      selector:@selector(listModified:)
                          name: LynkeosItemAddedNotification
                        object:_document];
      [notifCenter addObserver:self
                      selector:@selector(listModified:)
                          name: LynkeosItemRemovedNotification
                        object:_document];

      // Synchronize the display
      [self highlightChange:nil];
      [self listModified:nil];

      _isAligning = NO;
   }
   else
   {
      [_window setListSelectionAuthorization:YES];

      // Stop receiving notifications
      [notifCenter removeObserver:self];
   }
}

- (LynkeosProcessingViewFrame_t) preferredDisplay { return( BottomTab ); }

- (id <LynkeosProcessingParameter>) getCurrentParameters
{
   // This is a list processing, the parameters are spread on the list
   return( nil );
}

- (IBAction) searchSquareChange :(id)sender
{
   id <LynkeosProcessable> item = [_window highlightedItem];
   MyImageAlignerParameters *params =
                 [item getProcessingParameterWithRef:myImageAlignerParametersRef
                                       forProcessing:myImageAlignerRef];
   id <LynkeosProcessable> dest;

   params->_alignOrigin.x = [_searchFieldX floatValue];
   params->_alignOrigin.y = [_searchFieldY floatValue];

   if ( [params isMemberOfClass:[MyImageAlignerParameters class]] )
      dest = item;
   else
      dest = _list;
   [dest setProcessingParameter:params
                        withRef:myImageAlignerParametersRef
                  forProcessing:myImageAlignerRef];
}

- (IBAction) squareSizeChange: (id)sender
{
   MyImageAlignerListParameters *params =
      [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                                 forProcessing:myImageAlignerRef];

   params->_alignSize.width = [[_searchSideMenu selectedItem] tag];
   params->_alignSize.height = params->_alignSize.width;

   [_list setProcessingParameter:params
                             withRef:myImageAlignerParametersRef
                       forProcessing:myImageAlignerRef];
}

- (IBAction) specificSquareChange: (id)sender
{
   id <LynkeosProcessable> item = [_window highlightedItem];
   NSAssert( item != nil, @"Change specificity of search square without item" );
   MyImageAlignerParameters *params = 
            [item getProcessingParameterWithRef:myImageAlignerParametersRef
                                  forProcessing:myImageAlignerRef];

   if( [sender state] == NSOnState )
   {
      // Make alignment square specific if it is not
      if ( ![params isMemberOfClass:[MyImageAlignerParameters class]] )
      {
         MyImageAlignerParameters *itemParams =
                          [[[MyImageAlignerParameters alloc] init] autorelease];
         itemParams->_alignOrigin = params->_alignOrigin;
         [item setProcessingParameter:itemParams
                              withRef:myImageAlignerParametersRef
                        forProcessing:myImageAlignerRef];
      }
   }
   else
   {
      // Delete specific search square if any
      [item setProcessingParameter:nil
                           withRef:myImageAlignerParametersRef
                     forProcessing:myImageAlignerRef];
   }

}

- (IBAction) referenceAction :(id)sender
{
   MyImageAlignerListParameters *params =
            [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                                       forProcessing:myImageAlignerRef];

   params->_referenceItem = ([_refCheckBox state] == NSOnState ?
                             [_window highlightedItem] :
                             (_list != nil ? [_list firstItem] : nil));

   [_list setProcessingParameter:params
                             withRef:myImageAlignerParametersRef
                       forProcessing:myImageAlignerRef];
}

- (IBAction) cancelAction :(id)sender
{
   id <LynkeosProcessableItem> item = [_window highlightedItem];

   // Cancel selected alignment
   if ( item != nil )
      [item setProcessingParameter:nil
                           withRef:LynkeosAlignResultRef
                     forProcessing:LynkeosAlignRef];

   else
   {
      NSEnumerator *list = [_list imageEnumeratorStartAt:nil
                                             directSense:YES
                                          skipUnselected:NO];

      // Delete any align result in the list
      while( (item = [list nextObject]) != nil )
      {
         id <LynkeosAlignResult> res = (id <LynkeosAlignResult>)
                       [item getProcessingParameterWithRef:LynkeosAlignResultRef
                                             forProcessing:LynkeosAlignRef
                                                      goUp:NO];

         if ( res != nil )
            [item setProcessingParameter:nil withRef:LynkeosAlignResultRef
                           forProcessing:LynkeosAlignRef];
      }

      // And delete the list level align result, if any
      [_list setProcessingParameter:nil
                            withRef:LynkeosAlignResultRef
                      forProcessing:LynkeosAlignRef];
   }

   // Redisplay the modified data
   [_textView reloadData];
   if (item != nil )
      [_imageView displayItem:item];
}

- (IBAction) alignAction :(id)sender
{
   MyImageAlignerListParameters *listParams=
            [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                                       forProcessing:myImageAlignerRef];

   [sender setEnabled:NO];

   if ( _isAligning )
      [_document stopProcess];

   else
   {
      // Disable all controls
      [_searchFieldX setEnabled: NO];
      [_searchFieldY setEnabled: NO];
      [_searchSideMenu setEnabled: NO];
      [_privateSearch setEnabled: NO];
      [_refCheckBox setEnabled: NO];

      // Freeze the selection rectangle to the default one
      LynkeosIntegerRect r;
      r.size = listParams->_alignSize;
      r.origin = listParams->_alignOrigin;
      [_imageView setSelection:r resizable:NO movable:NO];

      // Stop receiving some notifications
      [[NSNotificationCenter defaultCenter] removeObserver:self
                              name:LynkeosImageViewSelectionRectDidChangeNotification
                                                    object:_imageView];

      // Initialize the align parameters
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
      listParams->_cutoff =[defaults floatForKey:K_PREF_ALIGN_FREQUENCY_CUTOFF];
      listParams->_precisionThreshold = [defaults floatForKey:
                                              K_PREF_ALIGN_PRECISION_THRESHOLD];
      listParams->_checkAlignResult = [defaults boolForKey:K_PREF_ALIGN_CHECK];
      _imageUpdate = [defaults boolForKey:K_PREF_ALIGN_IMAGE_UPDATING];

      // Get an enumerator on the images
      NSEnumerator *strider = [_list imageEnumeratorStartAt:nil
                                                directSense:YES
                                             skipUnselected:YES];

      // Ask the doc to align
      [_document startProcess:[MyImageAligner class] withEnumerator:strider
                   parameters:listParams];
   }
}
@end
