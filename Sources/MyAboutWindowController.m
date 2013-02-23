// 
//  Lynkeos
//  $Id: MyAboutWindowController.m 508 2011-03-26 23:33:10Z j-etienne $
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

#include "MyAboutWindowController.h"

@implementation MyAboutWindowController

- (void) awakeFromNib
{
	NSBundle *app = [NSBundle mainBundle];
	NSDictionary *infos = [app localizedInfoDictionary];

	[versionString setStringValue:
                            [infos objectForKey:@"CFBundleShortVersionString"]];
	[copyrightString setStringValue:
                           [infos objectForKey:@"NSHumanReadableCopyright"]];

	[copyrightText readRTFDFromFile:
                           [app pathForResource:@"Copyrights" ofType:@"rtf"]];
	[creditstext readRTFDFromFile:
                           [app pathForResource:@"Credits" ofType:@"rtf"]];
	[licenseText readRTFDFromFile:
                           [app pathForResource:@"License" ofType:@"rtf"]];
	[changelogText readRTFDFromFile:
                           [app pathForResource:@"Changelog" ofType:@"rtf"]];
}

- (IBAction)closeAboutWindow:(id)sender
{
   [window orderOut:sender];
}

- (IBAction)showAboutWindow:(id)sender
{
   [window makeKeyAndOrderFront:self];
}

@end
