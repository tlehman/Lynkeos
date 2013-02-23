//
//  Lynkeos
//  $Id: DcrawReaderPrefs.m 500 2010-12-30 16:06:27Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Wed Sep 24 2008.
//  Copyright (c) 2008. Jean-Etienne LAMIAUD
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

#include "DcrawReaderPrefs.h"

NSString * const K_TMPDIR_KEY = @"RAW files conversion folder";
NSString * const K_MANUALWB_KEY = @"RAW manual white balance";
NSString * const K_RED_KEY = @"RAW red weight";
NSString * const K_GREEN1_KEY = @"RAW first green weight";
NSString * const K_BLUE_KEY = @"RAW blue weigh";
NSString * const K_GREEN2_KEY = @"RAW second green weigh";
NSString * const K_LEVELS_KEY = @"RAW manual levels";
NSString * const K_DARK_KEY = @"RAW dark level";
NSString * const K_SATURATION_KEY = @"RAW saturation level";
NSString * const K_ROTATION_KEY = @"RAW image rotation";

static DcrawReaderPrefs *dcrawReaderPrefsInstance = nil;

@interface DcrawReaderPrefs(Private)
- (void) initPrefs ;
- (void) readPrefs;
- (void) updatePanel;
@end

@implementation DcrawReaderPrefs(Private)
- (void) initPrefs
{
   // Set the factory defaults
   _tmpDir = nil;
   _manualWB = NO;
   _autoRotation = YES;
   _red = 1.0;
   _green1 = 1.0;
   _blue = 1.0;
   _green2 = 1.0;
   _dark = -HUGE;
   _saturation = HUGE;
}

- (void) readPrefs
{
   NSUserDefaults *user = [NSUserDefaults standardUserDefaults];
   NSFileManager *fileMgr = [NSFileManager defaultManager];
   BOOL isDir;

   _tmpDir = [user stringForKey:K_TMPDIR_KEY];
   if ( _tmpDir != nil &&
        (![fileMgr fileExistsAtPath:[_tmpDir stringByExpandingTildeInPath]
                       isDirectory:&isDir]
         || !isDir ) )
      // Bad path
      _tmpDir = nil;
   if ( [user objectForKey:K_MANUALWB_KEY] != nil )
      _manualWB = [user boolForKey:K_MANUALWB_KEY];
   if ( [user objectForKey:K_ROTATION_KEY] != nil )
      _autoRotation = [user boolForKey:K_ROTATION_KEY];
   getNumericPref(&_red, K_RED_KEY, 0.0, 10.0);
   getNumericPref(&_green1, K_GREEN1_KEY, 0.0, 10.0);
   getNumericPref(&_blue, K_BLUE_KEY, 0.0, 10.0);
   getNumericPref(&_green2, K_GREEN2_KEY, 0.0, 10.0);
   _manualLevels = [user boolForKey:K_LEVELS_KEY];
   getNumericPref(&_dark, K_DARK_KEY, 0.0, 65536.0);
   getNumericPref(&_saturation, K_SATURATION_KEY, 0.0, 65536.0);
}

- (void) updatePanel
{
   if ( _tmpDir != nil )
      [_tmpDirText setStringValue:_tmpDir];
   else
      [_tmpDirText setStringValue:@""];
   [_manualWbButton setState:(_manualWB ? NSOnState : NSOffState)];
   [_autoRotationButton setState:(_autoRotation ? NSOnState : NSOffState)];
   [_redText setDoubleValue:_red];
   [_green1Text setDoubleValue:_green1];
   [_blueText setDoubleValue:_blue];
   [_green2Text setDoubleValue:_green2];
   [_manualLevelsButton setState:(_manualLevels ? NSOnState : NSOffState)];
   [_darkText setDoubleValue:_dark];
   [_saturationText setDoubleValue:_saturation];

   [_redText setEnabled:_manualWB];
   [_green1Text setEnabled:_manualWB];
   [_blueText setEnabled:_manualWB];
   [_green2Text setEnabled:_manualWB];
   [_darkText setEnabled:_manualLevels];
   [_saturationText setEnabled:_manualLevels];
}
@end

