//
//  Lynkeos
//  $Id: LynkeosFileReader.h 471 2008-11-02 15:00:54Z j-etienne $
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
 \page fileAccess File access architecture
 The document contains lists of items ; each item owns a reader object which is
 able to read the image or movie file associated with this item. The reader
 implements either the \ref LynkeosImageFileReader protocol or the
 \ref LynkeosMovieFileReader protocol, both being children of the 
 \ref LynkeosFileReader protocol.<br>
 When the window controller needs to save an image or a sequence in a file, it
 uses a writer object able to save it in the required format. The writer
 implements either the \ref LynkeosImageFileWriter protocol or the
 \ref LynkeosMovieFileWriter protocol, both being children of the
 \ref LynkeosFileWriter protocol.
 \dot
 digraph process {
    node [shape=record, fontname=Helvetica, fontsize=10];
    doc [ label="Document"];
    window [ label="Window controller"];
    list [ label="Image list"];
    item [ label="Item"];
    reader [ label="Reader" URL="\ref LynkeosFileReader"];
    writer [ label="Writer" URL="\ref LynkeosFileWriter"];
    doc -> window [ arrowhead="open", style="dashed" ];
    doc -> list [ arrowhead="open", style="dashed" ];
    list -> item [ arrowhead="open", style="dashed" ];
    item -> reader [ arrowhead="open", style="solid" ];
    window -> writer [ arrowhead="open", style="solid" ];
 }
 \enddot
 */

/*!
 * @header
 * @abstract File reader protocols.
 * @discussion These protocols will be conformed to by the classes which 
 *   implements the read of some image or movie file format.
 */
#ifndef __LYNKEOSFILEREADER_H
#define __LYNKEOSFILEREADER_H

#import <Foundation/Foundation.h>
#import <AppKit/NSImage.h>

#include "LynkeosCore/LynkeosImageBuffer.h"

/*! \defgroup FileAccess Graphic files access
 *
 * The graphic files access classes are used by the models and controller 
 * classes to read and write data to/from graphics files of many formats.
 */

/*!
 * @abstract Common protocol for all file readers.
 * @discussion This protocol is not meant to be directly implemented. It is 
 *   the common part of more specialized protocols.
 * @ingroup FileAccess
 */
@protocol LynkeosFileReader <NSObject>

/*!
 * @abstract Returns the file types handled by that class.
 * @discussion The priority option shall be implemented only if you provide a 
 *   specialized reader which overrides a generic one for some particular 
 *   implementation of a file type (ex: the 16 bits TIFF reader overrides the 
 *   Cocoa TIFF reader for 16 bits files)
 * @param fileTypes The file types (as NSString  coded for use by NSOpenPanel) 
 *   that this class knows how to read. If a file type is preceded in the array
 *   by a NSNumber, the higher the number, the higher this class has priority 
 *   for opening that kind of file (otherwise, the priority is set to zero).
 */
+ (void) lynkeosFileTypes:(NSArray**)fileTypes ;

/*!
 * @abstract Initializes an instance for reading an URL.
 * @discussion If this URL cannot be read by this class, the instance 
 *   deallocates itself and returns nil.
 * @param url The URL of the file to read.
 * @result The initialized instance.
 */
- (id) initWithURL:(NSURL*)url ;

/*!
 * @abstract Get the pixel size of the image or movie.
 * @param[out] w the image width
 * @param[out] h the image height
 */
- (void) imageWidth:(u_short*)w height:(u_short*)h ;

/*!
 * @abstract Get the number of color planes in this file
 * @result The number of color planes
 */
- (u_short) numberOfPlanes;

/*!
 * @abstract Retrieves the minimum and maximum levels for this file
 * @discussion The usual implementation is to return 0..255 and to return images
 *    with pixels in this range. But, file format permitting, it is possible to
 *    return other values if they are relevant.
 * @param[out] vmin The minimum level
 * @param[out] vmax The maximum level
 */
- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax ;

/*!
 * @abstract Get the metadata of this file
 * @discussion This method is reserved for future use. Current implementations 
 *   shall return nil.
 * @result A Property list containing the metadata.
 */
- (NSDictionary*) getMetaData ;

/*!
 * @abstract Does this reader provides some custom image buffer class(es) ?
 * @discussion This method return YES if the image data is better represented 
 *   by a custom kind of LynkeosImageBuffer class. In which case, the main app 
 *   will use this class for calibration purpose.
 * @result Wether the reader has a custom image buffer class
 */
+ (BOOL) hasCustomImageBuffer ;

