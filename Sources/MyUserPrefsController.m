// 
//  Lynkeos
//  $Id: MyUserPrefsController.m 498 2010-12-29 15:46:09Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun Feb 8 2004.
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

#include "LynkeosPreferences.h"
#include "MyPluginsController.h"

#include "MyUserPrefsController.h"

static NSString * const K_PREF_TOOLBAR = @"Preferences toolbar";
static NSString * const toolbarIdentPrefix = @"LynkeosPrefToolbarItem_";

static MyUserPrefsController *instancePointer = nil;

@interface MyUserPrefsController(Private)
- (void) activatePreferencePane: (id) sender ;
@end

@implementation MyUserPrefsController(Private)
- (void) activatePreferencePane: (id) sender
{
   int tag = [sender tag];
   NSArray *prefList = [[MyPluginsController defaultPluginController]
                                                           getPreferencesPanes];
   // Retrieve the preferences controller
   Class c = [prefList objectAtIndex:tag];
   id <LynkeosPreferences> pref = [c getPreferenceInstance];
   NSView *newView = [pref getPreferencesView];

   // Access the NSView and insert it in the window
   [_prefView setDocumentView:newView];
}
@end

@implementation MyUserPrefsController

- (id) init
{
   NSAssert( instancePointer == nil, 
             @"Creation of more than 1 MyUserPrefsController object" );

   if ( (self = [super init]) != nil )
   {
      _user = [NSUserDefaults standardUserDefaults];

      _toolbar = [[NSToolbar alloc] initWithIdentifier:K_PREF_TOOLBAR];
      [_toolbar setAllowsUserCustomization:YES];
      [_toolbar setAutosavesConfiguration:YES];
      [_toolbar setDelegate:self];

      instancePointer = self;
   }

   return( self );
}

- (void) awakeFromNib
{
   [_panel setToolbar:_toolbar];

   [_prefView setDocumentView:_generalPrefsView];
   [_toolbar setSelectedItemIdentifier:@"LynkeosPrefToolbarItem_MyGeneralPrefs"];
}

// Toolbar
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
   if ( toolbar != _toolbar )
      return( nil );

   // Toolbar items identifiers are derived from their class name
   NSMutableArray *items = [NSMutableArray array];
   NSEnumerator *prefList = [[[MyPluginsController defaultPluginController]
                                         getPreferencesPanes] objectEnumerator];
   Class p;

   while ( (p = [prefList nextObject]) != nil )
   {
      NSString *ident = [toolbarIdentPrefix stringByAppendingString:
                                                                 [p className]];
      [items addObject:ident];
   }

   return( items );
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
   if ( toolbar != _toolbar )
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
   return( [self toolbarSelectableItemIdentifiers:toolbar] );
}

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar
      itemForItemIdentifier:(NSString *)itemIdentifier
  willBeInsertedIntoToolbar:(BOOL)flag
{
   if ( toolbar != _toolbar )
      return( nil );

   NSToolbarItem *item = nil;

   // Retrieve the class from the identifier
   if ([itemIdentifier hasPrefix:toolbarIdentPrefix])
   {
      NSString *className = [itemIdentifier substringFromIndex:
                                                   [toolbarIdentPrefix length]];
      Class c = objc_getClass( [className UTF8String] );

      if ( c != nil )
      {
         int tag = [[[MyPluginsController defaultPluginController]
                                          getPreferencesPanes] indexOfObject:c];

         NSAssert( tag != NSNotFound,
                   @"Tollbar item not in preferences class list" );

         // Initialize the item
         item = [[[NSToolbarItem alloc] initWithItemIdentifier:
                                                   itemIdentifier] autorelease];

         NSString *title, *tip;
         NSImage *icon;
         [c getPreferenceTitle:&title icon:&icon tip:&tip];

         [item setLabel:title];
         [item setPaletteLabel:title];

         [item setToolTip:tip];
         [item setImage:icon];

         [item setTag:tag];
         [item setTarget:self];
         [item setAction:@selector(activatePreferencePane:)];
      }
   }

   return item;
}

+ (MyUserPrefsController*) getUserPref { return instancePointer; }

- (IBAction)resetPrefs:(id)sender
{
   NSEnumerator *prefList = [[[MyPluginsController defaultPluginController]
      getPreferencesPanes] objectEnumerator];
   Class p;

   while ( (p = [prefList nextObject]) != nil )
      [[p getPreferenceInstance] resetPreferences:_user];
}

- (IBAction)applyChanges:(id)sender
{
   NSEnumerator *prefList = [[[MyPluginsController defaultPluginController]
      getPreferencesPanes] objectEnumerator];
   Class p;

   while ( (p = [prefList nextObject]) != nil )
      [[p getPreferenceInstance] savePreferences:_user];
}

- (IBAction)cancelChanges:(id)sender
{
   NSEnumerator *prefList = [[[MyPluginsController defaultPluginController]
      getPreferencesPanes] objectEnumerator];
   Class p;

   while ( (p = [prefList nextObject]) != nil )
      [[p getPreferenceInstance] revertPreferences];
   [_panel orderOut:sender];
}

- (IBAction)confirmChanges:(id)sender
{
   [self applyChanges:sender];
   [_panel orderOut:sender];
}

- (IBAction) showPrefs :(id)sender
{
   [_panel makeKeyAndOrderFront:self];
}

@end
