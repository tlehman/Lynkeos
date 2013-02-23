//
//  Lynkeos 
//  $Id: MyCustomAlert.m 462 2008-10-05 21:31:44Z j-etienne $
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

#include "MyCustomAlert.h"

static MyCustomAlert *myInstance = nil;

@interface MyCustomAlert(private)
- (void) openAlert:(NSString*)title withText:(NSString*)text ;
@end

@implementation MyCustomAlert(private)
- (void) openAlert:(NSString*)title withText:(NSString*)text
{
   [_panel setTitle:title];
   [_text setString:text];
   [_text setAlignment:NSLeftTextAlignment];
   [NSApp runModalForWindow:_panel];
}
@end

@implementation MyCustomAlert

- (id) init
{
   NSAssert( myInstance == nil, @"Multiple creations of MyCustomAlert" );
   if ( (self = [super init]) != nil )
      myInstance = self;
   return( self );
}

+ (void) runAlert:(NSString*)title withText:(NSString*)text
{
   [myInstance openAlert:title withText:text];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
   [NSApp abortModal];
}

- (IBAction) confirmAction:(id)sender
{
   [NSApp stopModal];
   [_panel close];
}

@end
