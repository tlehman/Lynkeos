//
//  Lynkeos
//  $Id: LynkeosStandardImageBuffer.m 498 2010-12-29 15:46:09Z j-etienne $
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
// 
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

#ifdef GNUSTEP
#include <GNUstepBase/GSObjCRuntime.h>
#else
#include <objc/objc-class.h>
#endif

#import <AppKit/NSGraphics.h>

#include "processing_core.h"
#include "LynkeosStandardImageBuffer.h"
#include "LynkeosStandardImageBufferAdditions.h"

#include "LynkeosGammaCorrecter.h"

#ifdef DOUBLE_PIXELS
#define powerof(x,y) pow(x,y)
#else
#define powerof(x,y) powf(x,y)
#endif

#define K_PLANES_NUMBER_KEY     @"planes"
#define K_IMAGE_WIDTH_KEY       @"width"
#define K_IMAGE_HEIGHT_KEY      @"height"
#define K_SINGLE_PRECISION_KEY  @"float"
#define K_IMAGE_DATA_KEY	@"data"

/*!
 * @abstract Pixels weight.
 */
typedef struct
{
   REAL x;     //!< X coord !...
   REAL y;     //!< Y coord !...
} PIXELS_WEIGHT_T;

/* Cut the coordinate to the authorized range */
static inline short range( long i, short l )
{
   if ( i < 0 )
      i = 0;

   else if ( i >= l )
      i = l-1;

   return( i );
}

/* Separate an image shift in an integer and a positive fractionary part. */
static void splitOffsets( NSPoint offset, short *i_dx, short *i_dy,
                          REAL *f_dx, REAL *f_dy )
{
   *i_dx = (short)offset.x;
   *f_dx = offset.x - (REAL)*i_dx;
   if ( *f_dx < 0 )
   {
      (*i_dx) --;
      (*f_dx) += 1.0;
   }

   *i_dy = (short)offset.y;
   *f_dy = offset.y - (REAL)*i_dy;
   if ( *f_dy < 0 )
   {
      (*i_dy) --;
      (*f_dy) += 1.0;
   }
}

/* Fill an array with pixels weight versus their modulus in the expansion. */
static PIXELS_WEIGHT_T *getWeights( u_short expand, REAL f_dx, REAL f_dy )
{
   static PIXELS_WEIGHT_T weights[2];
   u_short i;

   if ( expand > 2 )
   {
      fprintf( stderr,
               "We were not supposed to handle an expansion factor of %d\n",
               expand );
      return( NULL );
   }

   for( i = 0; i < expand; i++ )
   {
      weights[i].x = f_dx - i;
      if ( weights[i].x < 0.0 )
         // No x split, right pixel
         weights[i].x = 0.0;
      else if ( weights[i].x > 1.0 )
         // No x split, left pixel
         weights[i].x = 1.0;

      weights[i].y = f_dy - i;
      if ( weights[i].y < 0.0 )
         // No y split, lower pixel
         weights[i].y = 0.0;
      else if ( weights[i].y > 1.0 )
         // No y split, upper pixel
         weights[i].y = 1.0;
   }

   return( weights );
}

/*!
 * Calculate the fractionary shifted pixel value, by splitting it in 4 and 
 * adding the contributions from the 4 pixels in the source image
 *
 * @param image The image from which to extract the pixel value
 * @param plane Which image plane to use
 * @param expand The expansion for add (ie: image size is "expand" times 
 *               smaller than the destination image).
 * @param x X coordinate taking the expansion into account
 * @param y Y coordinate taking the expansion into account
 * @param f_dx X fraction of pixel shift with expansion. Valid values are in
 *             [0 .. expansion[
 * @param f_dy Y fraction of pixel shift with expansion. Valid values are in
 *             [0 .. expansion[
 */
static inline REAL shiftedPixelValue( LynkeosStandardImageBuffer *image, u_short plane, 
                                      u_short expand,
                                      long x, long y, 
                                      const PIXELS_WEIGHT_T *weights )
{
   // Pixel coordinate in the source image
   long ix, iy;
   // Offset inside the source image pixel
   u_short xp0, xp1, yp0, yp1;
   REAL ax, ay, v;

   // Get the coordinates in the source image
   ix = x/expand;
   iy = y/expand;
   xp0 = range(ix-1, image->_w);
   xp1 = range(ix, image->_w);
   yp0 = range(iy-1, image->_h);
   yp1 = range(iy, image->_h);

   // Determine the pixels weight
   ax = weights[(u_long)x%expand].x;
   ay = weights[(u_long)y%expand].y;

   /* First quadrant */
   v = colorValue(image,xp0,yp0,plane) * ax * ay;

   /* Second quadrant */
   v += colorValue(image,xp1,yp0,plane) * (1.0 - ax) * ay;

   /* Third quadrant */
   v += colorValue(image,xp0,yp1,plane) * ax * (1.0 - ay);

   /* Fourth and last quadrant */
   v += colorValue(image,xp1,yp1,plane) * (1.0 - ax) * (1.0 - ay);

   return( v );
}

