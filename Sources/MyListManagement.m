//  Lynkeos
//  $Id: MyListManagement.m 452 2008-09-14 12:35:29Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sat Mar 10, 2007.
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

#include "MyDocument.h"
#include "MyListManagement.h"

@interface MyListManagement(Private)
- (void) hilightChange:(NSNotification*)notif ;
- (void) processStarted:(NSNotification*)notif ;
@end

@implementation MyListManagement(Private)
- (void) hilightChange:(NSNotification*)notif
{
   id <LynkeosProcessableItem> item = nil;
   id <LynkeosImageList> list;
   NSEnumerator *listEnum;
   BOOL nextEnable = NO, prevEnable = NO;
   DataMode_t dataMode = [_document dataMode];

   // Get the item and its image
   if ( dataMode == ListData )
      item = [_windowController highlightedItem];
   else
      item = [_document currentList];

   // Update the image view
   [_imageView displayItem:item];

   // Update the buttons state
   if ( dataMode == ListData )
   {
      [_plusButton setEnabled:YES];
      [_minusButton setEnabled:item!=nil];
      [_toggleButton setEnabled:item!=nil];

      list = [(MyDocument*)_document currentList];
      if ( item != nil )
      {
         listEnum = [list imageEnumeratorStartAt:item 
                                     directSense:YES
                                  skipUnselected:YES];
         nextEnable = ([listEnum nextObject] != nil);

         listEnum = [list imageEnumeratorStartAt:item 
                                     directSense:NO
                                  skipUnselected:YES];
         prevEnable = ([listEnum nextObject] != nil);
      }
      else if ( [[list imageArray] count] != 0 )
      {
         nextEnable = YES;
         prevEnable = YES;
      }
   }
   else
   {
      [_plusButton setEnabled:NO];
      [_minusButton setEnabled:NO];
      [_toggleButton setEnabled:NO];
   }

   [_prevButton setEnabled:prevEnable];
   [_nextButton setEnabled:nextEnable];
}

- (void) processStarted:(NSNotification*)notif
{
   [_plusButton setEnabled:NO];
   [_minusButton setEnabled:NO];
   [_toggleButton setEnabled:NO];
   [_prevButton setEnabled:NO];
   [_nextButton setEnabled:NO];
}
@end

@implementation MyListManagement

+ (BOOL) isStandardProcessingViewController { return(YES); }

+ (ProcessingViewKind_t) processingViewKindForConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"List manager does not support configuration" );
   return(ListManagementKind);
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
   NSAssert( config == nil, @"List manager does not support configuration" );
   *title = NSLocalizedString(@"ListMenu",@"List menu title");
   *tooTitle = NSLocalizedString(@"ListTool",@"List tool title");
   *key = @"l";
   *icon = [NSImage imageNamed:@"List"];
   *tip = NSLocalizedString(@"ListTip",@"List tooltip");;
}

+ (unsigned int) authorizedModesForConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"List manager does not support configuration" );
   return(ImageMode|DarkFrameMode|FlatFieldMode|ListData|ResultData);
}

+ (unsigned int) allowedDisplaysForConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"List manager does not support configuration" );
   return( BottomTab|SeparateView );
}

- (id) initWithWindowController: (id <LynkeosWindowController>)window
                       document: (id <LynkeosViewDocument>)document
                  configuration: (id <NSObject>)config
{
   // We are instantiated by the nib file, not by the window controller
   [self doesNotRecognizeSelector:_cmd];
   return( nil );
}

- (void) awakeFromNib
{
   _textView = [_windowController getTextView];
   _imageView = [_windowController getImageView];
   _document = [_windowController document];
}

- (NSView*) getProcessingView { return( _view ); }

- (LynkeosProcessingViewFrame_t) preferredDisplay { return( BottomTab ); }

- (void) setActiveView:(BOOL)active
{
   NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

   if ( active )
   {
      // Authorize the selections
      [_windowController setListSelectionAuthorization:YES];
      [_windowController setDataModeSelectionAuthorization:YES];
      [_windowController setItemSelectionAuthorization:YES];
      [_windowController setItemEditionAuthorization:YES];

      // Delete the selection rectangle
      [_imageView setSelection:LynkeosMakeIntegerRect(0,0,0,0)
                     resizable:NO movable:NO];

      // Register for notifications
      [center addObserver:self
                 selector:@selector(hilightChange:)
                     name: NSOutlineViewSelectionDidChangeNotification
                   object:_textView];
      [center addObserver:self
                 selector:@selector(hilightChange:)
                     name: LynkeosItemAddedNotification
                   object:_document];
      [center addObserver:self
                 selector:@selector(hilightChange:)
                     name: LynkeosListChangeNotification
                   object:_document];
      [center addObserver:self
                 selector:@selector(processStarted:)
                     name: LynkeosProcessStartedNotification
                   object:_document];
      [center addObserver:self
                 selector:@selector(hilightChange:)
                     name: LynkeosProcessStackEndedNotification
                   object:_document];

      // Synchronize the display
      [self hilightChange:nil];
   }
   else
   {
      // Stop receiving notifications
      [center removeObserver:self];
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

- (IBAction) addAction :(id)sender
{
   [_windowController addAction:sender];
}

- (IBAction) deleteAction :(id)sender
{
   [_windowController delete:sender];
}

- (IBAction) toggleEntrySelection :(id)sender
{
   [_windowController toggleEntrySelection:sender];
}

- (IBAction) highlightNext :(id)sender
{
   [_windowController highlightNext:sender];
}

- (IBAction) highlightPrevious :(id)sender
{
   [_windowController highlightPrevious:sender];
}

@end
