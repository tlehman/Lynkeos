/*
 //
 //  Lynkeos
 //  $Id: ProcessingUtilities.h 475 2008-11-09 10:14:42Z j-etienne $
 //
 //  Created by Jean-Etienne LAMIAUD on Sun Nov 4 2007.
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
 */

/*!
 * @header
 * @abstract Common utilities for image processing.
 */
#ifndef __PROCESSINGUTILITIES_H
#define __PROCESSINGUTILITIES_H

#include "processing_core.h"

/*!
 * @abstract Create a bidimensional gaussian curve
 * @param[out] planes The planes to fill with the gaussian
 * @param width The image width
 * @param height The image height
 * @param nPlanes The number of planes to fill
 * @param lineWidth The number of "REAL" in a line
 * @param radius The gaussian radius
 * @ingroup Processing
 */
extern void MakeGaussian( REAL * const * const planes,
                          u_short width, u_short height, u_short nPlanes,
                          u_short lineWidth, double radius );
#endif
