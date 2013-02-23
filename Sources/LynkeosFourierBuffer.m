//
//  Lynkeos
//  $Id: LynkeosFourierBuffer.m 501 2010-12-30 17:21:17Z j-etienne $
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

#ifdef GNUSTEP
#include <sys/sysinfo.h>
#else
#include <sys/sysctl.h>
#include <CoreServices/CoreServices.h>
#endif
#include <pthread.h>

#include "processing_core.h"
#include "LynkeosFourierBuffer.h"
#include "LynkeosStandardImageBufferAdditions.h"

#ifndef DOUBLE_PIXELS
#define FFTW_INIT_THREADS fftwf_init_threads    //!< Initialize the FFTW threads
#define FFT_MALLOC fftwf_malloc                 //!< Allocate aligned on SIMD
//! Prepare N threads for FFTW
#define FFTW_PLAN_WITH_NTHREADS fftwf_plan_with_nthreads 
#define FFT_PLAN_R2C fftwf_plan_many_dft_r2c    //!< Plan a direct transform
#define FFT_PLAN_C2R fftwf_plan_many_dft_c2r    //!< Plan an inverse transform
#define FFT_EXECUTE fftwf_execute               //!< Execute a planned transform
#define FFT_FREE fftwf_free                     //!< Deallocate the buffer
#define FFT_DESTROY_PLAN fftwf_destroy_plan     //!< Deallocate a plan
#else
#define FFTW_INIT_THREADS fftw_init_threads
#define FFT_MALLOC fftw_malloc
#define FFTW_PLAN_WITH_NTHREADS fftw_plan_with_nthreads
#define FFT_PLAN_R2C fftw_plan_many_dft_r2c
#define FFT_PLAN_C2R fftw_plan_many_dft_c2r
#define FFT_EXECUTE fftw_execute
#define FFT_FREE fftw_free
#define FFT_DESTROY_PLAN fftw_destroy_plan
#endif

u_char hasSIMD;
u_short numberOfCpus;

static unsigned fftwDefaultFlag;
// Mutex used to protect every call to FFTW except fftw_execute
static pthread_mutex_t fftwLock;

/*!
* To initialize the processing, we need to check if the processor 
 * support Altivec instructions and configure FFTW3 calls accordingly ; and 
 * then to retrieve the number of processors.
 */
void initializeProcessing(void)
{
   // First evaluate if the CPU has Altivec capacity
#ifdef GNUSTEP
   int hasVectorUnit = 1;  // No single binary for vector/non vector on this arch
   int error = 0;
#else
   int selectors[2] = { CTL_HW, HW_VECTORUNIT };
   int hasVectorUnit = 0;
   size_t length = sizeof(hasVectorUnit);
   int error = sysctl(selectors, 2, &hasVectorUnit, &length, NULL, 0);
#endif

   if ( error == 0 && hasVectorUnit )
      fftwDefaultFlag = 0;
   else
      fftwDefaultFlag = FFTW_NO_SIMD;
   hasSIMD = ((fftwDefaultFlag & FFTW_NO_SIMD) == 0);

   // Then read the number of CPUs we are running on
#ifdef GNUSTEP
   numberOfCpus = get_nprocs();
   if ( numberOfCpus == 0 )
      numberOfCpus = 1;
#else
   if ( MPLibraryIsLoaded() )
      numberOfCpus = MPProcessors();
   else
      numberOfCpus = 1;
#endif

   // Create a lock for FFTW non thread safe functions
   pthread_mutex_init( &fftwLock, NULL );

   // Prepare FFTW to work with threads
   FFTW_INIT_THREADS();
}

/*!
 * @abstract Multiply method for strategy "without vectors"
 */
static void std_spectrum_mul_one_line(LynkeosFourierBuffer *a,
                                   ArithmeticOperand_t op,
                                   LynkeosFourierBuffer *res,
                                   u_short y )
{
   LynkeosFourierBuffer *b = (LynkeosFourierBuffer*)op.term;
   u_short x, c, ct;

   for( x = 0; x < a->_halfw; x++ )
      for( c = 0; c < a->_nPlanes; c++ )
      {
         if ( b->_nPlanes == 1 )
            ct = 0;
         else
            ct = c;
         COMPLEX r = colorComplexValue(a,x,y,c)
                     * colorComplexValue(b,x,y,ct);
         colorComplexValue(res,x,y,c) = r;
      }
}