/*!
 * @abstract Multiply method for strategy "without vectors"
 */
static void std_image_mul_one_line(LynkeosStandardImageBuffer *a,
                                   ArithmeticOperand_t b,
                                   LynkeosStandardImageBuffer *res,
                                   u_short y )
{
   u_short x, c, ct;

   for( x = 0; x < a->_w; x++ )
      for( c = 0; c < a->_nPlanes; c++ )
      {
         if ( b.term->_nPlanes == 1 )
            ct = 0;
         else
            ct = c;
         REAL r = colorValue(a,x,y,c) * colorValue(b.term,x,y,ct);
         colorValue(res,x,y,c) = r;
      }
}

#if !defined(DOUBLE_PIXELS) || defined(__i386__)
/*!
 * @abstract Multiply method for strategy "with vectors"
 */
static void vect_image_mul_one_line(LynkeosStandardImageBuffer *a,
                                   ArithmeticOperand_t b,
                                   LynkeosStandardImageBuffer *res,
                                   u_short y )
{
   u_short x, c, ct;

   for( x = 0; x < a->_w; x += 4 )
   {
      for( c = 0; c < a->_nPlanes; c++ )
      {
         REALVECT r = *((REALVECT*)&colorValue(a,x,y,c));

         if ( b.term->_nPlanes == 1 )
            ct = 0;
         else
            ct = c;

         r *= *((REALVECT*)&colorValue(b.term,x,y,ct));
         *((REALVECT*)&colorValue(res,x,y,c)) = r;
      }
   }
}
#endif

/*!
 * @abstract Scaling method for strategy "without vectors"
 */
static void std_image_scale_one_line(LynkeosStandardImageBuffer *a,
                                   ArithmeticOperand_t b,
                                   LynkeosStandardImageBuffer *res,
                                   u_short y )
{
   u_short x, c;

   for( x = 0; x < a->_w; x++ )
      for( c = 0; c < a->_nPlanes; c++ )
      {
         REAL r = colorValue(a,x,y,c) *
#ifdef DOUBLE_PIXELS
         b.dscalar
#else
         b.fscalar
#endif
         ;
         colorValue(res,x,y,c) = r;
      }
}

/*!
 * @abstract Scaling method for strategy "with vectors"
 */
#if !defined(DOUBLE_PIXELS) || defined(__i386__)
static void vect_image_scale_one_line(LynkeosStandardImageBuffer *a,
                                     ArithmeticOperand_t b,
                                     LynkeosStandardImageBuffer *res,
                                     u_short y )
{
   const REAL s =
#ifdef DOUBLE_PIXELS
      b.dscalar
#else
      b.fscalar
#endif
      ;
   const REALVECT scalar = { s, s, s, s };
   u_short x, c;

   for( x = 0; x < a->_w; x += 4 )
      for( c = 0; c < a->_nPlanes; c++ )
      {
         REALVECT r = *((REALVECT*)&colorValue(a,x,y,c)) * scalar;
         *((REALVECT*)&colorValue(res,x,y,c)) = r;
      }
}
#endif

/*!
 * @abstract Divide method for strategy "without vectors"
 */
static void std_image_div_one_line(LynkeosStandardImageBuffer *a,
                                   ArithmeticOperand_t b,
                                   LynkeosStandardImageBuffer *res,
                                   u_short y )
{
   u_short x, c, ct;

   for( x = 0; x < a->_w; x++ )
      for( c = 0; c < a->_nPlanes; c++ )
      {
         if ( b.term->_nPlanes == 1 )
            ct = 0;
         else
            ct = c;

         REAL n = colorValue(a,x,y,c), d = colorValue(b.term,x,y,ct), r;

         if ( d != 0.0 )
            r = n / d;
         else
            r = 0.0; // Arbitrary value to avoid NaN
         colorValue(res,x,y,c) = r;
      }
}

/*!
 * @abstract Phases of the parallel processing for the lock condition
 */
typedef enum
{
   OperationInited,
   OperationStarted,
   OperationEnded
} ParallelImageOperationState_t;

/*!
 * @abstract Record of data needed for parallelized multiplication
 */
@interface ParallelImageMultiplyArgs : NSObject
{
@public
   ArithmeticOperand_t op;          //!< Second operand
   LynkeosStandardImageBuffer *res; //!< Operation result
   u_short *y;                      //!< Current line
   //! Startegy method for performing the operation on one line
   void(*processOneLine)(LynkeosStandardImageBuffer*,
                         ArithmeticOperand_t,
                         LynkeosStandardImageBuffer*,
                         u_short);
   NSConditionLock *lock;           //!< Exclusive access to this object
   u_short startedThreads;         //!< Total number of started threads
   u_short livingThreads;         //!< Number of still living threads
}
@end

/*!
 * @abstract Private methods
 */
@interface LynkeosStandardImageBuffer(Private)
/*!
 * @abstract Stacks one color plane
 * @param plane The color plane to stack
 * @param image The image to add to ourselves
 */
- (void) stackPlane:(u_short)plane fromImage:(LynkeosStandardImageBuffer*)image ;

