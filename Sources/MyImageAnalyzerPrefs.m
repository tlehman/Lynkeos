// 
//  Lynkeos
//  $Id: MyImageAnalyzerPrefs.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Jun 8 2007.
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
#include "MyImageAnalyzerPrefs.h"

NSString * const K_PREF_ANALYSIS_LOWER_CUTOFF = @"Analysis lower cutoff";
NSString * const K_PREF_ANALYSIS_UPPER_CUTOFF = @"Analysis upper cutoff";
NSString * const K_PREF_ANALYSIS_IMAGE_UPDATING = @"Analysis image updating";
NSString * const K_PREF_ANALYSIS_MULTIPROC = @"Multiprocessor analysis";

static MyImageAnalyzerPrefs *myImageAnalyzerPrefsInstance = nil;

@interface MyImageAnalyzerPrefs(Private)
- (void) initPrefs ;
- (void) readPrefs;
- (void) updatePanel;
@end

@implementation MyImageAnalyzerPrefs(Private)
- (void) initPrefs
{
   // Set the factory defaults
   _analysisLowerCutoff = 0.125;
   _analysisUpperCutoff = 0.7;
   _analysisImageUpdating = NO;
   _analysisMultiProc = ListThreadsOptimizations;
}

- (void) readPrefs
{
   NSUserDefaults *user = [NSUserDefaults standardUserDefaults];
   ParallelOptimization_t opt;

   getNumericPref(&_analysisLowerCutoff, K_PREF_ANALYSIS_LOWER_CUTOFF,
                  0.0, 0.71);
   getNumericPref(&_analysisUpperCutoff, K_PREF_ANALYSIS_UPPER_CUTOFF,
                  0.0, 0.71);
   if ( [user objectForKey:K_PREF_ANALYSIS_IMAGE_UPDATING] != nil )
      _analysisImageUpdating = [user boolForKey:K_PREF_ANALYSIS_IMAGE_UPDATING];
   if ( [user objectForKey:K_PREF_ANALYSIS_MULTIPROC] != nil )
   {
      opt = [user integerForKey:K_PREF_ANALYSIS_MULTIPROC];
      // Compatibility with old prefs : FFTW3 threads is converted to none
      if ( opt == FFTW3ThreadsOptimization)
         _analysisMultiProc = NoParallelOptimization;
      else
         _analysisMultiProc = opt;
   }
}

- (void) updatePanel
{
   [_analysisLowerCutoffSlider setDoubleValue: _analysisLowerCutoff*10.0];
   [_analysisLowerCutoffText setDoubleValue: _analysisLowerCutoff];
   [_analysisUpperCutoffSlider setDoubleValue: _analysisUpperCutoff*10.0];
   [_analysisUpperCutoffText setDoubleValue: _analysisUpperCutoff];
   [_analysisImageUpdatingButton setState: 
      (_analysisImageUpdating ? NSOnState : NSOffState)];
   [_analysisMultiProcPopup selectItemWithTag: _analysisMultiProc];
}
@end

@implementation MyImageAnalyzerPrefs
+ (void) getPreferenceTitle:(NSString**)title
                       icon:(NSImage**)icon
                        tip:(NSString**)tip
{
   *title = @"Analyse";
   *icon = [NSImage imageNamed:@"Analysis"];
   *tip = nil;
}

+ (id <LynkeosPreferences>) getPreferenceInstance
{
   if ( myImageAnalyzerPrefsInstance == nil )
      [[self alloc] init];

   return( myImageAnalyzerPrefsInstance );
}


- (id) init
{
   NSAssert( myImageAnalyzerPrefsInstance == nil,
             @"More than one creation of MyImageAnalyzerPrefs" );

   if ( (self = [super init]) != nil )
   {
      [self initPrefs];

      myImageAnalyzerPrefsInstance = self;
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
   [prefs setFloat:_analysisLowerCutoff forKey:K_PREF_ANALYSIS_LOWER_CUTOFF];
   [prefs setFloat:_analysisUpperCutoff forKey:K_PREF_ANALYSIS_UPPER_CUTOFF];
   [prefs setBool:_analysisImageUpdating forKey:K_PREF_ANALYSIS_IMAGE_UPDATING];
   [prefs setInteger:_analysisMultiProc forKey:K_PREF_ANALYSIS_MULTIPROC];
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

- (IBAction)changeAnalysisLowerCutoff:(id)sender
{
   _analysisLowerCutoff = [sender doubleValue];

   if ( sender == _analysisLowerCutoffSlider )
      _analysisLowerCutoff /= 10.0;

   // Enforce consistency
   if ( _analysisLowerCutoff > _analysisUpperCutoff )
      _analysisLowerCutoff = _analysisUpperCutoff;

   [_analysisLowerCutoffSlider setDoubleValue: _analysisLowerCutoff*10.0];
   [_analysisLowerCutoffText setDoubleValue: _analysisLowerCutoff];
}

- (IBAction)changeAnalysisUpperCutoff:(id)sender
{
   _analysisUpperCutoff = [sender doubleValue];

   if ( sender == _analysisUpperCutoffSlider )
      _analysisUpperCutoff /= 10.0;

   // Enforce consistency
   if ( _analysisUpperCutoff < _analysisLowerCutoff )
      _analysisUpperCutoff = _analysisLowerCutoff;

   [_analysisUpperCutoffSlider setDoubleValue: _analysisUpperCutoff*10.0];
   [_analysisUpperCutoffText setDoubleValue: _analysisUpperCutoff];
}

- (IBAction)changeAnalysisImageUpdating:(id)sender
{
   _analysisImageUpdating = ([sender state] == NSOnState);
}

- (IBAction)changeAnalysisMultiProc:(id)sender
{
   _analysisMultiProc = [[sender selectedItem] tag];
}
@end
