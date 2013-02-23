/*
 //
 //  Lynkeos
 //  $Id: ProcessingUtilities.c 362 2007-12-26 22:18:12Z j-etienne $
 //
 //  Created by Jean-Etienne LAMIAUD on Sun Nov 4 2007.
 //  Copyright (c) 2007. Jean-Etienne LAMIAUD
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
 */

#include "ProcessingUtilities.h"

#define K_CUTOFF 2	/* The Gaussian is 1/K_CUTOFF at argument radius */

void MakeGaussian( REAL * const * const planes,
                   u_short width, u_short height, u_short nPlanes,
                   u_short lineWidth, double radius )
{
   const double k = log(K_CUTOFF)/radius/radius;
   u_short x, y, c;

   // Fill the buffer with the gaussian
   for( y = 0; y <= (height+1)/2; y++ )
   {
      for( x = 0; x <= (width+1)/2; x++ )
      {
         double d2, v;

         d2 = x*x + y*y;
         v = exp( -k*d2 );

         for( c = 0; c < nPlanes; c++ )
         {
            planes[c][x+lineWidth*y] = v;

            if ( x != 0 )
               planes[c][width-x+lineWidth*y] = v;

            if ( y != 0 )
               planes[c][x+lineWidth*(height-y)] = v;

            if ( x != 0 && y != 0 )
               planes[c][width-x+lineWidth*(height-y)] = v;
         }
      }
   }
}