/*!
 * @abstract Stacks one color plane with an image shift
 * @param plane The color plane to stack
 * @param image The image to add to ourselves
 * @param offset Offset applied to the other image before adding.
 * @param expand The pixel expansion factor
 */
- (void) stackPlane:(u_short)plane fromImage:(LynkeosStandardImageBuffer*)image 
         withOffset:(NSPoint)offset withExpansion:(u_short)expand ;

/*!
 * @abstract Stack the plane 0 of the argument image into our luminance channel
 * @param image The image to add to ourselves
 */
- (void) stackLRGBfromImage:(LynkeosStandardImageBuffer*)image ;

/*!
 * @abstract Stack the plane 0 of the argument image with a shift into our 
 *   luminance channel
 * @param image The image to add to ourselves
 * @param offset Offset applied to the other image before adding.
 * @param expand The pixel expansion factor
 */
- (void) stackLRGBfromImage:(LynkeosStandardImageBuffer*)image
                 withOffset:(NSPoint)offset withExpansion:(u_short)expand;

/*!
 * @abstract "Shared" multiply method
 */
- (void) one_thread_process_image:(id)arg ;

/*!
 * @abstract Multiply method for strategy "no parallelization"
 */
- (void) std_image_process:(ArithmeticOperand_t)op
                    result:(LynkeosStandardImageBuffer*)res 
            processOneLine:(void(*)(LynkeosStandardImageBuffer*,
                                    ArithmeticOperand_t,
                                    LynkeosStandardImageBuffer*,
                                    u_short))processOneLine ;

/*!
 * @abstract Multiply method for strategy "parallelize"
 */
- (void) parallel_image_process:(ArithmeticOperand_t)term
                         result:(LynkeosStandardImageBuffer*)res 
            processOneLine:(void(*)(LynkeosStandardImageBuffer*,
                                    ArithmeticOperand_t,
                                    LynkeosStandardImageBuffer*,
                                    u_short))processOneLine ;
@end

@implementation ParallelImageMultiplyArgs
@end

@implementation LynkeosStandardImageBuffer(Private)
/*! Macro for the common part of the add routines. */
#define ADD_RGB(add_code)                       \
   for( y = 0; y < _h; y++ )                    \
      for( x = 0; x < _w; x++ )                 \
         colorValue(self,x,y,plane) += add_code;

/*!
 * Both layers are required to have the same size.
 */
- (void) stackPlane:(u_short)plane fromImage:(LynkeosStandardImageBuffer*)image
{
   u_short x, y;

   ADD_RGB( colorValue(image,x,y,plane) );
}

/*!
 * Add two layers with the required offset.
 * Both layers are required to have the same size, taking the expansion into 
 * account.
 */
- (void) stackPlane:(u_short)plane fromImage:(LynkeosStandardImageBuffer*)image 
         withOffset:(NSPoint)offset withExpansion:(u_short)expand
{
   short i_dx, i_dy;
   REAL f_dx, f_dy;
   u_short x, y;
   PIXELS_WEIGHT_T *weight;

   splitOffsets( offset, &i_dx, &i_dy, &f_dx, &f_dy );
   weight = getWeights( expand, f_dx, f_dy );

   /* Add the layer with the shift */
   ADD_RGB( shiftedPixelValue( image, plane, expand,
                               x - i_dx, y - i_dy, weight ) );
}

/*! Macro for the common part of the add routines. */
#define ADD_LRGB(add_code)                                 \
   for( y = 0; y < _h; y++ )                               \
   {                                                       \
      for( x = 0; x < _w; x++ )                            \
      {                                                    \
         REAL red = redValue(self,x,y),                    \
              green = greenValue(self,x,y),                \
              blue = blueValue(self,x,y);                  \
         REAL lratio;                                      \
                                                           \
         lratio = 1.0 + 3*(add_code)/(red + green + blue); \
         redValue(self,x,y) = red * lratio;                \
         greenValue(self,x,y) = green * lratio;            \
         blueValue(self,x,y) = blue * lratio;              \
      }                                                    \
   }

/*!
 * Both layers are required to have the same size.
 */
- (void) stackLRGBfromImage:(LynkeosStandardImageBuffer*)image
{
   u_short x, y;

   /* Add the monochrome layer */
   ADD_LRGB( colorValue(image,x, y,0) );
}

/*!
 * Both layers are required to have the same size.
 */
- (void) stackLRGBfromImage:(LynkeosStandardImageBuffer*)image withOffset:(NSPoint)offset 
              withExpansion:(u_short)expand
{
   short i_dx, i_dy;
   REAL f_dx, f_dy;
   u_short x, y;
   PIXELS_WEIGHT_T *weight;

   splitOffsets( offset, &i_dx, &i_dy, &f_dx, &f_dy );
   weight = getWeights( expand, f_dx, f_dy );

   /* Add the monochrome layer with the shift */
   ADD_LRGB( shiftedPixelValue( image, 0, expand, 
                                x - i_dx, y - i_dy, weight ) );
}

