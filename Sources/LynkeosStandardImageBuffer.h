//
//  Lynkeos
//  $Id: LynkeosStandardImageBuffer.h 482 2008-12-08 16:38:55Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Mar 07 2005.
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

/*!
 * @header
 * @abstract Definitions for the application image buffer class.
 */
#ifndef __LYNKEOSSTANDARDIMAGEBUFFER_H
#define __LYNKEOSSTANDARDIMAGEBUFFER_H

#import <Foundation/Foundation.h>

#include "LynkeosCore/LynkeosImageBuffer.h"

/*!
 * @abstract Strategy used for arithmetic operators
 * @ingroup Processing
 */
typedef enum
{
   StandardStrategy,       //!< Operation is performed in the current thread
   ParallelizedStrategy    //!< Operation is parallelized in many threads
} ImageOperatorsStrategy_t;

/*!
 * @abstract Internal type used for arithmetic operators.
 * @discussion Either an image or a scalar.
 * @ingroup Processing
 */
typedef union
{
   LynkeosStandardImageBuffer *term; //!< When operator acts on an image
   float  fscalar;         //!< When operator acts on a single precision scalar
   double dscalar;         //!< When operator acts on a double precision scalar
} ArithmeticOperand_t;

/*!
 * @abstract Internal method pointer to arithmetically process one line
 */
typedef void(*ImageProcessOneLine_t)(LynkeosStandardImageBuffer*,
                                     ArithmeticOperand_t,
                                     LynkeosStandardImageBuffer*,
                                     u_short);

/*!
 * @abstract Class used for floating precision images.
 * @discussion For optimization purposes, the methods for accessing pixels 
 *   value are implemented as macros
 * @ingroup Processing
 */
@interface LynkeosStandardImageBuffer : NSObject <LynkeosImageBuffer>
{
@public
   u_short   _nPlanes;     ///< Number of color planes
   u_short  _w;            ///< Image pixels width
   u_short  _h;            ///< Image pixels width
   u_short  _padw;         ///< Padded line width (>= width)
   void     *_data;        ///< Pixel buffer, the planes are consecutive
@protected
   void     *_planes[3];   ///< Shortcuts to the color planes
   BOOL     _freeWhenDone; ///< Whether to free the planes on dealloc
   double   _min[4];          ///< The image minimum value
   double   _max[4];          ///< The image maximum value

   //! Strategy method for multiplying a line, with vectorization, or not
   ImageProcessOneLine_t _mul_one_image_line;
   //! Strategy method for scaling a line, with vectorization, or not
   ImageProcessOneLine_t _scale_one_image_line;
   //! Strategy method for dividing a line, with vectorization, or not
   ImageProcessOneLine_t _div_one_image_line;
   //! Strategy method for processing an image, actually for debug
   SEL     _process_image_selector;
   //! Strategy method for processing an image, func pointer which is called
   void (*_process_image)(id,SEL,ArithmeticOperand_t,
                          LynkeosStandardImageBuffer*res,
                          ImageProcessOneLine_t);
}

/*!
 * @abstract Allocates a new empty buffer
 * @param nPlanes Number of color planes for this image
 * @param w Image pixels width
 * @param h Image pixels height
 * @result The initialized buffer.
 */
- (id) initWithNumberOfPlanes:(u_short)nPlanes 
                        width:(u_short)w height:(u_short)h ;

/*!
 * @abstract Initialize a new buffer with preexisting data
 * @param data Image data
 * @param copy Whether to copy the data
 * @param freeWhenDone Whether to free the planes on dealloc (relevant only when
 *    copy is NO)
 * @param nPlanes Number of color planes for this image
 * @param w Image pixels width
 * @param padw Padded width of the data
 * @param h Image pixels height
 * @result The initialized buffer.
 */
- (id) initWithData:(void*)data
               copy:(BOOL)copy freeWhenDone:(BOOL)freeWhenDone
     numberOfPlanes:(u_short)nPlanes 
              width:(u_short)w paddedWidth:(u_short)padw height:(u_short)h ;

/*!
 * @abstract Change the strategy of arithmetic operators
 * @discussion The images are always created with the standard strategy (no
 *    parallelization).
 * @param strategy The new strategy
 */
- (void) setOperatorsStrategy:(ImageOperatorsStrategy_t)strategy ;

/*!
 * @abstract Reset the min and max to unset values
 */
- (void) resetMinMax ;

