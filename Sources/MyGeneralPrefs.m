// 
//  Lynkeos
//  $Id: MyGeneralPrefs.m 453 2008-09-21 00:12:39Z j-etienne $
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

#include "MyGeneralPrefs.h"

NSString * const K_PREF_ADJUST_FFT_SIZES = @"Adjust FFT sizes";
NSString * const K_PREF_IMAGEPROC_MULTIPROC = @"Multiprocessor image processing";
NSString * const K_PREF_END_PROCESS_SOUND = @"End of processing sound";

static MyGeneralPrefs *myGeneralPrefsInstance = nil;

@interface MyGeneralPrefs(Private)
- (void) initPrefs ;
- (void) findSounds ;
- (void) readPrefs;
- (void) updatePanel;
@end

@implementation MyGeneralPrefs(Private)
- (void) initPrefs
{
   // Set the factory defaults value
   _adjustFFTSizes = YES;
   _imageProcOptim = FFTW3ThreadsOptimization|ListThreadsOptimizations;
   _sound = @"Glass";
   if ( ![_soundsNames containsObject:_sound] )
      _sound = @"";
}

- (void) findSounds
{
   NSArray *extensions = [NSSound soundUnfilteredFileTypes];
   NSArray *librarySearchPaths;
   NSEnumerator *searchPathEnum;
   NSString *currPath;
   NSMutableArray *bundleSearchPaths = [NSMutableArray array];

   // Build the sounds paths list
   librarySearchPaths = NSSearchPathForDirectoriesInDomains(
                                     NSLibraryDirectory, NSAllDomainsMask, YES);

   searchPathEnum = [librarySearchPaths objectEnumerator];
   while( (currPath = [searchPathEnum nextObject]) != nil )
      [bundleSearchPaths addObject: [currPath stringByAppendingPathComponent:
                                                                    @"Sounds"]];

   [bundleSearchPaths addObject: [[NSBundle mainBundle] resourcePath]];

   // Load every plugin in each directory
   searchPathEnum = [bundleSearchPaths objectEnumerator];
   while( (currPath = [searchPathEnum nextObject]) != nil )
   {
      NSDirectoryEnumerator *bundleEnum;
      NSString *currBundlePath;

      bundleEnum = [[NSFileManager defaultManager] enumeratorAtPath:currPath];

      if(bundleEnum)
      {
         while( (currBundlePath = [bundleEnum nextObject]) != nil )
         {
            if( [extensions containsObject:[currBundlePath pathExtension]] )
               [_soundsNames addObject:[[currBundlePath lastPathComponent]
                                                stringByDeletingPathExtension]];
         }
      }
   }

   // Sort the sounds names
   [_soundsNames sortUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (void) readPrefs
{
   NSUserDefaults *user = [NSUserDefaults standardUserDefaults];

   if ( [user objectForKey:K_PREF_ADJUST_FFT_SIZES] != nil )
      _adjustFFTSizes = [user boolForKey:K_PREF_ADJUST_FFT_SIZES];
   if ( [user objectForKey:K_PREF_IMAGEPROC_MULTIPROC] != nil )
      _imageProcOptim = [user integerForKey:K_PREF_IMAGEPROC_MULTIPROC];
   NSString *sound = [user objectForKey:K_PREF_END_PROCESS_SOUND];
   int soundIdx = NSNotFound;
   // Always get _sound from our array to avoid memory management issues
   if ( sound != nil )
      soundIdx = [_soundsNames indexOfObject:sound];
   if ( soundIdx != NSNotFound )
      _sound = [_soundsNames objectAtIndex:soundIdx];
   else
      _sound = @"";
}

- (void) updatePanel
{
   [_adjustFFTSizesButton setState: (_adjustFFTSizes ? NSOnState : NSOffState)];
   [_imageProcOptimPopup selectItemWithTag:_imageProcOptim];
   if ( [_sound length] != 0 )
      [_soundPopup selectItemWithTitle:_sound];
   else
      [_soundPopup selectItemAtIndex:0];
}
@end

@implementation MyGeneralPrefs

+ (void) getPreferenceTitle:(NSString**)title
                       icon:(NSImage**)icon
                        tip:(NSString**)tip
{
   *title = @"General";
   *icon = [NSImage imageNamed:@"Lynkeos"];
   *tip = @"Lynkeos general preferences";
}

+ (id <LynkeosPreferences>) getPreferenceInstance
{
   if ( myGeneralPrefsInstance == nil )
      [[self alloc] init];

   return( myGeneralPrefsInstance );
}

- (id) init
{
   NSAssert( myGeneralPrefsInstance == nil,
             @"More than one creation of MyGeneralPrefs" );

   if ( (self = [super init]) != nil )
   {
      _soundsNames = [[NSMutableArray array] retain];
      [self findSounds];
      [self initPrefs];

      myGeneralPrefsInstance = self;
   }

   return( self );
}

- (void) awakeFromNib
{
   // Update with database value, if any
   [self readPrefs];
   // And rewrite them to ensure correct values
   [self savePreferences:[NSUserDefaults standardUserDefaults]];

   // Update the sound popup
   NSEnumerator *list = [_soundsNames objectEnumerator];
   NSString *label;
   while ( (label = [list nextObject]) != nil )
      [_soundPopup addItemWithTitle:label];

   // Finally initialize the GUI
   [self updatePanel];
}

- (NSView*) getPreferencesView
{
   return( _prefsView );
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

- (void) savePreferences:(NSUserDefaults*)prefs
{
   [prefs setBool:_adjustFFTSizes forKey:K_PREF_ADJUST_FFT_SIZES];
   [prefs setObject:_sound forKey:K_PREF_END_PROCESS_SOUND];
   [prefs setInteger:_imageProcOptim forKey:K_PREF_IMAGEPROC_MULTIPROC];
}

- (IBAction)changeAdjustFFTSizes:(id)sender
{
   _adjustFFTSizes = ([sender state] == NSOnState);
}

- (IBAction)changeImageProcOptim:(id)sender
{
   _imageProcOptim = [sender selectedTag];
}

- (IBAction)changeEndProcessingSound:(id)sender
{
   if ( [sender indexOfSelectedItem] == 0 )
      _sound = @"";
   else
   {
      _sound = [sender titleOfSelectedItem];
      NSSound *snd = [NSSound soundNamed:_sound];
      NSAssert( snd != nil, @"Unknown sound in preferences" );
      [snd play];
   }
}

@end