- (void) one_thread_process_image:(id)arg
{
   ParallelImageMultiplyArgs * const args = arg;
   u_short ourY;

   // Count up on entry
   [args->lock lock];
   ourY = *(args->y);
   (*(args->y))++;
   if ( args->startedThreads < numberOfCpus )
      args->startedThreads++;
   else
      NSLog( @"Too much thread start in one_thread_process_image" );
   args->livingThreads++;
   if ( args->startedThreads == numberOfCpus )
      [args->lock unlockWithCondition:OperationStarted];
   else
      [args->lock unlock];

   // Process by sharing lines with other threads
   while( ourY < _h )
   {
      args->processOneLine( self, args->op, args->res, ourY );
      [args->lock lock];
      ourY = *(args->y);
      (*(args->y))++;
      [args->lock unlock];
   }

   // Count down on exit
   [args->lock lock];
   if ( args->livingThreads > 0 )
      args->livingThreads--;
   else
      NSLog( @"Too much thread end in one_thread_process_image" );

   if ( [args->lock condition] == OperationStarted && args->livingThreads == 0 )
      [args->lock unlockWithCondition:OperationEnded];
   else
      [args->lock unlock];
}

- (void) std_image_process:(ArithmeticOperand_t)op
                    result:(LynkeosStandardImageBuffer*)res 
            processOneLine:(void(*)(LynkeosStandardImageBuffer*,
                                    ArithmeticOperand_t,
                                    LynkeosStandardImageBuffer*,
                                    u_short))processOneLine
{
   u_short y;
   for( y = 0; y < _h; y++ )
      processOneLine( self, op, res, y );
}

/*!
 * @abstract Multiply method for strategy "parallelize"
 */
- (void) parallel_image_process:(ArithmeticOperand_t)term
                         result:(LynkeosStandardImageBuffer*)res 
                 processOneLine:(void(*)(LynkeosStandardImageBuffer*,
                                         ArithmeticOperand_t,
                                         LynkeosStandardImageBuffer*,
                                         u_short))processOneLine
{
   NSConditionLock *lock =
                    [[NSConditionLock alloc] initWithCondition:OperationInited];
   u_short y = 0;
   ParallelImageMultiplyArgs *args = [[ParallelImageMultiplyArgs alloc] init];
   int i;

   args->op = term;
   args->res = res;
   args->y = &y;
   args->lock = lock;
   args->processOneLine = processOneLine;
   args->startedThreads = 0;
   args->livingThreads = 0;

   // Start a thread for each "other processor"
   for( i =  1; i < numberOfCpus; i++ )
      [NSThread detachNewThreadSelector:@selector(one_thread_process_image:)
                               toTarget:self
                             withObject:args];

   // Do our part of the job
   [self one_thread_process_image:args];

   // Finally, wait or all threads completion
   [lock lockWhenCondition:OperationEnded];
   [lock unlock];

   [lock release];
   [args release];
}

@end

@implementation LynkeosStandardImageBuffer

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _nPlanes = 0;
      _w = 0;
      _padw = 0;
      _h = 0;
      [self resetMinMax];
      _data = NULL;
      _freeWhenDone = NO;

      if ( hasSIMD )
      {
         _mul_one_image_line = vect_image_mul_one_line;
         _scale_one_image_line = vect_image_scale_one_line;
      }
      else
      {
         _mul_one_image_line = std_image_mul_one_line;
         _scale_one_image_line = std_image_scale_one_line;
      }
      _div_one_image_line = std_image_div_one_line;

      _process_image_selector =
                            @selector(std_image_process:result:processOneLine:);
      _process_image = (void(*)(id,SEL,ArithmeticOperand_t,
                         LynkeosStandardImageBuffer*res,
                         void(*)(LynkeosStandardImageBuffer*,
                                 ArithmeticOperand_t,
                                 LynkeosStandardImageBuffer*,
                                 u_short)))
                               [self methodForSelector:_process_image_selector];
   }

   return( self );
}

- (id) copyWithZone:(NSZone *)zone
{
   return( [[LynkeosStandardImageBuffer allocWithZone:zone] initWithData:_data
                                                       copy:YES
                                               freeWhenDone:YES
                                             numberOfPlanes:_nPlanes
                                                      width:_w
                                                paddedWidth:_padw
                                                     height:_h] );
}

- (id) initWithData:(void*)data
               copy:(BOOL)copy  freeWhenDone:(BOOL)freeWhenDone
     numberOfPlanes:(u_short)nPlanes 
              width:(u_short)w paddedWidth:(u_short)padw height:(u_short)h
{
   u_short c;

   NSAssert( nPlanes == 1 || nPlanes == 3, 
             @"MyImageBuffer handles only monochrome or RGB images" );

   if ( (self = [self init]) != nil )
   {
      u_long dataSize;

      _nPlanes = nPlanes;
      _w = w;
      _padw = padw;
      _h = h;

      if ( copy )
      {
         dataSize = _padw*_h*_nPlanes*sizeof(REAL);
         _data = malloc( dataSize );
         if (data != NULL )
            memcpy( _data, data, dataSize );
         else
            memset( _data, 0, dataSize );
         _freeWhenDone = YES;
      }
      else
      {
         _data = data;
         _freeWhenDone = freeWhenDone;
      }

      // Vectorized instructions are only usable if aligned
      if ( (padw % sizeof(REALVECT)) != 0
           || ((u_long)_data % sizeof(REALVECT)) != 0 )
      {
         _mul_one_image_line = std_image_mul_one_line;
         _scale_one_image_line = std_image_scale_one_line;
      }

      for( c = 0; c < nPlanes; c++ )
         _planes[c] = &((REAL*)_data)[c*_h*_padw];
   }

   return( self );
}

