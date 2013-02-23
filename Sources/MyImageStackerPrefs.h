// 
//  Lynkeos
//  $Id: MyImageStackerPrefs.h 444 2008-08-26 14:50:42Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Wed June 18 2007.
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

#ifndef __MYIMAGE_STACKER_PREFS_H
#define __MYIMAGE_STACKER_PREFS_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "LynkeosProcessing.h"
#include "LynkeosPreferences.h"

//! Wether to redisplay the images once stacked
extern NSString * const K_PREF_STACK_IMAGE_UPDATING;
//! What kind of multiprocessor optimization to use for stacking
extern NSString * const K_PREF_STACK_MULTIPROC;

@interface MyImageStackerPrefs : NSObject <LynkeosPreferences>
{
   IBOutlet NSView*           _prefsView;
   IBOutlet NSButton*         _stackImageUpdatingButton;
   IBOutlet NSPopUpButton*    _stackMultiProcPopup;

   BOOL                       _stackImageUpdating;
   ParallelOptimization_t     _stackMultiProc;
}

/*!
 * @method changeStackImageUpdating:
 * @abstract Set wether to redisplay the image when stacked.
 * @param sender The checkbox
 */
- (IBAction)changeStackImageUpdating:(id)sender;

/*!
 * @method changeStackMultiProc:
 * @abstract Set the multiprocessor optimization to use for stacking.
 * @param sender The popup
 */
- (IBAction)changeStackMultiProc:(id)sender;
@end

#endif