/*=============================================================================
** Lynkeos
** $Id: corelation.h 475 2008-11-09 10:14:42Z j-etienne $
**-----------------------------------------------------------------------------
**
**  Created by Jean-Etienne LAMIAUD on Aug 5, 2003
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
 * @abstract Definitions related to the corelation operation
 */
#ifndef __CORELATION_H
#define __CORELATION_H

#include "LynkeosCore/LynkeosFourierBuffer.h"

/*!
 * @struct CORRELATION_PEAK
 * @abstract Description of the peak in the correlation data
 * @ingroup Processing
 */
typedef struct
{
   double x;            //!< X coordinate of the peak
   double y;            //!< Y coordinate of the peak
   double val;          //!< Peak value
   double sigma_x;      //!< Peak standard deviation along x axis
   double sigma_y;      //!< Peak standard deviation along y axis
} CORRELATION_PEAK;

/*!
 * @function correlate
 * @abstract Correlate two images
 * @param s1 First image
 * @param s2 Second image
 * @param r Image of the correlation data
 * @ingroup Processing
 */
extern void correlate( LynkeosFourierBuffer *s1, LynkeosFourierBuffer *s2, LynkeosFourierBuffer *r );

/*!
* @function correlate_spectrums
 * @abstract Correlate two spectrums
 * @param s1 First spectrum
 * @param s2 Second spectrum
 * @param r Image of the correlation data
 * @ingroup Processing
 */
extern void correlate_spectrums( LynkeosFourierBuffer *s1, LynkeosFourierBuffer *s2, 
                                 LynkeosFourierBuffer *r );

/*!
* @function corelation_peak
 * @abstract Search the correlation peak in the correlation data
 * @param result Correlation data (result from one correlate call)
 * @param peak Array of CORRELATION_PEAK (one entry per plane in result)
 * @ingroup Processing
 */
extern void corelation_peak( LynkeosFourierBuffer *result, CORRELATION_PEAK *peak );

#endif