- (id) initWithNumberOfPlanes:(u_short)nPlanes 
                        width:(u_short)w height:(u_short)h
{
   return( [self initWithData:NULL copy:YES freeWhenDone:YES
               numberOfPlanes:nPlanes width:w
                  paddedWidth: // Padded for SIMD
                     sizeof(REALVECT)*((w+sizeof(REALVECT)-1)/sizeof(REALVECT))
                       height:h] );
}

- (void) dealloc
{
   if ( _freeWhenDone )
      free( _data );
   [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
#ifndef DOUBLE_PIXELS
#define SwappedReal NSSwappedFloat
#define ConvertHostToSwappedReal NSConvertHostFloatToSwapped
#else
#define SwappedReal NSSwappedDouble
#define ConvertHostToSwappedReal NSConvertHostDoubleToSwapped
#endif
   NSMutableData *dataWrapper = nil;
   u_short x, y, c;
   SwappedReal *buf;
   u_long i;

   [encoder encodeInt:_nPlanes forKey:K_PLANES_NUMBER_KEY];
   [encoder encodeInt:_w forKey:K_IMAGE_WIDTH_KEY];
   [encoder encodeInt:_h forKey:K_IMAGE_HEIGHT_KEY];

   // Encode data
   dataWrapper = [NSMutableData dataWithLength:
                                            _w*_h*_nPlanes*sizeof(SwappedReal)];

   buf = [dataWrapper mutableBytes];
   for( c = 0, i = 0; c < _nPlanes; c++ )
   {
      for( y = 0; y < _h; y++ )
      {
         for( x = 0; x < _w; x++ )
         {         
            // Data is always archived as planar         
            buf[i] = ConvertHostToSwappedReal(colorValue(self,x,y,c));
            i++;
         }
      }
   }

   [encoder encodeBool:
#ifndef DOUBLE_PIXELS
      YES
#else
      NO
#endif
                forKey:K_SINGLE_PRECISION_KEY];
   [encoder encodeObject:dataWrapper forKey:K_IMAGE_DATA_KEY];
}

- (id)initWithCoder:(NSCoder *)decoder
{
   NSData *dataWrapper = [decoder decodeObjectForKey:K_IMAGE_DATA_KEY];
   u_short planes = [decoder decodeIntForKey:K_PLANES_NUMBER_KEY];
   u_short w = [decoder decodeIntForKey:K_IMAGE_WIDTH_KEY];
   u_short h = [decoder decodeIntForKey:K_IMAGE_HEIGHT_KEY];
   BOOL isFloat = [decoder decodeBoolForKey:K_SINGLE_PRECISION_KEY];

   if ( dataWrapper == nil || planes == 0 || w == 0 || h == 0 )
   {
      [self release];
      self = nil;
   }

   if ( self != nil )
      // Allocate our buffer
      self = [self initWithNumberOfPlanes:planes width:w height:h];

   if ( self != nil )
   {
      // And copy the data in it
      u_short x, y, c;
      const void *buf;
      u_long i;

      buf = [dataWrapper bytes];
      for( c = 0, i=0; c < planes; c++ )
      {
         for( y = 0; y < h; y++ )
         {
            for( x = 0; x < w; x++ )
            {
               REAL v;

               // Data is always archived as planar
               if (isFloat )
                  v = NSConvertSwappedFloatToHost( ((NSSwappedFloat*)buf)[i] );
               else
                  v = NSConvertSwappedDoubleToHost( ((NSSwappedDouble*)buf)[i] );
               i++;

               colorValue(self,x,y,c) = v;
            }
         }
      }
   }

   return( self );
}

- (size_t) memorySize
{
   return( class_getInstanceSize([self class])
           + _nPlanes*_padw*_h*sizeof(REAL) );
}

- (void) setOperatorsStrategy:(ImageOperatorsStrategy_t)strategy
{
   switch( strategy )
   {
      case StandardStrategy:
         _process_image_selector =
                            @selector(std_image_process:result:processOneLine:);
         _process_image = (void(*)(id,SEL,ArithmeticOperand_t,
                                   LynkeosStandardImageBuffer*res,
                                   void(*)(LynkeosStandardImageBuffer*,
                                           ArithmeticOperand_t,
                                           LynkeosStandardImageBuffer*,
                                           u_short)))
                               [self methodForSelector:_process_image_selector];
         break;
      case ParallelizedStrategy:
         _process_image_selector =
                       @selector(parallel_image_process:result:processOneLine:);
         _process_image = (void(*)(id,SEL,ArithmeticOperand_t,
                                   LynkeosStandardImageBuffer*res,
                                   void(*)(LynkeosStandardImageBuffer*,
                                           ArithmeticOperand_t,
                                           LynkeosStandardImageBuffer*,
                                           u_short)))
                               [self methodForSelector:_process_image_selector];
         break;
      default:
         NSAssert1( NO, @"Unknown strategy %d in LynkeosStandardImageBuffer",
                    strategy);
         break;
   }
}

- (void) resetMinMax
{
   u_short c;
   for( c = 0; c <= 3; c++ )
   {
      _min[c] = 0.0;
      _max[c] = -1.0;
   }
}

- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax
{
   if ( _min[_nPlanes] >= _max[_nPlanes] )
   {
      int x, y, c;

      for( c = 0; c <= _nPlanes; c++ )
      {
         _min[c] = HUGE;
         _max[c] = -HUGE;
      }
      for( c = 0; c < _nPlanes; c++ )
      {
         for( y = 0; y < _h; y++ )
         {
            for( x = 0; x < _w; x++ )
            {
               double v = colorValue(self,x,y,c);
               if ( _min[c] > v )
                  _min[c] = v;
               if ( _max[c] < v )
                  _max[c] = v;
            }
         }
         if ( _min[_nPlanes] > _min[c] )
            _min[_nPlanes] = _min[c];
         if ( _max[_nPlanes] < _max[c] )
            _max[_nPlanes] = _max[c];
      }
   }

   *vmin = _min[_nPlanes];
   *vmax = _max[_nPlanes];
}

- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax
            forPlane:(u_short)plane
{
   double notused;

   if ( _min[plane] >= _max[plane] )
      [self getMinLevel:&notused maxLevel:&notused];

   *vmin = _min[plane];
   *vmax = _max[plane];
}

- (u_short) width { return( _w ); }
- (u_short) height { return( _h ); }
- (u_short) numberOfPlanes { return( _nPlanes ); }

- (void * const * const) colorPlanes
{
   return( (void * const * const)_planes );
}

- (NSBitmapImageRep*) getNSImageWithBlack:(double*)black white:(double*)white
                                    gamma:(double*)gamma
{
   const u_short nPlanes = (_nPlanes <= 3 ? _nPlanes : 3);
   NSBitmapImageRep* bitmap;
   u_char *pixels;
   u_short x, y, c;
   int bpp, bpr;
   double vmin, vmax;

   // Create a bitmap
   bitmap = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
						     pixelsWide:_w
						     pixelsHigh:_h
						  bitsPerSample:8
                                                samplesPerPixel:3
						       hasAlpha:NO
						       isPlanar:NO
                                       colorSpaceName:NSCalibratedRGBColorSpace
						    bytesPerRow:0
						   bitsPerPixel:0]
                                                                  autorelease];
   // Retrieve the geometry allocated by the runtime
   bpp = [bitmap bitsPerPixel];
   bpr = [bitmap bytesPerRow];
   NSAssert( (bpp%8) == 0,
             @"Hey, I do not intend to work on non byte boudaries" );
   bpp /= 8;

   // Copy the pixels
   pixels = [bitmap bitmapData];
   NSAssert( white[_nPlanes] > black[_nPlanes],
            @"Inconsistent black and white levels" );
   const double a = 1.0/(white[_nPlanes] - black[_nPlanes]);

   [self getMinLevel:&vmin maxLevel:&vmax];
   for( c = 0; c < nPlanes; c++ )
   {
      NSAssert( white[c] > black[c],
                @"Inconsistent black and white plane levels" );
      const double ac = (vmax - vmin)/(white[c] - black[c]);
      LynkeosGammaCorrecter *gammaCorrect =
          [LynkeosGammaCorrecter getCorrecterForGamma:gamma[_nPlanes]*gamma[c]];

      for( y = 0; y < _h; y++ )
      {
         for( x = 0; x < _w; x++ )
         {
            u_char v = screenCorrectedValue( gammaCorrect,
                                    ( (colorValue(self,x,y,c) - black[c])*ac
                                      + _min[_nPlanes] - black[_nPlanes] ) * a);
            if ( _nPlanes != 1 )
               pixels[y*bpr+x*bpp+c] = v;

            // Convert monochrome image to RGB representation
            else
            {
               u_short p;
               for( p = 0; p < 3; p++ )
                  pixels[y*bpr+x*bpp+p] = v;

            }
         }
      }

      [gammaCorrect releaseCorrecter];
   }

   return( bitmap );
}

