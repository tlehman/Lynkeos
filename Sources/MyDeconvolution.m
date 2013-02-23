//
//  Lynkeos
//  $Id: MyDeconvolution.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sat Sept 29 2007.
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
#include "LynkeosThreadConnection.h"

#include "MyDeconvolution.h"

static NSString * const K_RADIUS_KEY = @"radius";
static NSString * const K_THRESHOLD_KEY = @"threshold";

#ifdef DOUBLE_PIXELS
#define EXP(v) exp(v)
#else
#define EXP(v) expf(v)
#endif

static void std_Process_One_line( MyDeconvolutionParameters *params, u_short y )
{
   const REAL threshold = 1.0/params->_threshold;
   const REAL dgY = params->_expY[y];
   LynkeosFourierBuffer * const spectrum = params->_spectrum;
   const u_short nPlanes = spectrum->_nPlanes;
   u_short x, c;

   for( x = 0; x < spectrum->_halfw; x++ )
   {
      // Deconvolution term = source/gauss when gauss > threshold
      REAL dg = dgY*params->_expX[x];
      if ( dg > threshold )
         dg = threshold;

      for( c = 0; c < nPlanes; c++ )
         colorComplexValue(spectrum,x,y,c) *= dg;
   }
}

#if !defined(DOUBLE_PIXELS) || defined(__i386__)
static void vector_Process_One_line( MyDeconvolutionParameters *params, u_short y )
{
   const REAL threshold = 1.0/params->_threshold;
   LynkeosFourierBuffer * const spectrum = params->_spectrum;
   const u_long nPlanes = spectrum->_nPlanes;
   u_long x, c;

#ifdef __ALTIVEC__
   // Altivec code
   static const __vector REAL Vzero = { -0.0, -0.0, -0.0, -0.0 };
   static const __vector u_long Vperma = { 0x00010203, 0x00010203,
                                           0x04050607, 0x04050607 };
   static const __vector u_long Vpermb = { 0x08090A0B, 0x08090A0B,
                                           0x0C0D0E0F, 0x0C0D0E0F };
   const u_long byteLineWidth = spectrum->_halfw*sizeof(COMPLEX);
   const u_long bytePlaneSize = spectrum->_h*spectrum->_padw*sizeof(REAL); // padw is for REALs
   COMPLEX * const linePtr = &colorComplexValue(spectrum,0,y,0);
   REAL * expXptr = params->_expX;
   const __vector REAL Vthr = { threshold, threshold, threshold, threshold };
   const register __vector REAL Vdy = { params->_expY[y], params->_expY[y],
                                        params->_expY[y], params->_expY[y] };
   register __vector REAL Vdx, Vda, Vdb;

   // 2 Vectors acts on 4 complex values at a time
   for( x = 0; x < byteLineWidth; x += 4*sizeof(COMPLEX), expXptr += 4 )
   {
      // Deconvolution term = source/gauss when gauss > threshold
      Vdx = vec_madd( vec_ld(0,expXptr), Vdy, Vzero );
      const __vector __bool int Vmask = vec_cmplt(Vdx,Vthr);
      __vector REAL Vge = vec_and(Vdx,Vmask);
      __vector REAL Vlt = vec_andc(Vthr,Vmask);
      Vdx = vec_or(Vge,Vlt);
      Vda = vec_perm(Vdx,Vzero,Vperma);

      // Apply it on each plane
      if ( x < byteLineWidth-2*sizeof(COMPLEX) )
      {
         Vdb = vec_perm(Vdx,Vzero,Vpermb);
         for( c = x; c < x+nPlanes*bytePlaneSize; c += bytePlaneSize )
         {
            __vector REAL Vbuf = vec_ld(c,(REAL*)linePtr);
            Vbuf = vec_madd( Vbuf, Vda, Vzero);
            vec_st( Vbuf,c, (REAL*)linePtr );
            Vbuf = vec_ld(c+2*sizeof(COMPLEX),(REAL*)linePtr);
            Vbuf = vec_madd( Vbuf, Vdb, Vzero);
            vec_st( Vbuf,c+2*sizeof(COMPLEX), (REAL*)linePtr );
         }
      }
      else
      {
         for( c = x; c < x+nPlanes*bytePlaneSize; c += bytePlaneSize )
            vec_st( vec_madd( vec_ld(c,(REAL*)linePtr), Vda, Vzero),
                    c, (REAL*)linePtr );
      }

   }

#else
#ifdef DOUBLE_PIXELS
   typedef REAL REALVECT __attribute__ ((vector_size (32)));
#else
   typedef REAL REALVECT __attribute__ ((vector_size (16)));
#endif
   const REAL dgY = params->_expY[y];

   // Vector acts on 2 complex values at a time
   for( x = 0; x < spectrum->_halfw; x += 2 )
   {
      // Deconvolution term = source/gauss when gauss > threshold
      REAL dga, dgb;

      dga = params->_expX[x]*dgY;
      if ( dga > threshold )
         dga = threshold;
      dgb = params->_expX[x+1]*dgY;
      if ( dgb > threshold )
         dgb = threshold;

      REALVECT Vdg = { dga, dga, dgb, dgb };

      for( c = 0; c < nPlanes; c++ )
         *((REALVECT*)&colorComplexValue(spectrum,x,y,c)) *= Vdg;
   }
#endif
}
#endif

