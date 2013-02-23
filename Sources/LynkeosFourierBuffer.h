/*=============================================================================
** Lynkeos
** $Id: LynkeosFourierBuffer.h 479 2008-11-23 14:28:07Z j-etienne $
**-----------------------------------------------------------------------------
**
**  Created by Jean-Etienne LAMIAUD on Aug 5, 2003.
**  Copyright (c) 2003-2008. Jean-Etienne LAMIAUD
**
** This program is free software; you can redistribute it and/or modify
** it under the terms of the GNU General Public License as published by
** the Free Software Foundation; either version 2 of the License, or
** (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software
** Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
**
**-----------------------------------------------------------------------------
*/

/*!
 * @header
 * @abstract Definitions related to the Fourier transform
 */
#ifndef __LYNKEOSFOURIERBUFFER_H
#define __LYNKEOSFOURIERBUFFER_H

#include "LynkeosCore/LynkeosStandardImageBuffer.h"

/**
 * \ifnot LynkeosCore
 * \page libraries Libraries needed to compile Lynkeos
 * The Fourier transformations needs FFTW3 library which can be found at 
 * http://www.fftw.org
 * \endif
 */

/*-----------------------------------------------------------------------------
** MACROS
**-----------------------------------------------------------------------------
*/

#define FOR_DIRECT  1      //!< Prepare a buffer for direct transform
#define FOR_INVERSE 2      //!< Prepare a buffer for inverse transform

/*!
 * @abstract Internal method pointer to arithmetically process one line
 */
typedef void(*SpectrumProcessOneLine_t)(LynkeosFourierBuffer *a,
                                        ArithmeticOperand_t op,
                                        LynkeosFourierBuffer *res,
                                        u_short y );

/*!
 * @abstract Class used to wrap the Fourier transform with FFTW library.
 * @ingroup Processing
 */
@interface LynkeosFourierBuffer : LynkeosStandardImageBuffer
{
@public
   //! The spectrum has only half the image width (complex pixels)
   u_short     _halfw;
   u_short     _spadw;     //!< Spectrum padded width
@private
   u_char      _goal;      //!< The kind of transform that will be performed
   void       *_direct;    //!< FFTW plan for direct transform, if any
   void       *_inverse;   //!< FFTW plan for inverse transform, if any
   BOOL        _isSpectrum; //!< Current state : spatial or frequency

   //! Strategy method for multiplying a line, with vectorization, or not
   SpectrumProcessOneLine_t _mul_one_spectrum_line;
   //! Strategy method for multiplying a line with a conjugate
   SpectrumProcessOneLine_t _mul_one_conjugate_line;
   //! Strategy method for scaling a line
   SpectrumProcessOneLine_t _scale_one_spectrum_line;
   //! Strategy method for dividing a line
   SpectrumProcessOneLine_t _div_one_spectrum_line;
}

/*!
 * @abstract Allocates a new empty buffer
 * @param nPlanes Number of color planes for this image
 * @param w Image pixels width
 * @param h Image pixels height
 * @param goal What kind of transform to prepare, direct, inverse or both.
 * @result The allocated and initialized buffer, ready for FFT.
 */
- (id) initWithNumberOfPlanes:(u_char)nPlanes 
                        width:(u_short)w height:(u_short)h 
                     withGoal:(u_char)goal ;

/*!
 * @abstract Allocates a new empty buffer
 * @param nPlanes Number of color planes for this image
 * @param w Image pixels width
 * @param h Image pixels height
 * @param goal What kind of transform to prepare, direct, inverse or both.
 * @param isSpectrum Whether the initial data is a spectrum
 * @result The allocated and initialized buffer, ready for FFT.
 */
- (id) initWithNumberOfPlanes:(u_char)nPlanes 
                        width:(u_short)w height:(u_short)h 
                     withGoal:(u_char)goal
                   isSpectrum:(BOOL)isSpectrum;

/*!
 * @abstract Tells whether the instance is a spectrum or an image
 * @result YES if the instance is a spectrum
 */
- (BOOL) isSpectrum ;

/*!
 * @abstract Compute the direct transform
 * @result none
 */
- (void) directTransform ;

/*!
 * @abstract Compute the inverse transform, normalize the result and returns
 *   the values extremes
 */
- (void) inverseTransform ;

/*!
 * @abstract Normalize the spectrum to a 1.0 continous level
 */
- (void) normalize ;

/*!
 * @abstract Transform the spectrum pixels into their conjugate
 */
- (void) conjugate ;

/*!
 * @abstract Multiplication with conjugate
 * @discussion term shall either have the same number of planes as the receiver
 *    or only one plane. In the latter case, the plane is applied to each planes
 *    of the receiver.
 * @param term other term (shall be a spectrum)
 * @param result where the result is stored, can be one of the terms
 */
- (void) multiplyWithConjugateOf:(LynkeosFourierBuffer*)term
                          result:(LynkeosFourierBuffer*)result ;

/*!
 * @abstract Access to the complex value of a pixel in the spectrum
 * @discussion This method is provided as a macro for speed purpose.
 * @param buf The fourier buffer
 * @param p The processing precision
 * @param x The X coordinate of the pixel
 * @param y The Y coordinate of the pixel
 * @param c The color plane
 * @ingroup Processing
 * @relates LynkeosFourierBuffer
 */
#define stdColorComplexValue(buf,p,x,y,c) \
   (p == SINGLE_PRECISION ? \
    (((float _Complex*)(buf)->_data)[((y)+(c)*(buf)->_h)*(buf)->_spadw+(x)]) : \
    (((double _Complex*)(buf)->_data)[((y)+(c)*(buf)->_h)*(buf)->_spadw+(x)]) )

/*!
 * @abstract Allocates a new empty buffer
 * @param nPlanes Number of color planes for this image
 * @param w Image pixels width
 * @param h Image pixels height
 * @param goal What kind of transform to prepare, direct, inverse or both.
 * @result The allocated and initialized buffer, ready for FFT.
 */
+ (LynkeosFourierBuffer*) fourierBufferWithNumberOfPlanes:(u_char)nPlanes 
                                              width:(u_short)w 
                                             height:(u_short)h 
                                           withGoal:(u_char)goal ;

@end

/*!
 * @abstract Base 2 logarithm
 * @param val The source value
 * @result Its logarithm.
 */
extern short log_2( short val );

#endif