- (void) substract:(LynkeosStandardImageBuffer*)image
{
   u_short x, y, c;

   for( c = 0; c < _nPlanes; c++ )
      for( y = 0; y < _h; y++ )
         for( x = 0; x < _w; x++ )
            colorValue(self,x,y,c) -= colorValue(image,x,y,c);
}

/*!
 * Only images of the same size can be added (so far).
 */
- (void) add:(id <LynkeosImageBuffer>)image
{
   static const NSPoint freeze[3] = {{0.0,0.0},{0.0,0.0},{0.0,0.0}};
   [self add:(LynkeosStandardImageBuffer*)image withOffsets:freeze
         withExpansion:1];
}

/*!
 * Only images of the same size can be added (so far).
 * The offsets array is required to have as many elements as image has planes.
 */
- (void) add:(LynkeosStandardImageBuffer*)image
            withOffsets:(const NSPoint*)offsets 
          withExpansion:(u_short)expand
{
   NSAssert( expand != 0, @"Illegal expansion factor" );
   NSAssert( _w == image->_w*expand && _h == image->_h*expand, 
             @"Stack with different sizes" );

   [self resetMinMax];

   if ( _nPlanes == image->_nPlanes )
   {
      // Same structure, simply add plane by plane
      u_short plane;

      for( plane = 0; plane < _nPlanes; plane++ )
      {
         if ( offsets[plane].x == 0.0 && offsets[plane].y == 0.0 
              && expand == 1 )
            [self stackPlane:plane fromImage:image];
         else
            [self stackPlane:plane fromImage:image withOffset:offsets[plane]
                  withExpansion:expand];
      }
   }
   else
   {
      // Composite: add the monochrome plane into the luminance channel
      if ( image->_nPlanes == 1 )
      {
         if ( offsets[0].x == 0.0 && offsets[0].y == 0.0 
              && expand == 1 )
            [self stackLRGBfromImage:image];
         else
            [self stackLRGBfromImage:image withOffset:offsets[0] 
                  withExpansion:expand];
      }

      else
      {
         u_short plane;
         // Copy ourselves in a temporary image buffer
         LynkeosStandardImageBuffer *monoImage =
                           [LynkeosStandardImageBuffer imageBufferWithData:_data
                                                   copy:NO freeWhenDone:YES
                                                   numberOfPlanes:_nPlanes
                                                   width:_w
                                                   paddedWidth:_padw
                                                   height:_h];

         // Make this image become RGB
         _nPlanes = image->_nPlanes;
         _data = malloc( _padw*_h*_nPlanes*sizeof(REAL) );
         for( plane = 0; plane < _nPlanes; plane++ )
            _planes[plane] = &((REAL*)_data)[plane*_h*_padw];

         // Add the image with its offsets to this null image
         memset( _data, 0, _padw*_h*_nPlanes*sizeof(REAL) );
         for( plane = 0; plane < _nPlanes; plane++ )
         {
            if ( offsets[plane].x == 0.0 && offsets[plane].y == 0.0
                 && expand == 1 )
               [self stackPlane:plane fromImage:image];
            else
               [self stackPlane:plane fromImage:image 
                     withOffset:offsets[plane]
                     withExpansion:expand];
         }

         // And add the former (ourself) monochrome image with no offset
         [self stackLRGBfromImage:monoImage];
      }
   }
}