#if !defined(DOUBLE_PIXELS) || defined(__i386__)
static void vect_spectrum_mul_one_line(LynkeosFourierBuffer *a,
                                       ArithmeticOperand_t op,
                                       LynkeosFourierBuffer *res,
                                       u_short y )
{
   LynkeosFourierBuffer *b = (LynkeosFourierBuffer*)op.term;
   u_short x, c, ct;

   for( x = 0; x < a->_halfw; x+=2 )
      for( c = 0; c < a->_nPlanes; c++ )
      {
         if ( b->_nPlanes == 1 )
            ct = 0;
         else
            ct = c;
#ifdef __ALTIVEC__
         static const REALVECT Vzero = { -0.0, -0.0, -0.0, -0.0 };
         static const REALVECT Vsign = { -1.0, 1.0, -1.0, 1.0 };
         static const __vector u_long Vcross =
                             { 0x04050607, 0x00010203, 0x0C0D0E0F, 0x08090A0B };
         static const __vector u_long Vperm1 =
                             { 0x00010203, 0x10111213, 0x08090A0B, 0x18191A1B };
         static const __vector u_long Vperm2 =
                             { 0x04050607, 0x14151617, 0x0C0D0E0F, 0x1C1D1E1F };
         const REALVECT t1 = *((REALVECT*)&colorComplexValue(a,x,y,c));
         const REALVECT t2 = *((REALVECT*)&colorComplexValue(b,x,y,ct));
         const REALVECT t2p = vec_perm(t2,t2,Vcross);
         REALVECT r1, r2;
         r1 = vec_madd(t1,t2,Vzero);   // Direct product
         r2 = vec_madd(t1,t2p,Vzero);  // Cross product
         *((REALVECT*)&colorComplexValue(res,x,y,c)) =
                  vec_madd(vec_perm(r1,r2,Vperm2),Vsign,vec_perm(r1,r2,Vperm1));
#else
         union { REALVECT val; REAL vct[4]; } t1, t2, r1, r;
         t1.val = *((REALVECT*)&colorComplexValue(a,x,y,c));
         t2.val = *((REALVECT*)&colorComplexValue(b,x,y,ct));
         r1.val = t1.val * t2.val;  // Direct product
         r.vct[0] = r1.vct[0] - r1.vct[1];                     // 1st cplx real
         r.vct[1] = t1.vct[0]*t2.vct[1] + t1.vct[1]*t2.vct[0]; // 1st cplx imag
         r.vct[2] = r1.vct[2] - r1.vct[3];                     // 2nd cplx real
         r.vct[3] = t1.vct[2]*t2.vct[3] + t1.vct[3]*t2.vct[2]; // 1st cplx imag
         *((REALVECT*)&colorComplexValue(res,x,y,c)) = r.val;
#endif
      }
}
#endif

/*!
 * @abstract "Multiply with conjugate" method for strategy "without vectors"
 */
static void std_spectrum_mul_conjugate_one_line(LynkeosFourierBuffer *a,
                                      ArithmeticOperand_t op,
                                      LynkeosFourierBuffer *res,
                                      u_short y )
{
   LynkeosFourierBuffer *b = (LynkeosFourierBuffer*)op.term;
   u_short x, c, ct;

   for( x = 0; x < a->_halfw; x++ )
      for( c = 0; c < a->_nPlanes; c++ )
      {
         if ( b->_nPlanes == 1 )
            ct = 0;
         else
            ct = c;
         COMPLEX t1 = colorComplexValue(a,x,y,c),
                 t2 = colorComplexValue(b,x,y,ct);
         COMPLEX r;
         __real__ r = (__real__ t1 * __real__ t2) + (__imag__ t1 * __imag__ t2);
         __imag__ r = (__real__ t2 * __imag__ t1) - (__real__ t1 * __imag__ t2);
         colorComplexValue(res,x,y,c) = r;
      }
}

