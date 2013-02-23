//
//  Lynkeos
//  $Id: MyWaveletView.h 479 2008-11-23 14:28:07Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Dec 7 2007.
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

/*!
 * @header
 * @abstract View controller of the unsharp mask processing.
 */
#ifndef __MYWAVELETVIEW_H
#define __MYWAVELETVIEW_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "LynkeosProcessingView.h"
#include "MyWavelet.h"

/*!
 * @abstract View controller of the deconvolution processing
 * @ingroup Processing
 */
@interface MyWaveletView : NSObject <LynkeosProcessingView>
{
   IBOutlet NSView            *_panel;            //!< Our view
   IBOutlet NSPopUpButton     *_progressionPopup; //!< Geometric/arithmetic
   IBOutlet NSTextField       *_progrStepText;    //!< Geometric progress step
   IBOutlet NSTextField       *_numberOfFreqText; //!< Number of wavelets
   IBOutlet NSStepper         *_numberOfFreqStep; //!< Stepper for wavelet nb
   IBOutlet NSPopUpButton     *_algorithmPopup;   //!< ESO/sawtooth choice
   IBOutlet NSButton          *_freqDisplaySwitch; //!< Freq/Pixels display choice
   IBOutlet NSButton          *_addFreqButton;     //!< Add a wavelet
   IBOutlet NSMatrix          *_deleteFreqButton;  //!< Delete a wavelet
   IBOutlet NSMatrix          *_freqMatrix;        //!< Wavelet frequencies
   IBOutlet NSMatrix          *_selectMatrix;      //!< Display one wavelet
   IBOutlet NSMatrix          *_levelSliderMatrix; //!< Wavelet level sliders
   IBOutlet NSMatrix          *_levelTextMatrix;   //!< Wavelet level text fields
   IBOutlet NSProgressIndicator *_progress;        //!< Progress bar

   id <LynkeosViewDocument> _document;             //!< Our document
   id <LynkeosWindowController> _window;           //!< Our window controler
   id <LynkeosImageView>       _imageView;         //!< For result display
   id <LynkeosImageView>       _realImageView;     //!< To jump over a proxy
   NSOutlineView              *_textView;          //!< The items list

   LynkeosProcessableImage    *_item;              //!< Item being processed
   MyWaveletParameters        *_params;            //!< Wavelet parameters
   BOOL                        _isProcessing;      //!< Whether process is running
   BOOL                        _displayFrequency;  //!< Freq/Pixels display
   //! Timer for progress bar update
   NSTimer                    *_progressTimer;
}

/*!
 * @abstract The kind of frequency progression was changed
 * @param sender The control which value was changed
 */
- (IBAction) progressionChange: (id)sender ;
/*!
 * @abstract The step of the frequency prgression was changed
 * @param sender The control which value was changed
 */
- (IBAction) progressionStepChange: (id)sender ;
/*!
 * @abstract The number of wavelets was changed
 * @param sender The control which value was changed
 */
- (IBAction) numberOfFreqChange: (id)sender ;
/*!
 * @abstract The kind of wavelet algo was changed
 * @param sender The control which value was changed
 */
- (IBAction) algorithmChange: (id)sender ;
/*!
 * @abstract The choice between frequency or pixels display was changed
 * @param sender The control which value was changed
 */
- (IBAction) freqDisplayChange: (id)sender ;
/*!
 * @abstract Add one wavelet to the series
 * @param sender The button
 */
- (IBAction) addOneFrequency: (id)sender ;
/*!
 * @abstract Delete one wavelet
 * @param sender The button
 */
- (IBAction) deleteOneFrequency: (id)sender ;
/*!
 * @abstract The frequency of a wavelet was changed
 * @param sender The control which value was changed
 */
- (IBAction) freqChange: (id)sender ;
/*!
 * @abstract Alternate between one wavelet display and full series
 * @param sender The button
 */
- (IBAction) selectChange: (id)sender ;
/*!
 * @abstract The level of one wavelet was changed
 * @param sender The control which value was changed
 */
- (IBAction) levelChange: (id)sender ;

@end

#endif
