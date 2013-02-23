//
//  Lynkeos
//  $Id: FITSReader.h 425 2008-05-17 22:11:43Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun Apr 17 2005.
//  Copyright (c) 2005. Jean-Etienne LAMIAUD
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
 * @abstract Reader for FITS images
 */
#ifndef __FITSREADER_H
#define __FITSREADER_H

/**
 * \page libraries Libraries needed to compile Lynkeos
 * The FITS reader and writer classes needs the CFITSIO library which can be 
 * found at http://heasarc.gsfc.nasa.gov/fitsio
 */

#include <fitsio.h>

#include "LynkeosFileReader.h"

/*!
* @class FITSReader
 * @abstract Class for reading FITS image file format.
 * @ingroup FileAccess
 */
@interface FITSReader : NSObject <LynkeosImageFileReader>
{
   @private
   fitsfile    *_fits;        //< CFITSIO handle on the FITS file
   u_short     _width;        //< Cached width
   u_short     _height;       //< Cached height
   double      _scale;        //< Value scale to apply for NSImage conversion
   double      _imageScale;   //< Value scale of image
   double      _zero;         //< Zero value to apply for NSImage conversion
   double      _imageZero;    //< Zero value of image
   double      _minValue;     //< Minimum value of data
   double      _maxValue;     //< Maximum value of data
}

@end

#endif