#if !defined(DOUBLE_PIXELS) || defined(__i386__)
/*!
 * @abstract "Multiply with conjugate" method for strategy "with vectors"
 */
static void vect_spectrum_mul_conjugate_one_line(LynkeosFourierBuffer *a,
                                                ArithmeticOperand_t op,
                                                LynkeosFourierBuffer *res,
                                                u_short y )
{
   LynkeosFourierBuffer *b = (LynkeosFourierBuffer*)op.term;
   u_short x, c, ct;

   for( x = 0; x < a->_halfw; x+=2 )
      for( c = 0; c < a->_nPlanes; c++ )
      {
         if ( b->_nPlanes == 1 )
            ct = 0;
         else
            ct = c;
#ifdef __ALTIVEC__
         static const REALVECT Vzero = { -0.0, -0.0, -0.0, -0.0 };
         static const REALVECT Vsign = { 1.0, -1.0, 1.0, -1.0 };
         static const __vector u_long Vcross =
                             { 0x04050607, 0x00010203, 0x0C0D0E0F, 0x08090A0B };
         static const __vector u_long Vperm1 =
                             { 0x00010203, 0x10111213, 0x08090A0B, 0x18191A1B };
         static const __vector u_long Vperm2 =
                             { 0x04050607, 0x14151617, 0x0C0D0E0F, 0x1C1D1E1F };
         const REALVECT t1 = *((REALVECT*)&colorComplexValue(a,x,y,c));
         const REALVECT t2 = *((REALVECT*)&colorComplexValue(b,x,y,ct));
         const REALVECT t2p = vec_perm(t2,t2,Vcross);
         REALVECT r1, r2;
         r1 = vec_madd(t1,t2,Vzero);   // Direct product
         r2 = vec_madd(t1,t2p,Vzero);  // Cross product
         *((REALVECT*)&colorComplexValue(res,x,y,c)) =
                  vec_madd(vec_perm(r1,r2,Vperm1),Vsign,vec_perm(r1,r2,Vperm2));
#else
         union { REALVECT val; REAL vect[4]; } t1, t2, r1, r;
         t1.val = *((REALVECT*)&colorComplexValue(a,x,y,c));
         t2.val = *((REALVECT*)&colorComplexValue(b,x,y,ct));
         r1.val = t1.val * t2.val; // Direct product
         r.vect[0] = r1.vect[0] + r1.vect[1];
         r.vect[1] = t2.vect[0] * t1.vect[1] - t1.vect[0] * t2.vect[1];
         r.vect[2] = r1.vect[2] + r1.vect[3];
         r.vect[3] = t2.vect[2] * t1.vect[3] - t1.vect[2] * t2.vect[3];
         *((REALVECT*)&colorComplexValue(res,x,y,c)) = r.val;
#endif
      }
}
#endif

/*!
 * @abstract Scaling method for strategy "without vectors"
 */
static void std_spectrum_scale_one_line(LynkeosFourierBuffer *a,
                                      ArithmeticOperand_t op,
                                      LynkeosFourierBuffer *res,
                                      u_short y )
{
   REAL scalar = 
#ifdef DOUBLE_PIXELS
      op.dscalar
#else
      op.fscalar
#endif
      ;
   u_short x, c;

   for( x = 0; x < a->_halfw; x++ )
      for( c = 0; c < a->_nPlanes; c++ )
      {
         COMPLEX r = colorComplexValue(a,x,y,c) * scalar;
         colorComplexValue(res,x,y,c) = r;
      }
}

#if !defined(DOUBLE_PIXELS) || defined(__i386__)
/*!
 * @abstract Scaling method for strategy "with vectors"
 */
