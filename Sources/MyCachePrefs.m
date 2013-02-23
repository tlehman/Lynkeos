// 
//  Lynkeos
//  $Id: MyCachePrefs.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Mar 14 2008.
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
#ifdef GNUSTEP
#include <sys/user.h>
#include <sys/sysinfo.h>
#else
#include <mach/mach.h>
#include <mach/mach_host.h>
#include <mach/host_info.h>
#include <mach/machine.h>
#endif

#include "processing_core.h"
#include <LynkeosCore/LynkeosProcessing.h>

#include "MyCachePrefs.h"

NSString * const K_PREF_MOVIE_CACHE = @"Movie cache size";
NSString * const K_PREF_IMAGEPROC_CACHE = @"Image processing cache size";

static MyCachePrefs *myCachePrefsInstance = nil;

@interface MyCachePrefs(Private)
- (void) initPrefs ;
- (void) readPrefs;
- (void) updatePanel;
@end

@implementation MyCachePrefs(Private)
- (void) initPrefs
{
   // Set the factory defaults value

   // Should be more than the Mach ports queues (seems to be 6 per port)
   _movieCacheSize = 8*numberOfCpus;

   // Use 25% of the computers memory by defaults
   unsigned long long memSize;
#ifdef GNUSTEP
   memSize = get_phys_pages() * PAGE_SIZE;
#else
   host_basic_info_data_t hostInfo;
   mach_msg_type_number_t infoCount;

   infoCount = HOST_BASIC_INFO_COUNT;
   host_info(mach_host_self(), HOST_BASIC_INFO, 
             (host_info_t)&hostInfo, &infoCount);
   memSize = hostInfo.max_mem;
#endif

   _imageProcCacheSize = memSize/4/1024/1024;
}

- (void) readPrefs
{
   NSUserDefaults *user = [NSUserDefaults standardUserDefaults];

   if ( [user objectForKey:K_PREF_MOVIE_CACHE] != nil )
      _movieCacheSize = [user integerForKey:K_PREF_MOVIE_CACHE];
   if ( [user objectForKey:K_PREF_IMAGEPROC_CACHE] != nil )
      _imageProcCacheSize = [user integerForKey:K_PREF_IMAGEPROC_CACHE];
}

- (void) updatePanel
{
   [_movieCacheSizeText setIntValue:_movieCacheSize];
   [_movieCacheSizeStep setIntValue:_movieCacheSize];
   [_imageProcCacheSizeText setIntValue:_imageProcCacheSize];
   [_imageProcCacheSizeStep setIntValue:_imageProcCacheSize];
}
@end

@implementation MyCachePrefs

+ (void) getPreferenceTitle:(NSString**)title
                       icon:(NSImage**)icon
                        tip:(NSString**)tip
{
   *title = @"Cache";
   *icon = [NSImage imageNamed:@"Cache"];
   *tip = @"Cache preferences";
}

+ (id <LynkeosPreferences>) getPreferenceInstance
{
   if ( myCachePrefsInstance == nil )
      [[self alloc] init];

   return( myCachePrefsInstance );
}

- (id) init
{
   NSAssert( myCachePrefsInstance == nil,
             @"More than one creation of MyCachePrefs" );

   if ( (self = [super init]) != nil )
   {
      [self initPrefs];

      myCachePrefsInstance = self;
   }

   return( self );
}

- (void) awakeFromNib
{
   // Update with database value, if any
   [self readPrefs];
   // And rewrite them to ensure correct values
   [self savePreferences:[NSUserDefaults standardUserDefaults]];
   // Initialize the GUI
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
   [prefs setInteger:_movieCacheSize forKey:K_PREF_MOVIE_CACHE];
   [prefs setInteger:_imageProcCacheSize forKey:K_PREF_IMAGEPROC_CACHE];

   // Reconfigure the caches accordingly
   if ( [LynkeosObjectCache movieCache] != nil )
   {
      if ( _movieCacheSize == 0 )
         [LynkeosObjectCache setMovieCache:nil];
      else
         [[LynkeosObjectCache movieCache] setCapacity:_movieCacheSize];
   }
   else if ( _movieCacheSize != 0 )
      [LynkeosObjectCache setMovieCache:
               [[LynkeosObjectCache alloc] initWithStrategy:CacheNumberOfObjects
                                                   capacity:_movieCacheSize
                                                     policy:WriteRefresh]];

   u_long byteCacheSize = _imageProcCacheSize*1024*1024;
   if ( [LynkeosObjectCache imageProcessingCache] != nil )
   {
      if ( _imageProcCacheSize == 0 )
         [LynkeosObjectCache setImageProcessingCache:nil];
      else
         [[LynkeosObjectCache imageProcessingCache] setCapacity:byteCacheSize];
   }
   else if ( _imageProcCacheSize != 0 )
      [LynkeosObjectCache setImageProcessingCache:
               [[LynkeosObjectCache alloc] initWithStrategy:CacheMemorySize
                                                   capacity:byteCacheSize
                                                     policy:WriteRefresh]];
}

- (IBAction)changeMovieCacheSize:(id)sender
{
   _movieCacheSize = [sender intValue];

   if ( sender == _movieCacheSizeStep )
      [_movieCacheSizeText setIntValue:_movieCacheSize];
   else if ( sender == _movieCacheSizeText )
      [_movieCacheSizeStep setIntValue:_movieCacheSize];
}

- (IBAction)changeImageProcessingCacheSize:(id)sender
{
   _imageProcCacheSize = [sender intValue];

   if ( sender == _imageProcCacheSizeStep )
      [_imageProcCacheSizeText setIntValue:_imageProcCacheSize];
   else if ( sender == _imageProcCacheSizeText )
      [_imageProcCacheSizeStep setIntValue:_imageProcCacheSize];
}
@end
