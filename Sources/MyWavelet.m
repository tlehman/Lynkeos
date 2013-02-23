//
//  Lynkeos
//  $Id: MyWavelet.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Thu Dec 6 2007.
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

#include <math.h>

#include "processing_core.h"
#include "LynkeosFourierBuffer.h"
#include "LynkeosStandardImageBufferAdditions.h"
#include "MyGeneralPrefs.h"
#include "LynkeosThreadConnection.h"
#include "MyWavelet.h"

static NSString * const K_WAVELET_KIND_KEY = @"waveletKind";
static NSString * const K_WAVELETS_KEY = @"wavelets";

static const double K_Cutoff = M_LN2;

#ifdef DOUBLE_PIXELS
#define EXP(v) exp(v)
#else
#define EXP(v) expf(v)
#endif

/*!
 * @abstract Frequency sawtooth algorithm
 */
static void std_frequency_sawtooth_process_line(
                                            const MyWaveletParameters *params,
                                            u_short y )
{
   LynkeosFourierBuffer * const spectrum = params->_spectrum;
   const u_short nPlanes = spectrum->_nPlanes;
   const u_short waveletsNb = params->_numberOfWavelets;
   wavelet_t * const wavelet = params->_wavelet;
   REAL h2, w, freq, gain;
   u_long x, c, i = 0;

   // Precompute the vertical frequency square
   if ( y < spectrum->_h/2 )
      h2 = y;
   else
      h2 = spectrum->_h - y;
   h2 /= (REAL)spectrum->_h;
   h2 *= h2;

   for( x = 0; x < spectrum->_halfw; x++ )
   {
      // Interpolate the weight
      w = (REAL)x/(REAL)spectrum->_w;
      freq = sqrt( w*w + h2 );

      // The frequency increases with x, the wavelet shall always be the same
      // or a higher one
      if ( i > 0 && freq <= (REAL)wavelet[i-1]._frequency )
      {
         NSLog( @"Inconsistent frequency %f during wavelet processing", freq );
         return;
      }

      for ( ; i < waveletsNb && (REAL)wavelet[i]._frequency < freq; i++ )
         ;

      if ( i == 0 )
      {
         if ( freq != 0.0 )
            NSLog( @"Invalid wavelet 0{freq=%f} selection at freq=%f",
                   wavelet[0]._frequency, freq );
         gain = (REAL)wavelet[0]._weight;
      }
      else if ( i == waveletsNb )
      {
         if ( freq > M_SQRT1_2 )
            NSLog( @"Invalid frequency %f", freq );
         gain = (REAL)wavelet[i-1]._weight * (M_SQRT1_2 - freq)
                / (M_SQRT1_2 - (REAL)wavelet[i-1]._frequency);
      }
      else
         gain =   ((REAL)wavelet[i]._weight - (REAL)wavelet[i-1]._weight)
                  / ((REAL)wavelet[i]._frequency - (REAL)wavelet[i-1]._frequency)
                  * (freq - (REAL)wavelet[i-1]._frequency)
                  + (REAL)wavelet[i-1]._weight;

      for( c = 0; c < nPlanes; c++ )
         colorComplexValue(spectrum,x,y,c) *= gain;
   }
}