static void vect_spectrum_scale_one_line(LynkeosFourierBuffer *a,
                                        ArithmeticOperand_t op,
                                        LynkeosFourierBuffer *res,
                                        u_short y )
{
   const REAL scalar = 
#ifdef DOUBLE_PIXELS
      op.dscalar
#else
      op.fscalar
#endif
      ;
   const REALVECT Vscale = { scalar, scalar, scalar, scalar };
   u_short x, c;

   for( x = 0; x < a->_halfw; x+=2 )
      for( c = 0; c < a->_nPlanes; c++ )
      {
         REALVECT r = *((REALVECT*)&colorComplexValue(a,x,y,c)) * Vscale;
         *((REALVECT*)&colorComplexValue(res,x,y,c)) = r;
      }
}
#endif

/*!
 * @abstract Divide method for strategy "without vectors"
 */
static void std_spectrum_div_one_line(LynkeosFourierBuffer *a,
                                      ArithmeticOperand_t op,
                                      LynkeosFourierBuffer *res,
                                      u_short y )
{
   LynkeosFourierBuffer *b = (LynkeosFourierBuffer*)op.term;
   u_short x, c, ct;

   for( x = 0; x < a->_halfw; x++ )
      for( c = 0; c < a->_nPlanes; c++ )
      {
         if ( b->_nPlanes == 1 )
            ct = 0;
         else
            ct = c;
         COMPLEX n = colorComplexValue(a,x,y,c),
                 d = colorComplexValue(b,x,y,ct), r;
         if ( d != 0.0 )
            r = n / d;
         else
            r = 0.0; // Arbitrary value to avoid NaN
         colorComplexValue(res,x,y,c) = r;
      }
}

#if !defined(DOUBLE_PIXELS) || defined(__i386__)
/*!
 * @abstract Divide method for strategy "with vectors"
 */
static void vect_spectrum_div_one_line(LynkeosFourierBuffer *a,
                                       ArithmeticOperand_t op,
                                       LynkeosFourierBuffer *res,
                                       u_short y )
{
   LynkeosFourierBuffer *b = (LynkeosFourierBuffer*)op.term;
   u_short x, c, ct;

   for( x = 0; x < a->_halfw; x+=2 )
      for( c = 0; c < a->_nPlanes; c++ )
      {
         if ( b->_nPlanes == 1 )
            ct = 0;
         else
            ct = c;

         // (a+ib)/(c+id) = (ac+bd+i(bc-ad))/(c2+d2)
#ifdef __ALTIVEC__
         static const REALVECT Vzero = { -0.0, -0.0, -0.0, -0.0 };
         static const REALVECT Vsign = { 1.0, -1.0, 1.0, -1.0 };
         static const __vector u_long Vcross =
                             { 0x04050607, 0x00010203, 0x0C0D0E0F, 0x08090A0B };
         static const __vector u_long Vperm1 =
                             { 0x00010203, 0x10111213, 0x08090A0B, 0x18191A1B };
         static const __vector u_long Vperm2 =
                             { 0x04050607, 0x14151617, 0x0C0D0E0F, 0x1C1D1E1F };
         const REALVECT n = *((REALVECT*)&colorComplexValue(a,x,y,c));
         const REALVECT d = *((REALVECT*)&colorComplexValue(b,x,y,ct));
         REALVECT r1, r2, r;
         union { REALVECT val; REAL vect[4]; } m;
         REAL m1, m2;
         r1 = vec_madd(n,d,Vzero);   // Direct product
         r2 = vec_madd(n,vec_perm(d,d,Vcross),Vzero);  // Cross product
         r = vec_madd(vec_perm(r1,r2,Vperm1),Vsign,vec_perm(r1,r2,Vperm2));
         m.val = vec_madd(d,d,Vzero);
         m.val = vec_add(m.val,vec_perm(m.val,Vzero,Vcross)); // module
         m1 = (m.vect[0] > 0.0 ? 1.0/m.vect[0] : 0.0);
         m2 = (m.vect[2] > 0.0 ? 1.0/m.vect[2] : 0.0);
         m.vect[0] = m.vect[1] = m1;
         m.vect[2] = m.vect[3] = m2;
         *((REALVECT*)&colorComplexValue(res,x,y,c)) = vec_madd(r,m.val,Vzero);
#else
         union { REALVECT val; REAL vect[4]; } n, d, r1, m, r;
         REAL m1, m2;
         n.val = *((REALVECT*)&colorComplexValue(a,x,y,c));
         d.val = *((REALVECT*)&colorComplexValue(b,x,y,ct));
         r1.val = n.val * d.val;  // Direct product
         m.val = d.val*d.val;
         m1 = m.vect[0] + m.vect[1];
         if ( m1 > 0.0 )
         {
            r.vect[0] = (r1.vect[0] + r1.vect[1])/m1;
            r.vect[1] = (d.vect[0] * n.vect[1] - n.vect[0] * d.vect[1])/m1;
         }
         else
         {
            r.vect[0] = 0.0;
            r.vect[1] = 0.0;
         }
         m2 = m.vect[2] + m.vect[3];
         if ( m2 > 0.0 )
         {
            r.vect[2] = (r1.vect[2] + r1.vect[3])/m2;
            r.vect[3] = (d.vect[2] * n.vect[3] - n.vect[2] * d.vect[3])/m2;
         }
         else
         {
            r.vect[0] = 0.0;
            r.vect[1] = 0.0;
         }
         *((REALVECT*)&colorComplexValue(res,x,y,c)) = r.val;
#endif
      }
}
#endif

