/*=============================================================================
** Lynkeos
** $Id: corelation.m 501 2010-12-30 17:21:17Z j-etienne $
**-----------------------------------------------------------------------------
**
**  Created by Jean-Etienne LAMIAUD on Apr 30, 1998
**  Renamed from corelation.c to corelation.m on Mar 11, 2005
**  Copyright (c) 1998,2003-2008. Jean-Etienne LAMIAUD
**
** This program is free software; you can redistribute it and/or modify
** it under the terms of the GNU General Public License as published by
** the Free Software Foundation; either version 2 of the License, or
** (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software
** Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
**
**-----------------------------------------------------------------------------
*/
#include <stdlib.h>
#include <assert.h>

#include "processing_core.h"
#include "corelation.h"
#include "LynkeosStandardImageBufferAdditions.h"

void correlate_spectrums( LynkeosFourierBuffer *s1, LynkeosFourierBuffer *s2, 
                          LynkeosFourierBuffer *r )
{
   /* Fourier transform of correlation is the product of s1 by s2 conjugate */
   [s1 multiplyWithConjugateOf:s2 result:r];

   [r inverseTransform];
}

void correlate( LynkeosFourierBuffer *s1, LynkeosFourierBuffer *s2, LynkeosFourierBuffer *r )
{
   /* Transform both images */
   [s1 directTransform];
   [s2 directTransform];

   /* Perform the correlation */
   correlate_spectrums( s1, s2, r );
}

void corelation_peak( LynkeosFourierBuffer *result, CORRELATION_PEAK *peak )
{
   u_short x, y, c; 
   double sum, module_max, module_min;
   double xp, yp, s_x2, s_y2;
   u_long nb_pixel;
   REAL r;

   assert( peak != NULL );

   for( c = 0; c < result->_nPlanes; c++ )
   {
      /* Search for min and max */
      module_max = 0.0;
      module_min = HUGE;

      for( y = 0; y < result->_h; y++ )
      {
         for( x = 0; x < result->_w; x++ )
         {
            r = colorValue(result,x,y,c);

            if ( r > module_max )
               module_max = r;
            if ( r < module_min )
               module_min = r;
         }
      }

      /* Locate the peak as the barycenter of pixels above (max-min)/sqrt(2) */
      xp = 0.0;
      yp = 0.0;
      s_x2 = 0.0;
      s_y2 = 0.0;
      sum = 0.0;
      nb_pixel = 0;

      for( y = 0; y < result->_h; y++ )
      {
         for( x = 0; x < result->_w; x++ )
         {
            double module;
            r = colorValue(result,x,y,c);
            module = r - module_min;

            if ( module > (module_max-module_min)*0.707 )
            {
               // Get the offset, taking into account the quadrants order
               // from the inverse FFT
               double dx = (2*x < result->_w ? x : x - result->_w),
                      dy = (2*y < result->_h ? y : y - result->_w);
               xp += dx*module;
               yp += dy*module;
               s_x2 += dx*dx*module;
               s_y2 += dy*dy*module;
               sum += module;
               nb_pixel++;
            }
         }
      }

      /* Present the results */
      xp /= sum;
      yp /= sum;
      peak[c].val = module_max - module_min;
      peak[c].x = xp;
      peak[c].y = yp;
      peak[c].sigma_x = sqrt(s_x2/sum - xp*xp);
      peak[c].sigma_y = sqrt(s_y2/sum - yp*yp);
   }
}
