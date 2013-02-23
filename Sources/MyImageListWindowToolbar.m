//
//  Lynkeos
//  $Id: MyImageListWindowToolbar.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Tue May 22 2007.
//  Copyright (c) 2007. Jean-Etienne LAMIAUD
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

#include "MyPluginsController.h"
#include "MyDocument.h"
#include "MyImageListWindow.h"

NSString * const toolbarProcPrefix = @"LynkeosProcToolbarItem_";

@implementation MyImageListWindow(Toolbar)

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
   if ( toolbar != _toolBar )
      return( nil );

   // Toolbar items identifiers are derived from their class name
   NSMutableArray *allowed = [NSMutableArray array];
   NSEnumerator *procList = [[[MyPluginsController defaultPluginController]
                                          getProcessingViews] objectEnumerator];
   LynkeosProcessingViewRegistry *reg;

   while ( (reg = [procList nextObject]) != nil )
   {
      NSMutableString *ident =
                           [NSMutableString stringWithString:toolbarProcPrefix];
      [ident appendString:[reg->controller className]];
      if ( reg->ident != nil )
         [ident appendString:reg->ident];
      [allowed addObject:ident];
   }

   return( allowed );
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
   if ( toolbar != _toolBar )
      return( nil );

   NSMutableArray *allowed =
               (NSMutableArray*)[self toolbarSelectableItemIdentifiers:toolbar];

   [allowed addObjectsFromArray:
            [NSArray arrayWithObjects:
               NSToolbarCustomizeToolbarItemIdentifier,
               NSToolbarFlexibleSpaceItemIdentifier,
               NSToolbarSpaceItemIdentifier,
               NSToolbarSeparatorItemIdentifier, nil]];

   return( allowed );
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar
{
   if ( toolbar != _toolBar )
      return( nil );

   return( [NSArray arrayWithObjects:
                        @"LynkeosProcToolbarItem_MyListManagement",
                        @"LynkeosProcToolbarItem_MyImageAlignerView",
                        @"LynkeosProcToolbarItem_MyImageAnalyzerView",
                        @"LynkeosProcToolbarItem_MyImageStackerView",
                        @"LynkeosProcToolbarItem_MyDeconvolutionView",
                        @"LynkeosProcToolbarItem_MyUnsharpMaskView",
                        @"LynkeosProcToolbarItem_MyWaveletView",
                        @"LynkeosProcToolbarItem_MyProcessStackView",
                        NSToolbarFlexibleSpaceItemIdentifier,
                        NSToolbarCustomizeToolbarItemIdentifier,
                        nil] );
}

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar
      itemForItemIdentifier:(NSString *)itemIdentifier
  willBeInsertedIntoToolbar:(BOOL)flag
{
   if ( toolbar != _toolBar )
      return( nil );

   NSToolbarItem *item = nil;

   // Retrieve the class from the identifier
   if ([itemIdentifier hasPrefix:toolbarProcPrefix])
   {
      NSEnumerator *list = [[[MyPluginsController defaultPluginController]
                                          getProcessingViews] objectEnumerator];
      LynkeosProcessingViewRegistry *reg = nil;
      int tag = NSNotFound, i = 0;
      while( (reg = [list nextObject]) != nil )
      {
         NSMutableString *procIdent =
                           [NSMutableString stringWithString:toolbarProcPrefix];
         [procIdent appendString:[reg->controller className]];
         if ( reg->ident != nil )
            [procIdent appendString:reg->ident];
         if ( [procIdent isEqual:itemIdentifier] )
         {
            tag = i;
            break;
         }
         i++;
      }

      NSAssert( tag != NSNotFound,
                @"Toolbar item not in processing class list" );

      // Initialize the item
      item = [[[NSToolbarItem alloc] initWithItemIdentifier:
                                                   itemIdentifier] autorelease];

      NSString *menuTitle, *title, *key, *tip;
      NSImage *icon;
      [reg->controller getProcessingTitle:&menuTitle toolTitle:&title
                                      key:&key icon:&icon tip:&tip
                                forConfig:reg->config];

      [item setLabel:title];
      [item setPaletteLabel:title];

      [item setToolTip:tip];
      [item setImage:icon];

      [item setTag:tag];
      [item setTarget:self];
      [item setAction:@selector(activateProcessingView:)];
   }

   return item;
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem
{
   unsigned int mask = ProcessingViewAuthorized|_listMode;
   return( !_isProcessing &&
           (_processingAuthorization[[theItem tag]] & mask) == mask );
}
@end
