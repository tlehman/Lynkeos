/*=============================================================================
**  Lynkeos
**  $Id: processing_core.h 480 2008-11-23 15:13:52Z j-etienne $
**-----------------------------------------------------------------------------
**
**  Created by Jean-Etienne LAMIAUD on Fri Dec 05 2003.
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
 * @abstract Common processing definitions
 */
#ifndef __PROCESSING_CORE_H
#define __PROCESSING_CORE_H

#include <math.h>
#ifdef __sun__
#define _Complex_I      (__extension__ 1.0iF)
#else
#include <complex.h>
#endif
#include <fftw3.h>

#include "LynkeosCommon.h"

/* Types used in all processing routines */

/*! \page options Compilation options
 * The preprocessor variable "DOUBLE_PIXELS" causes the application to be built 
 * with double precision for all its internal calculations, if it is defined.
 * Otherwise, the default is to use single precision.
 *
 * For 8 bit images (webcam) 
 * the double precision is needed if the list of images to process exceeds 
 * 16384 elements (if you need this let me know ;o). For 12 bit images (DSLR) 
 * the double precision is useful for processing more than 1024 images... And 
 * at last, for 16 bits images (astronomical CCD) the double precision is 
 * useful because the the limit is only 64 images.
 *
 * Whatever precision Lynkeos is compiled with, it opens Lynkeos documents saved
 * with any precision.
 */
#ifndef DOUBLE_PIXELS
typedef float REAL;     //!< Floating precision type used by the application
#else
typedef double REAL;
#endif

/*!
 * @abstract Vector type
 * @ingroup Processing
 */
#if !defined(DOUBLE_PIXELS) || defined(__i386__)
#ifdef __ALTIVEC__
typedef __vector REAL REALVECT;
#else
#ifdef DOUBLE_PIXELS
typedef REAL REALVECT __attribute__ ((vector_size (32)));
#else
typedef REAL REALVECT __attribute__ ((vector_size (16)));
#endif
#endif
#endif

#ifndef DOUBLE_PIXELS
//! Kind of floating type precision
#define PROCESSING_PRECISION   SINGLE_PRECISION
typedef fftwf_complex COMPLEX;   //!< Complex type with application's precision
typedef fftwf_plan FFT_PLAN;     //!< FFTW plan with application's precision
#else
#define PROCESSING_PRECISION   DOUBLE_PRECISION
typedef fftw_complex COMPLEX;
typedef fftw_plan FFT_PLAN;
#endif

/*!
 * @function initializeProcessing
 * @abstract Processing initialization
 * @result None 
 * @ingroup Processing
 */
extern void initializeProcessing(void);

#endif
