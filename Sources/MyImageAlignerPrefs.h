// 
//  Lynkeos
//  $Id: MyImageAlignerPrefs.h 444 2008-08-26 14:50:42Z j-etienne $
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

#ifndef __MYIMAGEALIGNERPREFS_H
#define __MYIMAGEALIGNERPREFS_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "LynkeosProcessing.h"
#include "LynkeosPreferences.h"

//! Frequency above which the spectrum is cleared before alignment
extern NSString * const K_PREF_ALIGN_FREQUENCY_CUTOFF;
//! Maximum standard deviation for succesful alignment
extern NSString * const K_PREF_ALIGN_PRECISION_THRESHOLD;
//! Wether to redisplay the images once aligned
extern NSString * const K_PREF_ALIGN_IMAGE_UPDATING;
//! Wether to check the alignment result
extern NSString * const K_PREF_ALIGN_CHECK;
//! What kind of multiprocessor optimization to use for alignment
extern NSString * const K_PREF_ALIGN_MULTIPROC;

@interface MyImageAlignerPrefs : NSObject <LynkeosPreferences>
{
   IBOutlet NSView*           _prefsView;
   IBOutlet NSSlider*         _alignFrequencyCutoffSlider;
   IBOutlet NSTextField*      _alignFrequencyCutoffText;
   IBOutlet NSSlider*         _alignThresholdSlider;
   IBOutlet NSTextField*      _alignThresholdText;
   IBOutlet NSButton*         _alignImageUpdatingButton;
   IBOutlet NSButton*         _alignCheckButton;
   IBOutlet NSPopUpButton*    _alignMultiProcPopup;

   double                     _alignFrequencyCutoff;
   double                     _alignThreshold;
   BOOL                       _alignImageUpdating;
   BOOL                       _alignCheck;
   ParallelOptimization_t     _alignMultiProc;
}

/*!
 * @method changeAlignFrequencyCutoff:
 * @abstract Set the frequency cutoff for alignment.
 * @param sender The slider or the text field
 */
- (IBAction)changeAlignFrequencyCutoff:(id)sender;

/*!
 * @method changeAlignThreshold:
 * @abstract Change the alignment success threshold
 * @param sender The slider or the text field
 */
- (IBAction)changeAlignThreshold:(id)sender;

/*!
 * @method changeAlignImageUpdating:
 * @abstract Set wether to redisplay the image when aligned.
 * @param sender The checkbox
 */
- (IBAction)changeAlignImageUpdating:(id)sender;

/*!
 * @method changeAlignImageUpdating:
 * @abstract Set wether to redisplay the image when aligned.
 * @param sender The checkbox
 */
- (IBAction)changeAlignCheck:(id)sender;

/*!
 * @method changeAlignMultiProc:
 * @abstract Set the multiprocessor optimization to use for alignment.
 * @param sender The popup
 */
- (IBAction)changeAlignMultiProc:(id)sender;
@end

#endif
