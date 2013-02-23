//
//  Lynkeos
//  $Id:$
//
//  Created by Jean-Etienne LAMIAUD on Sun Nov 16 2008.
//  Copyright (c) 2008, Jean-Etienne LAMIAUD.
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

#import "ProcessStackTest.h"

#include "processing_core.h"
#include <LynkeosCore/LynkeosProcessing.h>
#include <LynkeosCore/LynkeosProcessableImage.h>
#include <LynkeosCore/LynkeosStandardImageBuffer.h>
#include "LynkeosStandardImageBufferAdditions.h"
#include "ProcessStackManager.h"

@interface TestProcessParam : LynkeosImageProcessingParameter
{
   @public
   unsigned int _identifier;
}

- (id) initWithIdentifier:(unsigned int)ident;
@end

@implementation TestProcessParam
- (id) initWithIdentifier:(unsigned int)ident
{
   if ( (self = [super init]) != nil )
      _identifier = ident;
   return( self );
}
@end


@implementation ProcessStackTest

// Test the creation of the stack and add of processings
- (void) testFirstProcess
{
   // Create a process stack manager
   ProcessStackManager *mgr = [[[ProcessStackManager alloc] init] autorelease];
   // Create an item
   LynkeosProcessableImage *item =
                           [[[LynkeosProcessableImage alloc] init] autorelease];
   // Add an original image to it
   [item setOriginalImage:
                  [LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:1
                                                                      width:1
                                                                     height:1]];
   // Create a processing parameter
   TestProcessParam *param = [[[TestProcessParam alloc] init] autorelease];

   // Check it is added to the stack
   LynkeosImageProcessingParameter *outParam = 
                                  [mgr getParameterForItem:item andParam:param];
   STAssertEquals( param, outParam,
                   @"Initial parameter not selected for processing" );

   // Check with a new one
   param = [[[TestProcessParam alloc] init] autorelease];   
   outParam = [mgr getParameterForItem:item andParam:param];
   STAssertEquals( param, outParam,
                  @"Initial parameter not selected for processing" );
}

// Test the stacking of 3 processings
// Test the modification of some processing in the stack
// Test the deletion of processings in the stack
// Test the exclusion of processings in the stack

@end