#if 0  /* To be developed later */
//#if defined(__i386__) || ! defined(DOUBLE_PIXELS)
void vect_frequency_sawtooth_process_line( const MyWaveletParameters *params,
                                           u_short y )
{
   typedef
#ifdef __ALTIVEC__
   __vector REAL
#else
#ifdef DOUBLE_PIXELS
   REAL __attribute__ ((vector_size (32)))
#else
   REAL __attribute__ ((vector_size (16)))
#endif
#endif
   REALVECT;
   typedef union
   {
      REALVECT val;
      struct
      {
         REAL a, b, c, d;
      } vect;
   } REALVECTU;

   MyFourierBuffer * const spectrum = params->_spectrum;
   const u_short nPlanes = spectrum->_nPlanes;
   const u_short waveletsNb = params->_numberOfWavelets;
   wavelet_t * const wavelet = params->_wavelet;
   REAL y2;
   u_long x, c, i = 0;
   REALVECTU Vfm = {.val={0.0, 0.0, 0.0, 0.0}}, Vpm = {.val={0.0, 0.0, 0.0, 0.0}};
   REALVECTU Vfp = {.vect={wavelet[0]._frequency, wavelet[0]._frequency,
                           wavelet[0]._frequency, wavelet[0]._frequency}};
   REALVECTU Vpp = {.vect={wavelet[0]._weight, wavelet[0]._weight,
                           wavelet[0]._weight, wavelet[0]._weight}};
   REALVECT Vx = {0.0, 0.0, 1.0/(REAL)spectrum->_w, 1.0/(REAL)spectrum->_w};
   const REALVECT V2 = {2.0, 2.0, 2.0, 2.0};
   const REALVECT Vinc = {2.0/(REAL)spectrum->_w,2.0/(REAL)spectrum->_w,
                          2.0/(REAL)spectrum->_w,2.0/(REAL)spectrum->_w};

   // Precompute the vertical frequency square
   if ( y < spectrum->_h/2 )
      y2 = (REAL)y;
   else
      y2 = (REAL)(spectrum->_h - y);
   y2 /= (REAL)spectrum->_h;
   y2 *= y2;
   const REALVECT Vy2 = { y2, y2, y2, y2 };

   for( x = 0; x < spectrum->_halfw; x += 2 )
   {
      // Interpolate the weight
      REALVECTU Vf;
#ifdef __ALTIVEC__
      vec_madd( Vx, Vx, Vy2 );
#else
      Vf.val = Vx*Vx + Vy2;
#endif
      Vf.vect.a = sqrt(Vf.vect.a);
      Vf.vect.b = Vf.vect.a;
      Vf.vect.c = sqrt(Vf.vect.c);
      Vf.vect.d = Vf.vect.c;

      BOOL found;
      for( found = NO; found && i <= waveletsNb; i++ )
      {
         REAL f, w;
         found = YES;

         if ( i < waveletsNb )
         {
            f = wavelet[i]._frequency;
            w = wavelet[i]._weight;
         }
         else
         {
            f = M_SQRT1_2;
            w = 0.0;
         }

         if ( f >= Vf.vect.a )
         {
            if ( Vfp.vect.a < Vf.vect.a )
            {
               Vfm.vect.a = Vfp.vect.a;
               Vfm.vect.b = Vfp.vect.a;
               Vfp.vect.a = f;
               Vfp.vect.b = f;
               Vpm.vect.a = Vpp.vect.a;
               Vpm.vect.b = Vpp.vect.a;
               Vpp.vect.a = w;
               Vpp.vect.b = w;
            }
         }
         else
            found = NO;
         if ( f >= Vf.vect.c )
         {
            if ( Vfp.vect.c < Vf.vect.c )
            {
               Vfm.vect.c = Vfp.vect.c;
               Vfm.vect.d = Vfp.vect.c;
               Vfp.vect.c = f;
               Vfp.vect.d = f;
               Vpm.vect.c = Vpp.vect.c;
               Vpm.vect.d = Vpp.vect.c;
               Vpp.vect.c = w;
               Vpp.vect.d = w;
            }
         }
         else
            found = NO;
      }

      REALVECTU Vdiff;
      Vdiff.val = Vfp.val - Vfm.val;

      if ( Vdiff.vect.a == 0.0 )
      {
         Vdiff.vect.a = 1.0;
         Vdiff.vect.b = 1.0;
      }
      else
      {
         Vdiff.vect.a = 1.0/Vdiff.vect.a;
         Vdiff.vect.b = Vdiff.vect.a;
      }
      if ( Vdiff.vect.c == 0.0 )
      {
         Vdiff.vect.c = 1.0;
         Vdiff.vect.d = 1.0;
      }
      else
      {
         Vdiff.vect.c = 1.0/Vdiff.vect.c;
         Vdiff.vect.d = Vdiff.vect.c;
      }

      REALVECTU Vg;
      Vg.val = (Vpp.val*(Vf.val-Vfm.val)-V2*Vpm.val*Vf.val)*Vdiff.val;
      for( c = 0; c < nPlanes; c++ )
         *((REALVECT*)&colorComplexValue(spectrum,x,y,c)) *= Vg.val;

      Vx += Vinc;
   }
}
#endif

static void std_ESO_process_line( const MyWaveletParameters *params, u_short y )
{
   LynkeosFourierBuffer * const spectrum = params->_spectrum;
   const u_short nPlanes = spectrum->_nPlanes;
   const u_short waveletsNb = params->_numberOfWavelets;
   wavelet_t * const wavelet = params->_wavelet;
   REAL h2, w, freq, gain;
   u_long x, c;

   // Precompute the vertical frequency square
   if ( y < spectrum->_h/2 )
      h2 = y;
   else
      h2 = spectrum->_h - y;
   h2 /= (REAL)spectrum->_h;
   h2 *= h2;

   for( x = 0; x < spectrum->_halfw; x++ )
   {
      // Interpolate the weight
      w = (REAL)x/(REAL)spectrum->_w;
      freq = sqrt( w*w + h2 );

      gain = (REAL)wavelet[0]._weight;

      if ( waveletsNb > 1 )
      {
         u_short n;

         gain += (REAL)wavelet[waveletsNb-1]._weight
                 - EXP( -freq*freq*K_Cutoff
                        /(REAL)wavelet[1]._frequency/(REAL)wavelet[1]._frequency )
                 *(REAL)wavelet[1]._weight;

         for( n = 2; n < waveletsNb; n++ )
            gain += EXP( -freq*freq*K_Cutoff
                         /(REAL)wavelet[n]._frequency/(REAL)wavelet[n]._frequency )
                    *((REAL)wavelet[n-1]._weight - (REAL)wavelet[n]._weight);

         for( c = 0; c < nPlanes; c++ )
            colorComplexValue(spectrum,x,y,c) *= gain;
      }
   }
}

