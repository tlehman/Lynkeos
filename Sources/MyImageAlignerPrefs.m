// 
//  Lynkeos
//  $Id: MyImageAlignerPrefs.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Wed May 16 2007.
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
#include "MyImageAlignerPrefs.h"

NSString * const K_PREF_ALIGN_FREQUENCY_CUTOFF = @"Align frequency cutoff";
NSString * const K_PREF_ALIGN_PRECISION_THRESHOLD = @"Align precision threshold";
NSString * const K_PREF_ALIGN_IMAGE_UPDATING = @"Align image updating";
NSString * const K_PREF_ALIGN_CHECK = @"Align check";
NSString * const K_PREF_ALIGN_MULTIPROC = @"Multiprocessor align";

static MyImageAlignerPrefs *myImageAlignerPrefsInstance = nil;

@interface MyImageAlignerPrefs(Private)
- (void) initPrefs ;
- (void) readPrefs;
- (void) updatePanel;
@end

@implementation MyImageAlignerPrefs(Private)
- (void) initPrefs
{
   // Set the factory defaults
   _alignFrequencyCutoff = 0.41;
   _alignThreshold = 0.125;
   _alignImageUpdating = YES;
   _alignCheck = NO;
   _alignMultiProc = ListThreadsOptimizations;
}

- (void) readPrefs
{
   NSUserDefaults *user = [NSUserDefaults standardUserDefaults];
   ParallelOptimization_t opt;

   getNumericPref(&_alignFrequencyCutoff, K_PREF_ALIGN_FREQUENCY_CUTOFF,
                  0.0, 0.71);
   getNumericPref(&_alignThreshold, K_PREF_ALIGN_PRECISION_THRESHOLD,
                  0.0, 1.0);
   if ( [user objectForKey:K_PREF_ALIGN_IMAGE_UPDATING] != nil )
      _alignImageUpdating = [user boolForKey:K_PREF_ALIGN_IMAGE_UPDATING];
   _alignCheck = [user boolForKey:K_PREF_ALIGN_CHECK];
   if ( [user objectForKey:K_PREF_ALIGN_MULTIPROC] != nil )
   {
      opt = [user integerForKey:K_PREF_ALIGN_MULTIPROC];
      // Compatibility with old prefs : FFTW3 threads is converted to none
      if ( opt == FFTW3ThreadsOptimization )
         _alignMultiProc = NoParallelOptimization;
      else
         _alignMultiProc = opt;
   }
}

- (void) updatePanel
{
   [_alignFrequencyCutoffSlider setDoubleValue: _alignFrequencyCutoff*10.0];
   [_alignFrequencyCutoffText setDoubleValue: _alignFrequencyCutoff];
   [_alignThresholdSlider setDoubleValue: _alignThreshold*100.0];
   [_alignThresholdText setDoubleValue: _alignThreshold*100.0];
   [_alignImageUpdatingButton setState: 
                                (_alignImageUpdating ? NSOnState : NSOffState)];
   [_alignCheckButton setState:(_alignCheck ? NSOnState : NSOffState)];
   [_alignMultiProcPopup selectItemWithTag: _alignMultiProc];
}
@end

@implementation MyImageAlignerPrefs

+ (void) getPreferenceTitle:(NSString**)title
                       icon:(NSImage**)icon
                        tip:(NSString**)tip
{
   *title = NSLocalizedString(@"Align",@"Align tool");
   *icon = [NSImage imageNamed:@"Align"];
   *tip = nil;
}

+ (id <LynkeosPreferences>) getPreferenceInstance
{
   if ( myImageAlignerPrefsInstance == nil )
      [[self alloc] init];

   return( myImageAlignerPrefsInstance );
}


- (id) init
{
   NSAssert( myImageAlignerPrefsInstance == nil,
             @"More than one creation of MyImageAlignerPrefs" );

   if ( (self = [super init]) != nil )
   {
      [self initPrefs];

      myImageAlignerPrefsInstance = self;
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
   [prefs setFloat:_alignFrequencyCutoff forKey:K_PREF_ALIGN_FREQUENCY_CUTOFF];
   [prefs setFloat:_alignThreshold forKey:K_PREF_ALIGN_PRECISION_THRESHOLD];
   [prefs setBool:_alignImageUpdating forKey:K_PREF_ALIGN_IMAGE_UPDATING];
   [prefs setBool:_alignCheck forKey:K_PREF_ALIGN_CHECK];
   [prefs setInteger:_alignMultiProc forKey:K_PREF_ALIGN_MULTIPROC];
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

- (IBAction)changeAlignFrequencyCutoff:(id)sender
{
   _alignFrequencyCutoff = [sender doubleValue];

   if ( sender == _alignFrequencyCutoffSlider )
   {
      _alignFrequencyCutoff /= 10.0;
      [_alignFrequencyCutoffText setDoubleValue: _alignFrequencyCutoff];
   }
   else
      [_alignFrequencyCutoffSlider setDoubleValue: _alignFrequencyCutoff*10.0];
}

- (IBAction)changeAlignThreshold:(id)sender
{
   _alignThreshold = [sender doubleValue]/100.0;

   if ( sender != _alignThresholdSlider )
      [_alignThresholdSlider setDoubleValue: _alignThreshold*100.0];

   if ( sender != _alignThresholdText )
      [_alignThresholdText setDoubleValue: _alignThreshold*100.0];
}

- (IBAction)changeAlignImageUpdating:(id)sender
{
   _alignImageUpdating = ([sender state] == NSOnState);
}

- (IBAction)changeAlignCheck:(id)sender
{
   _alignCheck = ([sender state] == NSOnState);
}

- (IBAction)changeAlignMultiProc:(id)sender
{
   _alignMultiProc = [[sender selectedItem] tag];
}
@end