/*!
 * @abstract Can image/movie data be calibrated by another reader instance data.
 * @discussion This method will be called if and only if the reader has a 
 *   custom image buffer. It shall return YES if the other reader custom image 
 *   data can be used to calibrate this instance data.<br>
 *   In other words : "does the data from the two readers comes from the same 
 *   representation of the same sensor ?".
 *
 *   In a typical implementation, it tests if the readers are instances of the 
 *   same class.<br>
 *   Actual implementations will for sure do something different.
 * @param reader The reader instance from which data should be used to 
 *   calibrate ours.
 */
- (BOOL) canBeCalibratedBy:(id <LynkeosFileReader>)reader ;

@end

/*!
 * @abstract Protocol for image file readers.
 * @discussion It allows the application to access image data.
 * @ingroup FileAccess
 */
@protocol LynkeosImageFileReader <LynkeosFileReader>

/*!
 * @abstract Returns an NSImage for displaying.
 * @result A NSImage built from the image data.
 */
- (NSImage*) getNSImage;

/*!
 * @abstract Retrieves image data for processing.
 * @discussion The (x,y) coordinate system has its origin in the top left 
 *   corner of the image. The samples shall be ordered left to right, then top 
 *   to bottom.<br>
 *   Most file formats share this orientation and pixels ordering.
 *
 *   Implementors can use the macro SET_SAMPLE to fill the output buffer.
 * @param sample An array of buffers to fill with image data
 * @param precision Wether the sample buffer shall be filled with floats or 
 *   doubles
 * @param nPlanes The number of buffers in the array. It can be 1 (the data 
 *   shall be converted to monochrome), or 3 (RGB data).
 * @param x X origin of the sample
 * @param y Y origin of the sample
 * @param w Width of sample
 * @param h Height of sample
 * @param lineW The number of samples in each line, as it can be larger than 
 *   w there may be spare at the end of the lines. This only applies to sample
 */
- (void) getImageSample:(void * const * const)sample 
          withPrecision:(floating_precision_t)precision
             withPlanes:(u_short)nPlanes
                    atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
              lineWidth:(u_short)lineW ;

/*!
 * @abstract Retrieves image data in a custom format for calibration (see 
 *   hasCustomImageBuffer).
 * @param x X origin of the sample
 * @param y Y origin of the sample
 * @param w Width of sample
 * @param h Height of sample
 * @result The image data in a custom format class conforming to 
 *   LynkeosImageBuffer
 */
- (id <LynkeosImageBuffer>) getCustomImageSampleAtX:(u_short)x Y:(u_short)y 
                                                  W:(u_short)w H:(u_short)h ;

@end

/*!
 * @abstract Protocol for movie file readers.
 * @discussion It allows the application to access each movie frame data.
 * @ingroup FileAccess
 */
@protocol LynkeosMovieFileReader <LynkeosFileReader>

/*!
 * @abstract Returns the number of frames in the movie
 * @result The number of movie frames.
 */
- (u_long) numberOfFrames ;

/*!
 * @abstract Returns an NSImage for displaying one movie frame.
 * @param index The index of the frame to read.
 * @result A NSImage built from the image data.
 */
- (NSImage*) getNSImageAtIndex:(u_long)index ;

/*!
 * @abstract Retrieves one movie frame data for processing.
 * @discussion The (x,y) coordinate system has its origin in the top left 
 *   corner of the image. The samples shall be ordered left to right, then top 
 *   to bottom.<br>
 *   Most file formats share this orientation and pixels ordering.
 *
 *   Implementors can use the macro SET_SAMPLE (from LynkeosImageBuffer.h) to 
 *   fill the output buffer.
 * @param sample An array of buffers to fill with image data
 * @param precision Wether the sample buffer shall be filled with floats or 
 *   doubles
 * @param index The index of the frame to read.
 * @param nPlanes The number of buffers in the array. It can be 1 (the data 
 *   shall be converted to monochrome), or 3 (RGB data).
 * @param x X origin of the sample
 * @param y Y origin of the sample
 * @param w Width of sample
 * @param h Height of sample
 * @param lineW The number of samples in each line, as it can be larger than 
 *   w there may be spare at the end of the lines. This only applies to sample
 */
- (void) getImageSample:(void * const * const)sample atIndex:(u_long)index
          withPrecision:(floating_precision_t)precision
             withPlanes:(u_short)nPlanes
                    atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
              lineWidth:(u_short)lineW ;

/*!
 * @abstract Retrieves image data in a custom format for calibration.(see 
 *   hasCustomImageBuffer).
 * @param index The index of the frame to read.
 * @param x X origin of the sample
 * @param y Y origin of the sample
 * @param w Width of sample
 * @param h Height of sample
 * @result The image data in a custom format class conforming to 
 *   LynkeosImageBuffer protocol
 */
- (id <LynkeosImageBuffer>) getCustomImageSampleAtIndex:(u_long)index
                                                   atX:(u_short)x Y:(u_short)y 
                                                     W:(u_short)w H:(u_short)h ;
@end

#endif
