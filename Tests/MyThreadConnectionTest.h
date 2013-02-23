//
//  Lynkeos
//  $Id: MyThreadConnectionTest.h 450 2008-09-13 21:27:31Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Mar 3 2008.
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

#import <SenTestingKit/SenTestingKit.h>

#include <LynkeosThreadConnection.h>

@class ThreadedTester;

@interface MyThreadConnectionTest : SenTestCase
{
   LynkeosThreadConnection *_cnx;
   ThreadedTester *_threadedTester;
   int _messageCounter;
}

@end