/*!
 * @abstract Get the minimum and maximum pixels value
 * @param[out] vmin Minimum pixel value
 * @param[out] vmax Maximum pixel value
 */
- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax ;

/*!
 * @abstract Get the minimum and maximum pixels value for a given plane
 * @param[out] vmin Minimum pixel value
 * @param[out] vmax Maximum pixel value
 * @param plane he plane for which min and max will be returned
 */
- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax
            forPlane:(u_short)plane;
/*!
 * @abstract Access to the color planes
 * @result An array of pointer to the color planes
 */
- (void * const * const) colorPlanes ;

/*!
 * @abstract Access to one color component of a pixel
 * @discussion This method is implemented as a macro for speed purpose
 * @param buf An instance of LynkeosStandardImageBuffer
 * @param prec The precision in which we are working
 * @param x Pixel's x coordinate
 * @param y Pixel's y coordinate
 * @param c Color plane
 * @result The access for this pixel (it can be used as an lvalue)
 * @relates LynkeosStandardImageBuffer
 * @ingroup Processing
 */
#define stdColorValue(buf,prec,x,y,c) \
   (prec==SINGLE_PRECISION ? \
      (((float*)(buf)->_data)[((y)+(c)*(buf)->_h)*(buf)->_padw+(x)]) : \
      (((double*)(buf)->_data)[((y)+(c)*(buf)->_h)*(buf)->_padw+(x)]) )

/*!
 * @abstract Extract a rectangle in the image
 */
- (void) extractSample:(void * const * const)planes 
                   atX:(u_short)x Y:(u_short)y
             withWidth:(u_short)w height:(u_short)h
            withPlanes:(u_short)nPlanes
             lineWidth:(u_short)lineW ;

/*!
 * @abstract Substract an image from another
 * @param image The other image to substract
 */
- (void) substract:(LynkeosStandardImageBuffer*)image ;

/*!
 * @abstract Shifts another image and add it to this one
 * @param image The other image to add
 * @param offsets An array of offsets (one per plane) expressed in the 
 *   coordinate system of "image".
 * @param expand The pixel expansion of the resulting image
 */
- (void) add:(LynkeosStandardImageBuffer*)image
                               withOffsets:(const NSPoint*)offsets 
                               withExpansion:(u_short)expand;

/*!
 * @abstract Multiplication
 * @discussion Term shall either have the same number of planes as the receiver
 *    or only one plane. In the latter case, the plane is applied to each planes
 *    of the receiver.
 * @param term other term
 * @param result where the result is stored, can be one of the terms.
 */
- (void) multiplyWith:(LynkeosStandardImageBuffer*)term
                               result:(LynkeosStandardImageBuffer*)result ;

/*!
 * @abstract Multiplication with a scalar
 * @param scalar The scalar by wich all pixels are multiplied
 */
- (void) multiplyWithScalar:(double)scalar ;

/*!
 * @abstract Division
 * @discussion term shall either have the same number of planes as the receiver
 *    or only one plane. In the latter case, the plane is applied to each planes
 *    of the receiver.
 * @param denom Denominator of the division
 * @param result where the result is stored, can be one of the terms
 */
- (void) divideBy:(LynkeosStandardImageBuffer*)denom
                               result:(LynkeosStandardImageBuffer*)result ;

/*!
 * @abstract Convenience empty image buffer creator
 * @param nPlanes Number of color planes for this image
 * @param w Image pixels width
 * @param h Image pixels height
 * @result The allocated and initialized LynkeosStandardImageBuffer.
 */
+ (LynkeosStandardImageBuffer*) imageBufferWithNumberOfPlanes:(u_short)nPlanes 
                               width:(u_short)w height:(u_short)h ;

/*!
 * @abstract Convenience initialized image buffer creator
 * @param data Image data
 * @param copy Wether to copy the data
 * @param freeWhenDone Whether to free the planes on dealloc (relevant only when
 *    copy is NO)
 * @param nPlanes Number of color planes for this image
 * @param w Image pixels width
 * @param padw Padded width of the data
 * @param h Image pixels height
 * @result The allocated and initialized LynkeosStandardImageBuffer.
 */
+ (LynkeosStandardImageBuffer*) imageBufferWithData:(void*)data
                               copy:(BOOL)copy  freeWhenDone:(BOOL)freeWhenDone
                               numberOfPlanes:(u_short)nPlanes 
                               width:(u_short)w paddedWidth:(u_short)padw
                               height:(u_short)h ;
@end

#endif

