//
//  Lynkeos
//  $Id: MyUnsharpMask.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun Dec 2 2007.
//  Copyright (c) 2007-2008. Jean-Etienne LAMIAUD
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

#include "MyGeneralPrefs.h"
#include "LynkeosFourierBuffer.h"
#include "LynkeosStandardImageBufferAdditions.h"
#include <LynkeosCore/LynkeosThreadConnection.h>

#include "MyUnsharpMask.h"

static NSString * const K_RADIUS_KEY = @"radius";
static NSString * const K_GAIN_KEY = @"gain";
static NSString * const K_GRADIENT_KEY = @"gradient";

#ifdef DOUBLE_PIXELS
#define EXP(v) exp(v)
#else
#define EXP(v) expf(v)
#endif

static void std_Process_One_line( MyUnsharpMaskParameters *params, u_short y )
{
   const REAL unsharpOffset = (params->_gradientOnly?0.0:1.0) + params->_gain;
   const REAL ugY = params->_expY[y];
   LynkeosFourierBuffer * const spectrum = params->_spectrum;
   const u_short nPlanes = spectrum->_nPlanes;
   u_short x, c;

   for( x = 0; x < spectrum->_halfw; x++ )
   {
      /* Unsharp term = 1 + gain*(1 - gauss) */
      const REAL ug = unsharpOffset - ugY*params->_expX[x];

      for( c = 0; c < nPlanes; c++ )
         colorComplexValue(spectrum,x,y,c) *= ug;
   }
}

#if !defined(DOUBLE_PIXELS) || defined(__i386__)
static void vector_Process_One_line( MyUnsharpMaskParameters *params, u_short y )
{
   const REAL unsharpOffset = (params->_gradientOnly?0.0:1.0) + params->_gain;
   LynkeosFourierBuffer * const spectrum = params->_spectrum;
   const u_long nPlanes = spectrum->_nPlanes;
   u_long x, c;

#ifdef __ALTIVEC__
   // Altivec code
   const u_long byteLineWidth = spectrum->_halfw*sizeof(COMPLEX);
   const u_long bytePlaneSize = spectrum->_h*spectrum->_padw*sizeof(REAL); // padw is for REALs
   COMPLEX * const linePtr = &colorComplexValue(spectrum,0,y,0);
   REAL * const expXptr = params->_expX;
   const register __vector REAL Voffset = { unsharpOffset, unsharpOffset,
                                            unsharpOffset, unsharpOffset };
   const register __vector REAL Vuy = { -params->_expY[y], -params->_expY[y],
                                        -params->_expY[y], -params->_expY[y] };
   const register __vector REAL Vzero = { -0.0, -0.0, -0.0, -0.0 };
   register __vector REAL Vu;

   // Vector acts on 2 complex values at a time
   for( x = 0; x < byteLineWidth; x += 2*sizeof(COMPLEX) )
   {
      // Unsharp term = 1 + gain*(1 - gauss)
      Vu = vec_madd( vec_ld(x,expXptr), Vuy, Voffset );
	  // Apply it on each plane
      for( c = x; c < x+nPlanes*bytePlaneSize; c += bytePlaneSize )
         vec_st( vec_madd( vec_ld(c,(REAL*)linePtr), Vu, Vzero), c, (REAL*)linePtr );
   }

#else
#ifdef DOUBLE_PIXELS
   typedef REAL REALVECT __attribute__ ((vector_size (32)));
#else
   typedef REAL REALVECT __attribute__ ((vector_size (16)));
#endif
   const REALVECT vectOffset = { unsharpOffset, unsharpOffset,
                                 unsharpOffset, unsharpOffset };
   const REALVECT ugY = { params->_expY[y], params->_expY[y],
                          params->_expY[y], params->_expY[y] };

   // Vector acts on 2 complex values at a time
   for( x = 0; x < spectrum->_halfw; x += 2 )
   {
      const REALVECT ugX = *((REALVECT*)&params->_expX[2*x]);
      // Unsharp term = 1 + gain*(1 - gauss)
      const REALVECT ug = vectOffset - ugY*ugX;

      for( c = 0; c < nPlanes; c++ )
         *((REALVECT*)&colorComplexValue(spectrum,x,y,c)) *= ug;
   }
#endif
}
#endif

@implementation MyUnsharpMaskParameters
- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _gradientOnly = NO;
      _loopLock = [[NSLock alloc] init];
      _spectrum = nil;
      _livingThreadsNb = 0;
      _expX = NULL;
      _expY = NULL;
   }
   return( self );
}