- (void) multiplyWith:(LynkeosStandardImageBuffer*)term
               result:(LynkeosStandardImageBuffer*)result
{
   NSAssert( (_nPlanes == term->_nPlanes || term->_nPlanes == 1)
            && _nPlanes == result->_nPlanes 
            && _w == term->_w && _h == term->_h
            && _w == result->_w && _h == result->_h,
            @"Incompatible terms in multiplication" );
   ArithmeticOperand_t op = { .term=term };

   [self resetMinMax];
   _process_image( self, _process_image_selector, op, result,
                  _mul_one_image_line );
}

- (void) multiplyWithScalar:(double)scalar
{
   ArithmeticOperand_t op =
#ifdef DOUBLE_PIXELS
   { .dscalar=scalar }
#else
   { .fscalar=scalar }
#endif
   ;

   [self resetMinMax];
   _process_image( self, _process_image_selector, op, self,
                   _scale_one_image_line );
}

- (void) divideBy:(LynkeosStandardImageBuffer*)denom result:(LynkeosStandardImageBuffer*)result
{   
   NSAssert( (_nPlanes == denom->_nPlanes || denom->_nPlanes == 1)
            && _nPlanes == result->_nPlanes 
            && _w == denom->_w && _h == denom->_h
            && _w == result->_w && _h == result->_h,
            @"Incompatible terms in division" );
   ArithmeticOperand_t op = { .term=denom };

   [self resetMinMax];
   _process_image( self, _process_image_selector, op, result,
                  _div_one_image_line );
}


- (void) calibrateWithDarkFrame:(id <LynkeosImageBuffer>)darkFrame
                      flatField:(id <LynkeosImageBuffer>)flatField
                             atX:(u_short)ox Y:(u_short)oy
{
   LynkeosStandardImageBuffer *dark = darkFrame, *flat = flatField;
   u_short x, y, c;

   NSAssert( ( darkFrame == nil 
               || [darkFrame isKindOfClass:[LynkeosStandardImageBuffer class]] )
             && ( flatField == nil
              || [flatField isKindOfClass:[LynkeosStandardImageBuffer class]] ),
             @"Calibration with heterogenous classes" );
   NSAssert( ( dark == nil || _nPlanes == dark->_nPlanes )
             && ( flat == nil || _nPlanes == flat->_nPlanes ),
             @"Inconsistent calibration frames depth" );

   [self resetMinMax];
   for( c = 0; c < _nPlanes; c++ )
   {
      for( y = 0; y < _h; y++ )
      {
         for( x = 0; x < _w; x++ )
         {
            REAL v = colorValue(self,x,y,c);
            if ( dark != nil )
               v -= colorValue(dark,x+ox,y+oy,c);
            if ( flat != nil )
               v /= colorValue(flat,x+ox,y+oy,c);

            colorValue(self,x,y,c) = v;
         }
      }
   }
}

