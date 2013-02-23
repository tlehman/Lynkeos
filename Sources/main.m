//==============================================================================
//  Lynkeos
//  $Id: main.m 501 2010-12-30 17:21:17Z j-etienne $
//  Created by Jean-Etienne LAMIAUD on Sat Oct 04 2003.
//------------------------------------------------------------------------------
//  Copyright (c) 2003-2008. Jean-Etienne LAMIAUD
//------------------------------------------------------------------------------
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
//------------------------------------------------------------------------------

// Special comments for Doxygen

/*! \mainpage
 \section structure Application structure
    This application is structured around the NSDocument class

    The classes are organized according to the model-view-controller
    architecture (see module page). The \ref Controlers "controler" classes
    use \ref Processing "processing" classes, and the \ref Models "models" 
    classes use \ref FileAccess "graphic file access" classes.
    These classes are grouped in two other packages.

 \section processing Processing architecture
    The processing classes interactions architecture is documented on the
    \ref processingArch page.
*/

#include "processing_core.h"

#import <Foundation/Foundation.h>
#import <AppKit/NSApplication.h>

int main(int argc, const char *argv[])
{
   initializeProcessing();

   return NSApplicationMain(argc, argv);
}
