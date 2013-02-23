// 
//  Lynkeos
//  $Id: MyGeneralPrefs.h 444 2008-08-26 14:50:42Z j-etienne $
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

#ifndef __MYGENERALPREFS_H
#define __MYGENERALPREFS_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "LynkeosProcessing.h"
#include "LynkeosPreferences.h"

//! Wether to adjust the FFT size to optimize FFTW processing time
extern NSString * const K_PREF_ADJUST_FFT_SIZES;
extern NSString * const K_PREF_IMAGEPROC_MULTIPROC;
extern NSString * const K_PREF_END_PROCESS_SOUND;

@interface MyGeneralPrefs : NSObject <LynkeosPreferences>
{
   IBOutlet NSView*           _prefsView;
   IBOutlet NSButton*         _adjustFFTSizesButton;
   IBOutlet NSPopUpButton*    _imageProcOptimPopup;
   IBOutlet NSPopUpButton*    _soundPopup;

   NSMutableArray*            _soundsNames;

   // Preferences
   BOOL                       _adjustFFTSizes;
   ParallelOptimization_t     _imageProcOptim;
   NSString                   *_sound;
}

/*!
 * @abstract Set wether the application should alter the rectangle size for FFT
 *   optimization.
 * @param sender The checkbox
 */
- (IBAction)changeAdjustFFTSizes:(id)sender;

/*!
 * @abstract Set how to use multiprocessors for image processing.
 * @param sender The popup
 */
- (IBAction)changeImageProcOptim:(id)sender;

   /*!
 * @abstract Set which sound to play at end of list processing.
 * @param sender The popup
 */
- (IBAction)changeEndProcessingSound:(id)sender;

@end

#endif
