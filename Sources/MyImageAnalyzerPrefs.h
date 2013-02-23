// 
//  Lynkeos
//  $Id: MyImageAnalyzerPrefs.h 444 2008-08-26 14:50:42Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Jun 8 2007.
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

#ifndef __MYIMAGEANALYZER_PREFS_H
#define __MYIMAGEANALYZER_PREFS_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "LynkeosProcessing.h"
#include "LynkeosPreferences.h"

//! Lower frequency cutoff for power spectrum analysis
extern NSString * const K_PREF_ANALYSIS_LOWER_CUTOFF;
//! Upper frequency cutoff for power spectrum analysis
extern NSString * const K_PREF_ANALYSIS_UPPER_CUTOFF;
//! Wether to redisplay the images once analyzed
extern NSString * const K_PREF_ANALYSIS_IMAGE_UPDATING;
//! What kind of multiprocessor optimization to use for analysis
extern NSString * const K_PREF_ANALYSIS_MULTIPROC;

@interface MyImageAnalyzerPrefs : NSObject <LynkeosPreferences>
{
   IBOutlet NSView*           _prefsView;
   IBOutlet NSSlider*         _analysisLowerCutoffSlider;
   IBOutlet NSTextField*      _analysisLowerCutoffText;
   IBOutlet NSSlider*         _analysisUpperCutoffSlider;
   IBOutlet NSTextField*      _analysisUpperCutoffText;
   IBOutlet NSButton*         _analysisImageUpdatingButton;
   IBOutlet NSPopUpButton*    _analysisMultiProcPopup;   

   double                     _analysisLowerCutoff;
   double                     _analysisUpperCutoff;
   BOOL                       _analysisImageUpdating;
   ParallelOptimization_t     _analysisMultiProc;   
}

/*!
 * @method changeAnalysisLowerCutoff:
 * @abstract Set the analysis low frequency
 * @param sender The slider or the text field
 */
- (IBAction)changeAnalysisLowerCutoff:(id)sender;

/*!
* @method changeAnalysisUpperCutoff:
 * @abstract Set the analysis high frequency
 * @param sender The slider or the text field
 */
- (IBAction)changeAnalysisUpperCutoff:(id)sender;

/*!
 * @method changeAnalysisImageUpdating:
 * @abstract Set wether to redisplay the image when analyzed.
 * @param sender The checkbox
 */
- (IBAction)changeAnalysisImageUpdating:(id)sender;

/*!
 * @method changeAnalysisMultiProc:
 * @abstract Set the multiprocessor optimization to use for analysis.
 * @param sender The popup
 */
- (IBAction)changeAnalysisMultiProc:(id)sender;

@end

#endif