@implementation LynkeosFourierBuffer

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _halfw = 0;
      _spadw = 0;
      _goal = 0;
      _direct = NULL;
      _inverse = NULL;
      _isSpectrum = NO;

#if !defined(DOUBLE_PIXELS) || defined(__i386__)
      if ( hasSIMD )
      {
         _mul_one_spectrum_line = vect_spectrum_mul_one_line;
         _mul_one_conjugate_line = vect_spectrum_mul_conjugate_one_line;
         _scale_one_spectrum_line = vect_spectrum_scale_one_line;
         _div_one_spectrum_line = vect_spectrum_div_one_line;
      }
      else
#endif
      {
         _mul_one_spectrum_line = std_spectrum_mul_one_line;
         _mul_one_conjugate_line = std_spectrum_mul_conjugate_one_line;
         _scale_one_spectrum_line = std_spectrum_scale_one_line;
         _div_one_spectrum_line = std_spectrum_div_one_line;
      }
   }

   return( self );
}

- (id) initWithNumberOfPlanes:(u_char)nPlanes 
                        width:(u_short)w height:(u_short)h 
                     withGoal:(u_char)goal
{
   return( [self initWithNumberOfPlanes:nPlanes width:w height:h
                               withGoal:goal isSpectrum:NO] );
}

- (id) initWithNumberOfPlanes:(u_char)nPlanes 
                        width:(u_short)w height:(u_short)h 
                     withGoal:(u_char)goal
                   isSpectrum:(BOOL)isSpectrum
{
   NSAssert( nPlanes == 1 || nPlanes == 3, 
             @"MyFourierBuffer handles only monochrome or RGB images" );

   if ( (self = [self init]) != nil )
   {
      int sizes[2], realPaddedSizes[2], complexPaddedSizes[2];
      u_char c;

      _nPlanes = nPlanes;
      _w = w;
      _halfw = w/2+1;
      // Line width is padded for Altivec
      _spadw = (_halfw*sizeof(COMPLEX) + 4*sizeof(float) - 1)/4/sizeof(float);
      _spadw *= 4*sizeof(float)/sizeof(COMPLEX);
      _padw = _spadw*sizeof(COMPLEX)/sizeof(REAL);    // Padded real pixels
      _h = h;
      _goal = goal;
      _isSpectrum = isSpectrum;

      pthread_mutex_lock( &fftwLock );

      _data = FFT_MALLOC( _nPlanes*sizeof(COMPLEX)*_spadw*_h );
      NSAssert( _data != NULL, @"FFT buffer allocation failed" );
      _freeWhenDone = YES;

      sizes[0] = _h;
      sizes[1] = _w;
      realPaddedSizes[0] = _h;
      realPaddedSizes[1] = _padw;
      complexPaddedSizes[0] = _h;
      complexPaddedSizes[1] = _spadw;

      if ( _goal & FOR_DIRECT )
         _direct = FFT_PLAN_R2C( 2, sizes, _nPlanes,
                              _data, realPaddedSizes, 1, _padw*h,
                              (COMPLEX*)_data, complexPaddedSizes, 1, _spadw*h,
                              fftwDefaultFlag | FFTW_MEASURE );

      if ( _goal & FOR_INVERSE )
         _inverse = FFT_PLAN_C2R( 2, sizes,  _nPlanes,
                               (COMPLEX*)_data, complexPaddedSizes, 1, _spadw*h,
                               _data, realPaddedSizes, 1, _padw*h,
                               fftwDefaultFlag | FFTW_MEASURE );

      pthread_mutex_unlock( &fftwLock );

      for( c = 0; c < nPlanes; c++ )
         _planes[c] = &((REAL*)_data)[c*_h*_padw];
   }

   return( self );
}

