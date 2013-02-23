//
//  Lynkeos
//  $Id: LynkeosStandardImageBufferAdditions.h 462 2008-10-05 21:31:44Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun Sep 14 2008.
//  Copyright (c) 2008. Jean-Etienne LAMIAUD
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

/*!
 * @header
 * @abstract Application internal definitions for the image buffer class.
 */
#ifndef __LYNKEOSSTANDARDIMAGEBUFFERADDITIONS_H
#define __LYNKEOSSTANDARDIMAGEBUFFERADDITIONS_H

/*!
 * @abstract Access to one color component of a pixel
 * @discussion This method is implemented as a macro for speed purpose
 * @param buf An instance of MyImageBuffer
 * @param x Pixel's x coordinate
 * @param y Pixel's y coordinate
 * @param c Color plane
 * @result The access for this pixel (it can be used as an lvalue)
 */
#define colorValue(buf,x,y,c) (((REAL*)(buf)->_data)[((y)+(c)*(buf)->_h)*(buf)->_padw+(x)])

//! Acces the red value of a pixel
#define redValue(s,x,y) colorValue(s,x,y,RED_PLANE)
//! Acces the green value of a pixel
#define greenValue(s,x,y) colorValue(s,x,y,GREEN_PLANE)
//! Acces the blue value of a pixel
#define blueValue(s,x,y) colorValue(s,x,y,BLUE_PLANE)

#ifndef DOUBLE_PIXELS
//! Prepare N threads for FFTW (float)
#define FFTW_PLAN_WITH_NTHREADS fftwf_plan_with_nthreads 
#else
//! Prepare N threads for FFTW (double)
#define FFTW_PLAN_WITH_NTHREADS fftw_plan_with_nthreads
#endif

/*!
 * @abstract Access to the complex value of a pixel in the spectrum
 * @discussion This method is provided as a macro for speed purpose.
 */
#define colorComplexValue(buf,x,y,c) \
(((COMPLEX*)(buf)->_data)[((y)+(c)*(buf)->_h)*(buf)->_spadw+(x)])

#endif