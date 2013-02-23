//
//  Lynkeos 
//  $Id: MyCustomAlert.h 462 2008-10-05 21:31:44Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Mon Mar 24 2008.
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

/*!
 * @header
 * @abstract Definitions of a custom alert panel.
 */
#ifndef __MYCUSTOMALERT_H
#define __MYCUSTOMALERT_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface MyCustomAlert : NSObject
{
   IBOutlet NSPanel*     _panel;
   IBOutlet NSTextView*  _text;
   IBOutlet NSButton*    _okButton;
}

+ (void) runAlert:(NSString*)title withText:(NSString*)text ;

- (IBAction) confirmAction:(id)sender ;
@end

#endif