// 
//  Lynkeos
//  $Id: MyAboutWindowController.h 362 2007-12-26 22:18:12Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Aug 18 2006.
//  Copyright (c) 2006-2007. Jean-Etienne LAMIAUD
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

#ifndef __MYABOUTWINDOWCONTROLLER_H
#define __MYABOUTWINDOWCONTROLLER_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

/*!
 * @abstract Singleton class controlling the "About" window
 */
@interface MyAboutWindowController : NSObject
{
	IBOutlet NSWindow *window;              ///< The About window itself
	IBOutlet NSTextField *copyrightString;  ///< Localized copyright string
	IBOutlet NSTextView *copyrightText;     ///< Localized copyright text
	IBOutlet NSTextView *creditstext;       ///< Localized credits text
	IBOutlet NSTextView *licenseText;       ///< Localized license text
	IBOutlet NSTextView *changelogText;     ///< Localized changelog
	IBOutlet NSTextField *versionString;    ///< Localized version string
}
- (IBAction)closeAboutWindow:(id)sender;        ///< Closes the window!
- (IBAction)showAboutWindow:(id)sender;         ///< Displays the window
@end

#endif

