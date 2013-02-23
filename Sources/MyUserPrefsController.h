// 
//  Lynkeos
//  $Id: MyUserPrefsController.h 455 2008-09-27 10:44:06Z j-etienne $
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

#ifndef __MYUSERPREFSCONTROLLER_H
#define __MYUSERPREFSCONTROLLER_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "LynkeosCommon.h"

/*!
 * @header
 * @abstract Definitions for the user preferences controller
 */

/*!
 * @class MyUserPrefsController
 * @abstract User preferences controller class
 * @discussion This class is a singleton object controlling the user 
 *   preferences window
 * @ingroup Controlers
 */
@interface MyUserPrefsController : NSObject
{
@private
   // GUI controls
   IBOutlet NSPanel*          _panel;
   IBOutlet NSScrollView*     _prefView;
   IBOutlet NSView*           _generalPrefsView;

   NSToolbar*                 _toolbar;   //!< The preferences pane toolbar

   // Internals
   NSUserDefaults*            _user;
}

/*!
 * @method getUserPref
 * @abstract Get the singleton instance
 * @result The only instance of MyUserPrefsController
 */
+ (MyUserPrefsController*) getUserPref ;

/*!
 * @method resetPrefs:
 * @abstract Reset the preferences to their "factory defaults" values.
 * @param sender The button
 */
- (IBAction)resetPrefs:(id)sender;

/*!
 * @method applyChanges:
 * @abstract Save the new preferences and leave the preferences panel open.
 * @param sender The button
 */
- (IBAction)applyChanges:(id)sender;

/*!
 * @method cancelChanges:
 * @abstract Close the preferences panel and discard its preferences.
 * @param sender The button
 */
- (IBAction)cancelChanges:(id)sender;

/*!
 * @method confirmChanges:
 * @abstract Save the new preferences and close the preferences panel
 * @param sender The button
 */
- (IBAction)confirmChanges:(id)sender;

/*!
 * @method showPrefs:
 * @abstract Open the preferences panel.
 * @param sender The main menu "preferences" item
 */
- (IBAction) showPrefs:(id)sender;

@end

#endif
