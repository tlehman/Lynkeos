//
//  Lynkeos
//  $Id: MyTiff16Reader.h 471 2008-11-02 15:00:54Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Tue Mar 29 2005.
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

/**
 * \page libraries Libraries needed to compile Lynkeos
 * The TIFF reader and writer classes needs the libtiff library which can be 
 * found at http://www.remotesensing.org/libtiff/
 */

/*!
 * @header
 * @abstract Reader for 16 bits and monochrome TIFF images
 * @discussion These formats are not directly supported by Cocoa, which reads 
 *   them as 8 bits RGB images. This class is delared with a higher priority.
 *
 */
#ifndef __MYTIFF16READER_H
#define __MYTIFF16READER_H

#include <tiffio.h>

#include <LynkeosCore/LynkeosFileReader.h>

/*!
 * @abstract Class for reading 16 bits or monochrome TIFF image file format.
 * @discussion The TIFF file is opened and closed each time we need to read its
 *   contents. Otherwise, all the TIFF files would be loaded in memory.
 * @ingroup FileAccess
 */
@interface MyTiff16Reader : NSObject <LynkeosImageFileReader>
{
@private
   char     *_tiffFile;  //!< Path and name of the TIFF file
   uint32   _width;      //!< Cached width
   uint32   _height;     //!< Cached height
   u_short  _planar;     //!< Is the image planar
   u_short  _nPlanes;    //!< Number of color planes
   uint32   _stripH;     //!< Tiff strip height
   u_short  _nBits;      //!< Number of bits per pixels
   u_short  _sampleType; //!< Integer or float pixels
   double   _min;        //!< Minimum pixel value
   double   _max;        //!< Maximum pixel value
}

@end

#endif