@implementation MyWaveletParameters
- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _waveletKind = FrequencySawtooth_Wavelet;
      _numberOfWavelets = 0;
      _wavelet = NULL;

      _loopLock = [[NSLock alloc] init];
      _spectrum = nil;
      _livingThreadsNb = 0;
   }

   return( self );
}

- (void) dealloc
{
   if ( _wavelet != NULL )
      free( _wavelet );
   [_loopLock release];
   if ( _spectrum != nil )
      [_spectrum release];
   [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [super encodeWithCoder:encoder];

   [encoder encodeInt:_waveletKind forKey:K_WAVELET_KIND_KEY];

   // Create an array of NSNumbers to save the wavelets characteritics
   NSMutableArray *wArray =
      [NSMutableArray arrayWithCapacity:_numberOfWavelets*2];
   int i;
   for( i = 0; i < _numberOfWavelets; i++ )
   {
      [wArray addObject:[NSNumber numberWithDouble:_wavelet[i]._frequency]];
      [wArray addObject:[NSNumber numberWithDouble:_wavelet[i]._weight]]; 
   }
   [encoder encodeObject:wArray forKey:K_WAVELETS_KEY];
}

- (id) initWithCoder:(NSCoder *)decoder
{
   if ( (self = [super initWithCoder:decoder]) != nil )
   {
      _waveletKind = [decoder decodeIntForKey:K_WAVELET_KIND_KEY];
      NSArray *wArray = [decoder decodeObjectForKey:K_WAVELETS_KEY];
      _numberOfWavelets = [wArray count]/2;
      _wavelet = (wavelet_t*)malloc( _numberOfWavelets*sizeof(wavelet_t) );
      int i;
      for( i = 0; i < _numberOfWavelets; i++ )
      {
         _wavelet[i]._frequency = [[wArray objectAtIndex:2*i] doubleValue];
         _wavelet[i]._weight = [[wArray objectAtIndex:2*i+1] doubleValue];
      }
   }
   return( self );
}
@end

@implementation MyWavelet

+ (ParallelOptimization_t) supportParallelization
{
   return([[NSUserDefaults standardUserDefaults] integerForKey:
                                                   K_PREF_IMAGEPROC_MULTIPROC]);
}

- (id <LynkeosProcessing>) initWithDocument:(id <LynkeosDocument>)document
                                 parameters:(id <NSObject>)params
                                  precision:(floating_precision_t)precision
{
   if ( (self = [self init]) != nil )
   {
      _params = [params retain];
      switch( _params->_waveletKind )
      {
         case FrequencySawtooth_Wavelet:
#if 0
//#if !defined(DOUBLE_PIXELS) || defined(__i386__)
            if ( hasSIMD )
               _process_One_Line = vect_frequency_sawtooth_process_line;
            else
#endif
               _process_One_Line = std_frequency_sawtooth_process_line;
            break;
         case ESO_Wavelet:
            _process_One_Line = std_ESO_process_line;
            break;
      }
   }

   return( self );
}

- (void) dealloc
{
   if ( _params != nil )
      [_params release];
   [super dealloc];
}

- (void) processItem:(id <LynkeosProcessableItem>)item
{
   const LynkeosIntegerRect r = {{0,0},[item imageSize]};
   int y;

   _item = item;

   // Get the Fourier transform
   [_params->_loopLock lock];
   if ( _params->_spectrum == nil )
   {
      // Get the Fourier transform
      [item getFourierTransform:&_params->_spectrum forRect:r
                 prepareInverse:YES];
      [_params->_spectrum retain];
      _params->_nextY = 0;
   }
   y = _params->_nextY;
   _params->_nextY++;
   _params->_livingThreadsNb++;
   [_params->_loopLock unlock];

   // Filter
   do
   {
      _process_One_Line( _params, y );

      [_params->_loopLock lock];
      y = _params->_nextY;
      if ( y < r.size.height )
         _params->_nextY++;
      [_params->_loopLock unlock];
   } while( y < r.size.height );
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
   }
   [_params->_loopLock unlock];
}
@end
