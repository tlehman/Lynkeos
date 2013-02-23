//
//  Lynkeos
//  $Id: MyWavelet.h 475 2008-11-09 10:14:42Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Thu Dec 6 2007.
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
 * @abstract Definitions for Wavelet processing.
 */
#ifndef __MYWAVELET_H
#define __MYWAVELET_H

#import <Foundation/Foundation.h>

#include "LynkeosProcessing.h"

/*!
 * @abstract Kind of wavelet
 * @ingroup Processing
 */
typedef enum
{
   FrequencySawtooth_Wavelet,     /* linear frequency interpolation */
   ESO_Wavelet       /* Gaussians difference */
} wavelet_kind_t;

/*!
 * @abstract One wavelet definition
 * @discussion The wavelet is defined by its spectrum which is a real sawtooth
 *    with its peak at the wavelet frequency and which falls to zero at the 
 *    neighbour wavelets frequencies.
 * @ingroup Processing
 */
typedef struct
{
   double _frequency;   //!< Wavelet frequency (in cycles per pixel)
   double _weight;      //!< Wavelet peak spectrum amplitude
} wavelet_t;

/*!
 * @abstract Wavelet processing parameters
 * @ingroup Processing
 */
@interface MyWaveletParameters : LynkeosImageProcessingParameter
{
@public
   wavelet_kind_t _waveletKind;  //!< Kind of wavelet to use
   u_short    _numberOfWavelets; //!< Size of the wavelet array
   wavelet_t *_wavelet;          //!< Array of wavelets

   NSLock   *_loopLock;           //!< Exclusive access to members below
   LynkeosFourierBuffer *_spectrum;    //!< Spectrum being processed
   u_short  _livingThreadsNb;     //!< Number of threads still living
   u_short  _nextY;               //!< Next line to process
}
@end

/*!
 * @abstract Wavelet processing
 * @ingroup Processing
 */
@interface MyWavelet : NSObject <LynkeosProcessing>
{
   MyWaveletParameters  *_params; //!< Wavelet parameters
   id <LynkeosProcessableItem> _item; //!< The item being processed
   //! Strategy (vector or not) method for processing one line
   void(*_process_One_Line)(MyWaveletParameters*,u_short);
}

@end
#endif