- (void) dealloc
{
   pthread_mutex_lock( &fftwLock );

   if ( _goal & FOR_DIRECT )
      FFT_DESTROY_PLAN( _direct );
   if ( _goal & FOR_INVERSE )
      FFT_DESTROY_PLAN( _inverse );

   pthread_mutex_unlock( &fftwLock );

   [super dealloc];
}

- (id) copyWithZone:(NSZone *)zone
{
   LynkeosFourierBuffer *buf =
      [[LynkeosFourierBuffer allocWithZone:zone] initWithNumberOfPlanes:_nPlanes
                                                             width:_w
                                                            height:_h
                                                          withGoal:_goal];
   memcpy( buf->_data, _data, _nPlanes*sizeof(COMPLEX)*_spadw*_h );
   buf->_isSpectrum = _isSpectrum;

   return( buf );
}

- (void) clear
{
   u_short x, y, c;

   [self resetMinMax];
   for( c = 0; c < _nPlanes; c++ )
      for( y = 0; y < _h; y++ )
         for( x = 0; x < _halfw; x++ )
            colorComplexValue(self,x,y,c) = 0.0;
}

- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax
{
   NSAssert( !_isSpectrum, @"GetMinLevel:maxLevel: called on a spectrum" );
   [super getMinLevel:vmin maxLevel:vmax];
}

- (BOOL) isSpectrum { return( _isSpectrum ); }

- (void) directTransform
{
   NSAssert( _goal & FOR_DIRECT, @"Non scheduled direct transform" );
   NSAssert( !_isSpectrum, @"Target is already transformed" );
   [self resetMinMax];
   FFT_EXECUTE( _direct );
   _isSpectrum = YES;
}

- (void) inverseTransform
{
   const REAL area = _w*_h;
   u_short x, y, c;

   NSAssert( _goal & FOR_INVERSE, @"Non scheduled inverse transform" );
   NSAssert( _isSpectrum, @"Target is not a spectrum" );
   FFT_EXECUTE( _inverse );
   _isSpectrum = NO;

   [self resetMinMax];
   for( c = 0; c < _nPlanes; c++ )
   {
      for( y = 0; y < _h; y++ )
      {
         for( x = 0; x < _w; x++ )
         {
            REAL *v = &colorValue(self,x,y,c);

            *v /= area;

            /* Update the range */
            if ( *v < _min[c] )
               _min[c] = *v;
            if ( *v > _max[c] )
               _max[c] = *v;
         }
      }
      if ( _min[c] < _min[_nPlanes] )
         _min[_nPlanes] = _min[c];
      if ( _max[c] > _max[_nPlanes] )
         _max[_nPlanes] = _max[c];
   }
}

- (void) normalize
{
   unsigned short int x, y, c;

   NSAssert( _isSpectrum, @"Target is not a spectrum" );

   // The (0,0) sample of the spectrum is the integral on the domain
   for( c = 0; c < _nPlanes; c++ )
   {
      const REAL weight = __real__ colorComplexValue(self,0,0,c);
      for( y = 0; y < _h; y++ )
         for( x = 0; x < _halfw; x++ )
            colorComplexValue(self,x,y,c) /= weight;
   }
}

