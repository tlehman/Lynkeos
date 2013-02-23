// 
//  Lynkeos
//  $Id: MyCachePrefs.h 479 2008-11-23 14:28:07Z j-etienne $
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

#ifndef __MYCACHEPREFS_H
#define __MYCACHEPREFS_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "LynkeosPreferences.h"
#include "LynkeosObjectCache.h"

extern NSString * const K_PREF_MOVIE_CACHE;

@interface MyCachePrefs : NSObject <LynkeosPreferences>
{
   IBOutlet NSView*           _prefsView;
   IBOutlet NSTextField*      _movieCacheSizeText;
   IBOutlet NSStepper*        _movieCacheSizeStep;
   IBOutlet NSTextField*      _imageProcCacheSizeText;
   IBOutlet NSStepper*        _imageProcCacheSizeStep;

   // Preferences
   u_long                     _movieCacheSize;
   u_long                     _imageProcCacheSize;
}

/*!
 * @abstract Change the number of images cached during movie read
 * @param sender Text or stepper which was modified
 */
- (IBAction)changeMovieCacheSize:(id)sender;

/*!
 * @abstract Change the amount of memory cached during image processing
 * @param sender Text or stepper which was modified
 */
- (IBAction)changeImageProcessingCacheSize:(id)sender;

@end

#endif
