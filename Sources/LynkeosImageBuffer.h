//
//  Lynkeos
//  $Id: LynkeosImageBuffer.h 479 2008-11-23 14:28:07Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Wed Mar 23 2005.
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
 * @abstract Image buffer protocol.
 * @discussion Protocol to be conformed by the classes which manage image data.
 *   These classes are expected to internally represent the image data with 
 *   floating precision (for efficient calibration and stacking).
 */
#ifndef __LYNKEOSIMAGEBUFFER_H
#define __LYNKEOSIMAGEBUFFER_H

#import <AppKit/AppKit.h>

#include "LynkeosCore/LynkeosProcessing.h"

#define RED_PLANE 0     //!< Index of the red plane in RGB buffers
#define GREEN_PLANE 1   //!< Index of the green plane in RGB buffers
#define BLUE_PLANE 2    //!< Index of the blue plane in RGB buffers

/*!
 * @abstract Generic image management
 * @ingroup Processing
 */
@protocol LynkeosImageBuffer <NSCopying, LynkeosProcessingParameter>

/*!
 * @abstract The memory size occupied by this item
 * @discussion The object shall use class_getInstanceSize and add the size of
 *    any aggregated objects and "mallocated" buffers.
 * @result The item's size
 */
- (size_t) memorySize ;

/*!
 * @abstract Get the image pixels width
 * @result The image width
 */
- (u_short) width ;

/*!
 * @abstract Get the image pixels height
 * @result The image height
 */
- (u_short) height ;

/*!
 * @abstract Get the number of color planes
 * @result The number of color planes
 */
- (u_short) numberOfPlanes ;

/*!
 * @abstract Retrieve a Cocoa 24 bits RGB bitmap representation
 * @discussion The black, white and gamma are arrays of values for each plane,
 *    and a last "global" value that is applied equally on each plane.
 * @param black Black level for conversion for each plane
 * @param white White level for conversion for each plane
 * @param gamma Gamma correction exponent  for each plane (ie: 1 = no correction)
 * @result The 8 bits RGB bitmap representation of the buffer data
 */
- (NSBitmapImageRep*) getNSImageWithBlack:(double*)black white:(double*)white
                                    gamma:(double*)gamma;

/*!
 * @abstract Add another image buffer.
 * @discussion The image to add shall be an instance of the same class as self
 *   and have the same size (method implementation can rely on this).
 * @param image The image to add
 */
- (void) add :(id <LynkeosImageBuffer>)image ;

/*!
 * @abstract Calibrate the image with the calibration images.
 * @discussion darkFrame and flatField, when present, are instances of the same
 *   class as self. They are "full sensor" images.
 *
 *   The darkFrame, if any, shall be substracted from the image and the result
 *   shall be divided by the flatField, if any.
 *
 *   The coordinates are specified using the same orientation as in 
 *   LynkeosFileReader
 * @param darkFrame The dark frame image, nil if not present
 * @param flatField The flat field image, nil if not present
 * @param ox The X origin of our image in the full sensor frame.
 * @param oy The Y origin of our image in the full sensor frame.
 */
- (void) calibrateWithDarkFrame:(id <LynkeosImageBuffer>)darkFrame
                      flatField:(id <LynkeosImageBuffer>)flatField
                            atX:(u_short)ox Y:(u_short)oy ;

/*!
 * @abstract Multiplies all values with a scalar
 * @param factor The value by which each pixel is multiplied. If 0, the factor 
 *   is taken as to set the maximum value of the resulting image to 1.0
 * @param mono If true and factor is zero, the color planes are leveled to 
 *   obtain a non color biased image
 */
- (void) normalizeWithFactor:(double)factor mono:(BOOL)mono ;

/*!
 * @abstract Convert the image buffer data to a floating precision planar 
 *   representation.
 * @discussion The pixels ordering is the same as in LynkeosFileReader.
 * @param planes The color planes to fill with the image data. There are as 
 *   many planes as there are in this instance and their size is the same as 
 *   this instance's image.
 * @param nPlanes Number of planes in the output buffer.
 * @param precision The floating precision of pixels in the output buffer.
 * @param lineW The line width of the output buffer (may be larger than this 
 *   instance's image width).
 */
- (void) convertToPlanar:(void * const * const)planes 
           withPrecision:(floating_precision_t)precision
              withPlanes:(u_short)nPlanes
               lineWidth:(u_short)lineW ;

/*!
 * @abstract Clear the image contents ; all samples are zeroes
 */
- (void) clear ;

@end

#endif