- (void) conjugate
{
   unsigned short int x, y, c;

   NSAssert( _isSpectrum, @"Target is not a spectrum" );

   for( c = 0; c < _nPlanes; c++ )
   {
      for( y = 0; y < _h; y++ )
         for( x = 0; x < _halfw; x++ )
            __imag__ colorComplexValue(self,x,y,c) *= -1.0;
   }
}

- (void) substract:(LynkeosFourierBuffer*)image
{
   u_short x, y, c;

   for( c = 0; c < _nPlanes; c++ )
      for( y = 0; y < _h; y++ )
         for( x = 0; x < _halfw; x++ )
            colorComplexValue(self,x,y,c) -= colorComplexValue(image,x,y,c);
}

- (void) multiplyWith:(LynkeosFourierBuffer*)term result:(LynkeosFourierBuffer*)result
{
   NSAssert( (_nPlanes == term->_nPlanes || term->_nPlanes == 1)
             && _nPlanes == result->_nPlanes 
             && _w == term->_w && _h == term->_h
             && _w == result->_w && _h == result->_h
             && _isSpectrum == term->_isSpectrum
             && _isSpectrum == result->_isSpectrum,
             @"Incompatible terms in multiplication" );
   ArithmeticOperand_t op = { .term=term };

   if ( _isSpectrum )
      _process_image( self, _process_image_selector, op, result,
                     (ImageProcessOneLine_t)_mul_one_spectrum_line );

   else
   {
      [self resetMinMax];
      _process_image( self, _process_image_selector, op, result,
                     _mul_one_image_line );
   }
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

   if ( _isSpectrum )
      _process_image( self, _process_image_selector, op, self,
                     (ImageProcessOneLine_t)_scale_one_spectrum_line );
   else
   {
      [self resetMinMax];
      _process_image( self, _process_image_selector, op, self,
                     _scale_one_image_line );
   }
}

- (void) multiplyWithConjugateOf:(LynkeosFourierBuffer*)term
                          result:(LynkeosFourierBuffer*)result
{
   NSAssert( (_nPlanes == term->_nPlanes || term->_nPlanes == 1)
             && _nPlanes == result->_nPlanes 
             && _w == term->_w && _h == term->_h
             && _w == result->_w && _h == result->_h
             && _isSpectrum && term->_isSpectrum && result->_isSpectrum,
             @"Incompatible terms in multiplication with conjugate" );
   ArithmeticOperand_t op = { .term=term };

   if ( _isSpectrum )
      _process_image( self, _process_image_selector, op, result,
                     (ImageProcessOneLine_t)_mul_one_conjugate_line );
}

- (void) divideBy:(LynkeosFourierBuffer*)denom result:(LynkeosFourierBuffer*)result
{
   NSAssert( (_nPlanes == denom->_nPlanes || denom->_nPlanes == 1)
             && _nPlanes == result->_nPlanes 
             && _w == denom->_w && _h == denom->_h
             && _w == result->_w && _h == result->_h
             && _isSpectrum == denom->_isSpectrum
             && _isSpectrum == result->_isSpectrum,
             @"Incompatible terms in division" );
   ArithmeticOperand_t op = { .term=denom };

   if ( _isSpectrum )
      _process_image( self, _process_image_selector, op, result,
                     (ImageProcessOneLine_t)_div_one_spectrum_line );

   else
   {
      [self resetMinMax];
      _process_image( self, _process_image_selector, op, result,
                     _div_one_image_line );
   }
}

+ (LynkeosFourierBuffer*) fourierBufferWithNumberOfPlanes:(u_char)nPlanes 
                                              width:(u_short)w 
                                             height:(u_short)h 
                                           withGoal:(u_char)goal
{
   return( [[[self alloc] initWithNumberOfPlanes:nPlanes
                                           width:w height:h 
                                        withGoal:goal] autorelease] );
}
@end
