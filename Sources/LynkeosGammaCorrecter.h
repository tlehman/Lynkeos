//
//  Lynkeos
//  $Id: LynkeosGammaCorrecter.h 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun Aug 17 2008.
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
//

/*!
 * @header
 * @abstract Definitions for the gamma correcter utility class.
 */

#ifndef __LYNKEOSGAMMACORRECTER_H
#define __LYNKEOSGAMMACORRECTER_H

#import <Foundation/Foundation.h>

/*!
 * @abstract Class which handle the gamma correction
 * @discussion It is instanciated once per window controller to allow caching
 *    gamma related data (LUT for instance).
 * @ingroup Support
 */
@interface LynkeosGammaCorrecter : NSObject
{
@public
   double _gamma;          //!< Current gamma value
   double _exponent;       //!< Real exponent applied to the curve
   double _linearExtent;   //!< Raw value extent of the linear part
   double _offset;         //!< Offset for the linear part
   double _slope;          //!< Slope of the linear part
   u_char *_lut;           //!< Look Up Table for 8 bit conversion
   u_long _lutSize;        //!< Size of the LUT

   u_long _inUse;          //!< To avoid changing the gamma while used
}

/*!
 * @abstract get a converter for a gamma value, it is created if needed
 * @param gamma The gamma value
 * @result The converter
 */
+ (LynkeosGammaCorrecter*) getCorrecterForGamma:(double)gamma ;

/*!
 * @abstract Let the gamma converter be reused for another gamma value if needed
 */
- (void) releaseCorrecter ;

@end

// "Friend" methods to inline the processing

/*!
 * @abstract Convert raw pixel value to a "displayable" value
 * @param value Raw pixel value
 * @param back Black level in raw data
 * @param white White level in raw data
 * @result The corrected value, the range is 0 for black to 1 for white
 */
static inline double correctedValuewithBlackAndWhite( LynkeosGammaCorrecter *c, 
                                                     double value,
                                                     double black,
                                                     double white )
{
   double res = 0.0;

   if ( value <= black )
      res = 0.0;

   else if ( value >= white )
      res = 1.0;

   else
   {
      res = (value - black)/(white - black);

      if ( c->_exponent != 1.0 )
      {
         if ( res <= c->_linearExtent )
            res *= c->_slope;

         else
         {
            if ( c->_exponent < 1.0 )
               res = (1.0+c->_offset)*pow(res,c->_exponent) - c->_offset;

            else
               res = pow((res+c->_offset)/(1.0+c->_offset),c->_exponent);
         }
      }
   }

   return( res );
}

/*!
 * @abstract Convert a [0..1] pixel value to a "displayable" value
 * @param value pixel value
 * @result The corrected value, the range is 0 for black to 1 for white
 */
static inline double correctedValue( LynkeosGammaCorrecter *c, double v ) 
{
   return( correctedValuewithBlackAndWhite( c, v, 0.0, 1.0 ) );
}

/*!
 * @abstract Convert raw pixel value to a 8 bits pixel for screen display
 * @param value Raw pixel value
 * @param back Black level in raw data
 * @param white White level in raw data
 * @result The corrected value, the range is 0 for black to 255 for white
 */
static inline u_char screenCorrectedValueWithBlackAndWhite(
                                                      LynkeosGammaCorrecter *c,
                                                      double value,
                                                      double black,
                                                      double white )
{
   u_char res;

   if ( value <= black )
      res = 0;
   else if ( value >= white )
      res = 255;
   else
      res = c->_lut[(u_long)((value - black)/(white - black)*c->_lutSize)];

   return( res );
}

/*!
 * @abstract Convert a [0..1] pixel value to a 8 bits pixel for screen display
 * @param value pixel value
 * @result The corrected value, the range is 0 for black to 255 for white
 */
static inline u_char screenCorrectedValue( LynkeosGammaCorrecter *c,
                                          double value )
{
   return( screenCorrectedValueWithBlackAndWhite(c,value,0.0,1.0) );
}

#endif
