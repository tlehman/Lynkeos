// 
//  Lynkeos
//  $Id: MyImageStackerPrefs.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Wed June 18 2007.
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

#include "MyUserPrefsController.h"
#include "MyImageStackerPrefs.h"

NSString * const K_PREF_STACK_IMAGE_UPDATING = @"Stack image updating";
NSString * const K_PREF_STACK_MULTIPROC = @"Multiprocessor stack";

static MyImageStackerPrefs *myImageStackerPrefsInstance = nil;

@interface MyImageStackerPrefs(Private)
- (void) initPrefs ;
- (void) readPrefs;
- (void) updatePanel;
@end

@implementation MyImageStackerPrefs(Private)
- (void) initPrefs
{
   // Set the factory defaults
   _stackImageUpdating = NO;
   _stackMultiProc = ListThreadsOptimizations;
}

- (void) readPrefs
{
   NSUserDefaults *user = [NSUserDefaults standardUserDefaults];
   ParallelOptimization_t opt;

   if ( [user objectForKey:K_PREF_STACK_IMAGE_UPDATING] != nil )
      _stackImageUpdating = [user boolForKey:K_PREF_STACK_IMAGE_UPDATING];
   if ( [user objectForKey:K_PREF_STACK_MULTIPROC] != nil )
   {
      opt = [user integerForKey:K_PREF_STACK_MULTIPROC];
      // Compatibility with old prefs : YES is converted to parallels lists
      _stackMultiProc = (opt == NoParallelOptimization ?
                         opt : ListThreadsOptimizations );
   }
}

- (void) updatePanel
{
   [_stackImageUpdatingButton setState: 
                                (_stackImageUpdating ? NSOnState : NSOffState)];
   [_stackMultiProcPopup selectItemWithTag: _stackMultiProc];
}
@end

@implementation MyImageStackerPrefs
+ (void) getPreferenceTitle:(NSString**)title
                       icon:(NSImage**)icon
                        tip:(NSString**)tip
{
   *title = NSLocalizedString(@"Stack",@"Stack tool");
   *icon = [NSImage imageNamed:@"Photolist"];
   *tip = nil;
}

+ (id <LynkeosPreferences>) getPreferenceInstance
{
   if ( myImageStackerPrefsInstance == nil )
      [[self alloc] init];

   return( myImageStackerPrefsInstance );
}


- (id) init
{
   NSAssert( myImageStackerPrefsInstance == nil,
             @"More than one creation of MyImageStackerPrefs" );

   if ( (self = [super init]) != nil )
   {
      [self initPrefs];

      myImageStackerPrefsInstance = self;
   }

   return( self );
}

- (void) awakeFromNib
{
   // Update with database value, if any
   [self readPrefs];
   // And rewrite them to ensure correct values
   [self savePreferences:[NSUserDefaults standardUserDefaults]];

   // Finally initialize the GUI
   [self updatePanel];
}

- (NSView*) getPreferencesView
{
   return( _prefsView );
}

- (void) savePreferences:(NSUserDefaults*)prefs
{
   [prefs setBool:_stackImageUpdating forKey:K_PREF_STACK_IMAGE_UPDATING];
   [prefs setInteger:_stackMultiProc forKey:K_PREF_STACK_MULTIPROC];
}

- (void) revertPreferences
{
   [self readPrefs];
   [self updatePanel];
}

- (void) resetPreferences:(NSUserDefaults*)prefs
{
   [self initPrefs];
   [self savePreferences:prefs];
   [self updatePanel];
}

- (IBAction)changeStackImageUpdating:(id)sender
{
   _stackImageUpdating = ([sender state] == NSOnState);
}

- (IBAction)changeStackMultiProc:(id)sender
{
   _stackMultiProc = [sender selectedTag];
}
@end