@implementation MyDeconvolutionParameters
- (id) init
{
   if ( (self = [super init]) != nil )
   {
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
   [encoder encodeDouble:_threshold forKey:K_THRESHOLD_KEY];
}

- (id) initWithCoder:(NSCoder *)decoder
{
   if ( (self = [super initWithCoder:decoder]) != nil )
   {
      _radius = [decoder decodeDoubleForKey:K_RADIUS_KEY];
      _threshold = [decoder decodeDoubleForKey:K_THRESHOLD_KEY];
   }

   return( self );
}
@end

@implementation MyDeconvolution

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
- (void) processItem:(id <LynkeosProcessableItem>)item
{
   const REAL gaussK = _params->_radius*_params->_radius*M_PI*M_PI/M_LN2;
   const LynkeosIntegerRect r = {{0,0},[item imageSize]};
   const REAL w2 = (REAL)r.size.width*(REAL)r.size.width;
   const REAL h2 = (REAL)r.size.height*(REAL)r.size.height;
   int x, y;

   _item = item;

   [_params->_loopLock lock];
   if ( _params->_spectrum == nil )
   {
      // Get the Fourier transform
      [item getFourierTransform:&_params->_spectrum forRect:r
                 prepareInverse:YES];
      [_params->_spectrum retain];
      _params->_nextY = 0;

      // Prepare the X and Y terms of the deconvolution Gauss
      _params->_expX = (REAL*)malloc( sizeof(REAL)*_params->_spectrum->_halfw );
      for( x = 0; x < _params->_spectrum->_halfw; x++ )
      {
         REAL g = EXP( -(REAL)x*(REAL)x/w2*gaussK );
         if ( g > 0.0 )
            _params->_expX[x] = 1.0/g;
         else
            _params->_expX[x] = HUGE;
      }
      _params->_expY = (REAL*)malloc( sizeof(REAL)*r.size.height );
      for( y = 0; y < r.size.height; y++ )
      {
         const REAL y2 = ( y < r.size.height/2 ? (REAL)y*y
                            : (REAL)(r.size.height-y)*(REAL)(r.size.height-y) );
         const REAL g = EXP(-y2/h2*gaussK );
         if ( g > 0.0 )
            _params->_expY[y] = 1.0/g;
         else
            _params->_expY[y] = HUGE;
      }
   }
   y = _params->_nextY;
   _params->_nextY++;
   _params->_livingThreadsNb++;
   [_params->_loopLock unlock];

   // Shortcut if threshold makes nothing to process at all
   if ( _params->_threshold < 1.0 && _params->_radius > 0.0 )
   {
      // Filter
      const REAL h = r.size.height;
      do
      {
         _process_One_Line( _params, y );

         [_params->_loopLock lock];
         y = _params->_nextY;
         if ( y < h )
            _params->_nextY++;
         [_params->_loopLock unlock];
      } while( y < h );
   }
}

- (void) finishProcessing
{
   [_params->_loopLock lock];
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
   [_params->_loopLock unlock];
}
@end