@implementation DcrawReaderPrefs

+ (void) getPreferenceTitle:(NSString**)title
                       icon:(NSImage**)icon
                        tip:(NSString**)tip
{
   NSBundle *myBundle = [NSBundle bundleWithIdentifier:
                                         @"net.sourceforge.lynkeos.plugin.RAW"];
   *title = @"RAW";
   *icon = [[[NSImage alloc] initWithContentsOfFile:
                         [myBundle pathForImageResource:@"Dcraw"]] autorelease];
   *tip = nil;
}

+ (id <LynkeosPreferences>) getPreferenceInstance
{
   if ( dcrawReaderPrefsInstance == nil )
      [[self alloc] init];

   return( dcrawReaderPrefsInstance );
}

- (id) init
{
   NSAssert( dcrawReaderPrefsInstance == nil,
            @"More than one creation of DcrawReaderPrefs" );

   if ( (self = [super init]) != nil )
   {
      [self initPrefs];
      [NSBundle loadNibNamed:@"DcrawReaderPrefs" owner:self];

      // Update with database value, if any
      [self readPrefs];
      // And rewrite them to ensure correct values
      [self savePreferences:[NSUserDefaults standardUserDefaults]];

      // Finally initialize the GUI
      [self updatePanel];

      dcrawReaderPrefsInstance = self;
   }

   return( self );
}

- (NSView*) getPreferencesView
{
   return( _prefsView );
}

- (void) savePreferences:(NSUserDefaults*)prefs
{
   [prefs setObject:_tmpDir     forKey:K_TMPDIR_KEY];
   [prefs setBool:_manualWB     forKey:K_MANUALWB_KEY];
   [prefs setBool:_autoRotation forKey:K_ROTATION_KEY];
   [prefs setFloat:_red         forKey:K_RED_KEY];
   [prefs setFloat:_green1      forKey:K_GREEN1_KEY];
   [prefs setFloat:_blue        forKey:K_BLUE_KEY];
   [prefs setFloat:_green2      forKey:K_GREEN2_KEY];
   [prefs setBool:_manualLevels forKey:K_LEVELS_KEY];
   [prefs setFloat:_dark        forKey:K_DARK_KEY];
   [prefs setFloat:_saturation  forKey:K_SATURATION_KEY];
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

- (IBAction)changeTmpDir:(id)sender
{
   BOOL isDir;

   if ( _tmpDir != nil )
      [_tmpDir release];

   _tmpDir = [sender stringValue];

   if ( [_tmpDir length] <= 0
        || ![[NSFileManager defaultManager] fileExistsAtPath:
                                          [_tmpDir stringByExpandingTildeInPath]
                       isDirectory:&isDir]
         || !isDir )
   {
      if ( [_tmpDir length] > 0 )
         // Bad path
         SysBeep(1);
      _tmpDir = nil;
      [sender setStringValue:@""];
   }
   else
      [_tmpDir retain];
}

- (IBAction)changeManualWB:(id)sender
{
   _manualWB = ([sender state] == NSOnState);
   [self updatePanel];
}

- (IBAction)changeAutoRotation:(id)sender
{
   _autoRotation = ([sender state] == NSOnState);
   [self updatePanel];
}

- (IBAction)changeRed:(id)sender
{
   _red = [sender doubleValue];
}

- (IBAction)changeGreen1:(id)sender
{
   _green1 = [sender doubleValue];
}

- (IBAction)changeBlue:(id)sender
{
   _blue = [sender doubleValue];
}

- (IBAction)changeGreen2:(id)sender
{
   _green2 = [sender doubleValue];
}

- (IBAction)changeManualLevels:(id)sender
{
   _manualLevels = ([sender state] == NSOnState);
   [self updatePanel];
}

- (IBAction)changeDark:(id)sender
{
   _dark = [sender doubleValue];
}

- (IBAction)changeSaturation:(id)sender
{
   _saturation = [sender doubleValue];
}
@end
