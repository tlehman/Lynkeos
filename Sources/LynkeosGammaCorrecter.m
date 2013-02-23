//
//  Lynkeos
//  $Id: LynkeosGammaCorrecter.m 435 2008-08-22 21:02:33Z j-etienne $
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

#include "LynkeosGammaCorrecter.h"

#define K_MAX_NB_OF_CONVERTERS 3

static const double K_LinearExtent = 0.00304;

/*!
 * @abstract Gamma converters array
 * @discussion contains all living gamma converters, ordered by last use
 */
static NSMutableArray *converters;

static double gammaCorrected( double v, double exponent, double linearExtent,
                             double offset, double slope )
{
   double res = 0.0;

   if ( exponent == 1.0 )
      res = v;

   else
   {
      if ( v <= linearExtent )
         res = slope * v;

      else
      {
         if ( exponent < 1.0 )
            res = (1.0+offset)*pow(v,exponent) - offset;

         else
            res = pow((v+offset)/(1.0+offset),exponent);
      }
   }

   return res;
}

@interface LynkeosGammaCorrecter(Private)
- (void) changeGamma:(double)gamma ;
@end

@implementation LynkeosGammaCorrecter(Private)
- (void) changeGamma:(double)gamma
{
   NSAssert( _inUse == 0,
             @"Trying to change the gamma of a converter while being used" );
   double g, a;

   if ( _lut != NULL )
      free(_lut );
   _lut = NULL;

   _gamma = gamma;
   _exponent = 1.0/gamma;

   // For gamma < 1, we will use 1/slope and apply offset to the input
   if ( gamma < 1.0 )
      g = 1.0/gamma;
   else
      g = gamma;

   _offset = (1.0 - g)/(g*(1.0 - 1.0/pow(K_LinearExtent,1.0/g))-1);
   a = (1.0 + _offset)/g*pow(K_LinearExtent,1.0/g-1.0);

   if ( gamma < 1.0 )
   {
      _slope = 1.0/a;
      _linearExtent = K_LinearExtent/a;
   }
   else
   {
      _slope = a;
      _linearExtent = K_LinearExtent;
   }

   // Prepare a LUT with these settings
   if ( gamma > 1.0 )
      _lutSize = (u_long)(256.0*_slope + 0.5);
   else
      _lutSize = (u_long)(1.0/(1.0
                               - (1.0+_offset)*pow(255.0/256.0,_exponent)
                               + _offset) + 0.5);

   _lut = (u_char*)malloc( _lutSize*sizeof(u_char) );
   NSAssert1( _lut != NULL, @"Failed to allocate a %d element gamma LUT",
                            _lutSize );

   u_long i;
   for( i = 0; i < _lutSize; i++ )
   {
      double v = gammaCorrected( (double)i/(double)_lutSize,
                                _exponent, _linearExtent,
                                _offset, _slope ) * 256.0;
      if ( v < 256.0 )
         _lut[i] = (u_char)(v);
      else
         _lut[i] = 255;
   }
}
@end

@implementation LynkeosGammaCorrecter
+ (void) initialize
{
   converters = [[NSMutableArray alloc] initWithCapacity:K_MAX_NB_OF_CONVERTERS];
}

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _gamma = 1.0;
      _exponent = 1.0;
      _linearExtent = 0.0;
      _offset = 0.0;
      _slope = 1.0;
      _lut = NULL;
      _lutSize = 0;
      _inUse = 0;
   }

   return( self );
}

- (void) dealloc
{
   if ( _lut != NULL )
      free( _lut );
   [super dealloc];
}

+ (LynkeosGammaCorrecter*) getCorrecterForGamma:(double)gamma
{
   const int nb = [converters count];
   LynkeosGammaCorrecter *c, *theCorrecter;
   int i;

   theCorrecter = nil;
   for( i = 0; i < nb && theCorrecter == nil; i++ )
   {
      c = [converters objectAtIndex:i];
      if ( c->_gamma == gamma )
      {
         // We found it, extract it from the array (it will be put back in front)
         theCorrecter = c;
         [converters removeObject:c];
      }
   }

   if ( theCorrecter == nil )
   {
      // No matching converter found, either reuse the last free one,
      // or create a new
      if ( nb < K_MAX_NB_OF_CONVERTERS )
         theCorrecter = [[self alloc] init];

      else
      {
         for( i = nb-1; i>= 0 && theCorrecter == nil; i-- )
         {
            c = [converters objectAtIndex:i];
            if ( c->_inUse == 0 )
            {
               theCorrecter = c;
               [converters removeObject:c];
            }
         }
      }
      NSAssert( theCorrecter != nil, @"Too much gamma converters in use" );

      [theCorrecter changeGamma:gamma];
   }

   [converters insertObject:theCorrecter atIndex:0];
   theCorrecter->_inUse++;

   return( theCorrecter );
}

- (void) releaseCorrecter
{
   if ( _inUse == 0 )
      NSLog( @"Attempt to release a free gamma converter" );
   else
      _inUse--;
}

@end
