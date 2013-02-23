//
//  Lynkeos
//  $Id: MyCocoaFilesReader.h 452 2008-09-14 12:35:29Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Mar 03 2005.
//  Copyright (c) 2005-2008. Jean-Etienne LAMIAUD
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
 * @abstract Classes that read file formats directly supported by Cocoa.
 * @discussion These classes are bridges between the application and 
 *   NSImage or NSMovie.
 */
#ifndef __MYCOCOAFILEREADER_H
#define __MYCOCOAFILEREADER_H

#include <QTKit/QTMovie.h>
#if !defined GNUSTEP
#include <AvailabilityMacros.h>
#ifndef AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER
#error "Pas defini"
#endif
#include <QuickTime/Movies.h>
#endif

#include "LynkeosCommon.h"
#include "LynkeosFileReader.h"

/*!
 * @class MyCocoaImageReader
 * @abstract Class for reading every Cocoa image file format.
 * @ingroup FileAccess
 */
@interface MyCocoaImageReader : NSObject <LynkeosImageFileReader>
{
@private
   NSString*         _path;            //!< Image file path
   LynkeosIntegerSize     _size;            //!< Image frame size
}
@end

#if !defined GNUSTEP
/*!
 * @class MyQuickTimeReader
 * @abstract Class for reading QuickTime movie files.
 * @ingroup FileAccess
 */
@interface MyQuickTimeReader : NSObject <LynkeosMovieFileReader>
{
@private
   QTMovie          *_movie;           //!< The movie being read
   QTTime           *_times;           //!< Time for each image in the movie
   u_long            _imageNumber;     //!< Number of images in the movie
   u_long            _currentImage;    //!< Last decoded image
   u_short           _nPlanes;         //!< Number of planes
   u_short           _pixmapPlanes;    //!< Number of planes rendered by QT
   u_short           _bitsPerPixel;    //!< Bit resolution of the movie
   QTVisualContextRef _visualContext;  //!< Offscreen bitmap
   NSLock           *_qtLock;          //!< Multithreading protection
   LynkeosIntegerSize     _size;            //!< Movie frame size
   NSString         *_url;             //!< Used for cache key
}
@end
#endif

#endif