- (void) dealloc
{
   [_loopLock release];
   if ( _spectrum != nil )
      [_spectrum release];
   if ( _expX != NULL )
      free( _expX );
   if ( _expY != NULL )
      free( _expY );
   [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [super encodeWithCoder:encoder];
   [encoder encodeDouble:_radius forKey:K_RADIUS_KEY];
   [encoder encodeDouble:_gain forKey:K_GAIN_KEY];
   [encoder encodeBool:_gradientOnly forKey:K_GRADIENT_KEY];
}

- (id) initWithCoder:(NSCoder *)decoder
{
   if ( (self = [super initWithCoder:decoder]) != nil )
   {
      _radius = [decoder decodeDoubleForKey:K_RADIUS_KEY];
      _gain = [decoder decodeDoubleForKey:K_GAIN_KEY];
      _gradientOnly = [decoder decodeBoolForKey:K_GRADIENT_KEY];
   }

   return( self );
}
@end

@implementation MyUnsharpMask
+ (ParallelOptimization_t) supportParallelization
{
   return( [[NSUserDefaults standardUserDefaults] integerForKey:
                                                  K_PREF_IMAGEPROC_MULTIPROC] );
}

- (id <LynkeosProcessing>) initWithDocument:(id <LynkeosDocument>)document
                                 parameters:(id <NSObject>)params
                                  precision:(floating_precision_t)precision
{
   if ( (self = [self init]) != nil )
   {
      _params = [params retain];
#if !defined(DOUBLE_PIXELS) || defined(__i386__)
      if ( hasSIMD )
         _process_One_Line = vector_Process_One_line;
      else
#endif
         _process_One_Line = std_Process_One_line;
   }

   return( self );
}

- (void) dealloc
{
   if ( _params != nil )
      [_params release];
   [super dealloc];
}

// Each CPU processes one line
- (void) processItem :(id <LynkeosProcessableItem>)item
{
   LynkeosIntegerRect r = {{0,0},[item imageSize]};
   const u_short h = r.size.height;
   const REAL h2 = (REAL)h*(REAL)h;
   const u_short w = r.size.width;
   const REAL w2 = (REAL)w*(REAL)w;
   const REAL gaussK = _params->_radius*_params->_radius*M_PI*M_PI/M_LN2;
   int x, y;

   _item = item;
   _lock = (void (*)(id, SEL))[_params->_loopLock methodForSelector:@selector(lock)];
   _unlock = (void (*)(id, SEL))[_params->_loopLock methodForSelector:@selector(unlock)];

   _lock(_params->_loopLock, @selector(lock) );
   if ( _params->_spectrum == nil )
   {
      // Get the Fourier transform
      [item getFourierTransform:&_params->_spectrum forRect:r
                 prepareInverse:YES];
      [_params->_spectrum retain];
      _params->_nextY = 0;

      // Prepare the X and Y terms of the unsharp Gauss
#if !defined(DOUBLE_PIXELS) || defined(__i386__)
      if ( hasSIMD )
      {
         _params->_expX =
                     (REAL*)malloc( 2*sizeof(REAL)*_params->_spectrum->_halfw );
         for( x = 0; x < _params->_spectrum->_halfw; x++ )
         {
            const REAL v = EXP( -(REAL)x*(REAL)x/w2*gaussK );
            _params->_expX[2*x] = v;
            _params->_expX[2*x+1] = v;
         }
      }
      else
#endif
      {
         _params->_expX =
                       (REAL*)malloc( sizeof(REAL)*_params->_spectrum->_halfw );
         for( x = 0; x < _params->_spectrum->_halfw; x++ )
            _params->_expX[x] = EXP( -(REAL)x*(REAL)x/w2*gaussK );
      }
      _params->_expY = (REAL*)malloc( sizeof(REAL)*h );
      for( y = 0; y < h; y++ )
      {
         const REAL y2 = ( y < r.size.height/2 ? (REAL)y*y : (h-y)*(h-y) );
         _params->_expY[y] = _params->_gain * EXP(-y2/h2*gaussK );
      }
   }
   y = _params->_nextY;
   _params->_nextY++;
   _params->_livingThreadsNb++;
   _unlock(_params->_loopLock, @selector(unlock));

   // Shortcut if gain makes nothing to process at all
   if ( _params->_gain > 0.0 && _params->_radius > 0.0 )
   {
      // Filter
      do
      {
         _process_One_Line( _params, y );

         _lock(_params->_loopLock, @selector(lock) );
         y = _params->_nextY;
         if ( y < h )
            _params->_nextY++;
         _unlock(_params->_loopLock, @selector(unlock));
      } while( y < h );
   }
}

- (void) finishProcessing
{
   _lock(_params->_loopLock, @selector(lock) );
   _params->_livingThreadsNb--;
   if ( _params->_livingThreadsNb == 0 )
   {
      // We were the last thread, finish the job
      // Save the result
      [_item setFourierTransform:_params->_spectrum];
      // Release resources
      [_params->_spectrum release];
      _params->_spectrum = nil;
      free( _params->_expX );
      _params->_expX = NULL;
      free( _params->_expY );
      _params->_expY = NULL;
   }
   _unlock(_params->_loopLock, @selector(unlock));
}
@end