- (void) normalizeWithFactor:(double)factor mono:(BOOL)mono
{
   double s;
   u_short x, y, c;

   // Calculate max values if needed
   if ( factor == 0.0 )
   {
      double max = -HUGE;

      // The factor shall be 1/max
      for( y = 0; y < _h; y++ )
      {
         for( x = 0; x < _w; x++ )
         {
            if ( mono )
            {
               REAL v = 0.0;

               // Convert first each plane to a copy of the monochrome image
               for( c = 0; c < _nPlanes; c++ )
                  v += colorValue(self,x,y,c);

               v /= (REAL)_nPlanes;

               for( c = 0; c < _nPlanes; c++ )
                  colorValue(self,x,y,c) = v;

               if ( v > max )
                  max = v;
            }
            else
            {
               for( c = 0; c < _nPlanes; c++ )
               {
                  REAL v = colorValue(self,x,y,c);
                  u_short plane;

                  if ( mono )
                     // Calculate the max for each plane
                     plane = c;
                  else
                     plane = 0;

                  if ( v > max )
                     max = v;
               }
            }
         }
      }
      s = 1.0/max;
   }
   else
      s = factor;

   // Apply the factor
   for( c = 0; c <= _nPlanes; c++ )
   {
      _min[c] = HUGE;
      _max[c] = -HUGE;
   }
   for( c = 0; c < _nPlanes; c++ )
   {
      for( y = 0; y < _h; y++ )
      {
         for( x = 0; x < _w; x++ )
         {
            REAL v = colorValue(self,x,y,c) * s;
            colorValue(self,x,y,c) = v;
            if ( _min[c] > v )
               _min[c] = v;
            if ( _max[c] < v )
               _max[c] = v;
         }
      }
      if ( _min[_nPlanes] > _min[c] )
         _min[_nPlanes] = _min[c];
      if ( _max[_nPlanes] < _max[c] )
         _max[_nPlanes] = _max[c];
   }
}

- (void) extractSample:(void * const * const)planes 
                   atX:(u_short)x Y:(u_short)y
             withWidth:(u_short)w height:(u_short)h
            withPlanes:(u_short)nPlanes
             lineWidth:(u_short)lineW
{
   u_short xi, yi, c;

   for( c = 0; c < nPlanes; c++ )
   {
      for( yi = 0; yi < h; yi++ )
      {
         for( xi = 0; xi < w; xi++ )
         {
            REAL v;

            if ( nPlanes == 1 )
            {
               u_short p;

               // Convert to monochrome
               for ( p = 0, v = 0; p < _nPlanes; p++ )
                  v += colorValue(self,xi+x,yi+y,p);
               v /= (REAL)_nPlanes;
            }
            else
            {
               if ( c < _nPlanes )
                  v = colorValue(self,xi+x,yi+y,c);
               else
                  v = 0;
            }

            SET_SAMPLE(planes[c],PROCESSING_PRECISION,xi,yi,lineW,v);
         }
      }
   }
}

- (void) convertToPlanar:(void * const * const)planes 
           withPrecision:(floating_precision_t)precision
              withPlanes:(u_short)nPlanes
               lineWidth:(u_short)lineW
{
   NSAssert( precision == PROCESSING_PRECISION,
             @"Wrong precision in [MyImageBuffer convertToPlanar" );
   [self extractSample:(void*const*const)planes atX:0 Y:0 withWidth:_w height:_h
            withPlanes:nPlanes lineWidth:lineW];
}

- (void) clear
{
   u_short x, y, c;

   [self resetMinMax];
   for( c = 0; c < _nPlanes; c++ )
      for( y = 0; y < _h; y++ )
         for( x = 0; x < _w; x++ )
            colorValue(self,x,y,c) = 0.0;
}

+ (LynkeosStandardImageBuffer*) imageBufferWithData:(void*)data
                                  copy:(BOOL)copy freeWhenDone:(BOOL)freeWhenDone
                        numberOfPlanes:(u_short)nPlanes 
                                 width:(u_short)w paddedWidth:(u_short)padw 
                                height:(u_short)h
{
   return( [[[self alloc] initWithData:data copy:copy freeWhenDone:freeWhenDone
                        numberOfPlanes:nPlanes width:w paddedWidth:padw
                                height:h] autorelease] );
}

+ (LynkeosStandardImageBuffer*) imageBufferWithNumberOfPlanes:(u_short)nPlanes 
                                           width:(u_short)w height:(u_short)h
{
   return( [[[self alloc] initWithNumberOfPlanes:nPlanes width:w height:h]
                                                                autorelease] );
}

@end
