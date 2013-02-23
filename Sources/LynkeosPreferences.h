//
//  Lynkeos
//  $Id: LynkeosPreferences.h 462 2008-10-05 21:31:44Z j-etienne $
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

/*!
 * @header
 * @abstract Definitions for every Lynkeos user preferences plugins.
 */
#ifndef __LYNKEOSPREFERENCES_H
#define __LYNKEOSPREFERENCES_H

#import <AppKit/AppKit.h>

/*!
 * @abstract Read a numeric preference with bounds
 * @discussion If the saved value is outside the range, it is clipped to the
 *   minimum or maximum value.
 * @param pref The value to set
 * @param key The preference key
 * @param minv Minimum value
 * @param maxv Maximum value
 */
extern void getNumericPref( double *pref, NSString *key,
                            double minv, double maxv );

/*!
 * @abstract Protocol for Lynkeos preferences plugins.
 * @discussion The preferences classes are all singleton.
 */
@protocol LynkeosPreferences <NSObject>

/*!
 * @abstract Retrieves a preference toolbar characteristics
 * @param title The title for this tab in the preferences NSTabView.
 * @param icon The icon for the toolbar.
 * @param tip A tooltip for these preferences
 */
+ (void) getPreferenceTitle:(NSString**)title
                       icon:(NSImage**)icon
                        tip:(NSString**)tip ;

/*!
 * @abstract Get the preference singleton instance
 * @discussion Create it if needed.
 * @result The singleton instance.
 */
+ (id <LynkeosPreferences>) getPreferenceInstance ;

/*!
 * @abstract Get the view with the controls
 */
- (NSView*) getPreferencesView ;

/*!
 * @abstract Save the controls changes in the user defaults
 */
- (void) savePreferences:(NSUserDefaults*)prefs ;

/*!
 * @abstract Cancel all the changes to the user defaults
 */
- (void) revertPreferences ;

/*!
 * @abstract Reset the user defaults to factory settings
 */
- (void) resetPreferences:(NSUserDefaults*)prefs ;
@end

#endif
