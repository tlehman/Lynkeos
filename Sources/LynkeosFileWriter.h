//
//  Lynkeos
//  $Id: LynkeosFileWriter.h 462 2008-10-05 21:31:44Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun Apr 03 2005.
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
 * @abstract File writer protocols.
 * @discussion These protocols will be conformed to by the classes which 
 *   implements the writing of some image or movie file format.
 */
#ifndef __LYNKEOSFILEWRITER_H
#define __LYNKEOSFILEWRITER_H

#import <Foundation/Foundation.h>
#import <AppKit/NSPanel.h>

#include "LynkeosCore/LynkeosProcessing.h"

/*!
 * @abstract Common protocol for all file writers.
 * @discussion This protocol is not meant to be directly implemented. It is 
 *   the common part of more specialized protocols.
 * @ingroup FileAccess
 */
@protocol LynkeosFileWriter <NSObject>

/*!
 * @abstract Get a string identifying this writer.
 * @discussion This string will be displayed by the application in a menu for
 *   choosing the writer.
 * @result The writer's name
 */
+ (NSString*) writerName ;

/*!
 * @abstract Get the extension that should be appended to a file name, when 
 *   written by this reader.
 * @result This writer's file type extension.
 */
+ (NSString*) fileExtension ;

/*!
 * @abstract Check if this writer is able to save that kind of data.
 * @discussion For example: some format only supports monochrome images.<br>
 *   Implementations that do not support metadata can return YES, and ignore 
 *   the metaData parameter.
 * @param nPlanes The number of color planes to save
 * @param w The image width
 * @param h The image height
 * @param metaData A property list containing image metadata
 */
+ (BOOL) canSaveDataWithPlanes:(u_short)nPlanes 
                         width:(u_short)w height:(u_short)h
                      metaData:(NSDictionary*)metaData ;

/*!
 * @abstract Get a configuration panel for this writer.
 * @discussion The application calls runModal on this panel, when the call 
 *   returns with NSOKButton, the writer's configurable parameters are set 
 *   for writing.
 * @result This writer's configuration panel.
 */
- (NSPanel*) configurationPanel ;

/*!
 * @abstract Constructor which creates a writer ready for writing some data 
 *   with the given parameters.
 * @discussion Implementations are not required to make use of the arguments, 
 *   therefore they shall be repeated verbatim in the saveData method.
 * @param url The URL of the file to be saved
 * @param nPlanes The number of color planes in the image
 * @param w The image width
 * @param h The image height
 * @param metaData The imag metadata
 */
+ (id <LynkeosFileWriter>) writerForURL:(NSURL*)url 
                                  planes:(u_short)nPlanes 
                                   width:(u_short)w height:(u_short)h
                                metaData:(NSDictionary*)metaData ;

@end

/*!
 * @abstract Protocol to conform for image file writers
 * @ingroup FileAccess
 */
@protocol LynkeosImageFileWriter <LynkeosFileWriter>

/*!
 * @abstract Save the image data in a file at the given URL. Simple as that ;o)
 * @discussion The pixels in the data are already scaled to 0.0 for black and
 *    1.0 for white. The parameters @param black and @param white give the value
 *    they had in the source image before scaling ; this can be used to save the
 *    original value (for example in floating point FITS).
 * @param url The URL of the file to save
 * @param data An array of pointers to the image color planes
 * @param precision Wether the data buffer contains floats or doubles
 * @param black The value of the black level in the source image
 * @param white The value of the white level in the source image
 * @param nPlanes The number of color planes.
 * @param w Width of sample
 * @param lineW The number of samples in each line, as it can be larger than 
 *   w there may be spare at the end of the lines.
 * @param h Height of sample
 * @param metaData The image meta data
 */
- (void) saveImageAtURL:(NSURL*)url
              withData:(const void * const * const)data
         withPrecision:(floating_precision_t)precision
            blackLevel:(double)black whiteLevel:(double)white
            withPlanes:(u_short)nPlanes
                 width:(u_short)w
             lineWidth:(u_short)lineW 
                height:(u_short)h
              metaData:(NSDictionary*)metaData ;

@end

/*!
 * @abstract This protocol describes the delegate which feed the movie writer 
 *   with frame data
 * @ingroup FileAccess
 */
@protocol LynkeosMovieFileWriterDelegate
/*!
 * @abstract Retrieve image data for the given frame
 * @param index The index of the frame to retrieve.
 * @param planes An array of color plane pointers filled by the delegate
 * @param lineW The sample width of each color plane.
 */
- (void) getFrameAtIndex:(u_long)index 
                withData:(const void * const *)planes
               lineWidth:(u_short)lineW ;
@end

/*!
 * @abstract Protocol to conform for movie file writers
 * @ingroup FileAccess
 */
@protocol LynkeosMovieFileWriter <LynkeosFileWriter>

/*!
 * @abstract Save the movie data in a file at the given URL. 
 * @discussion The pixels in the data are already scaled to 0.0 for black and
 *    1.0 for white. The parameters @param black and @param white give the value
 *    they had in the source image before scaling ; this can be used to save the
 *    original value.
 * @param url The URL of the file to save
 * @param delegate The delegate which provides each frame data
 * @param precision The floating point precision of the data returned by the 
 *   delegate
 * @param black The value of the black level to apply to the source image
 * @param white The value of the white level to apply to the source image
 * @param nPlanes The number of color planes.
 * @param w Width of sample
 * @param h Height of sample
 * @param metaData The image meta data
 */
- (void) saveMovieAtURL:(NSURL*)url
          withDelegate:(id <LynkeosMovieFileWriterDelegate>)delegate
         withPrecision:(floating_precision_t)precision
             blackLevel:(double)black whiteLevel:(double)white
            withPlanes:(u_short)nPlanes
                 width:(u_short)w
                height:(u_short)h
              metaData:(NSDictionary*)metaData ;

@end

#endif
