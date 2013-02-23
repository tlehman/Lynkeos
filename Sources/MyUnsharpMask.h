//
//  Lynkeos
//  $Id: MyUnsharpMask.h 475 2008-11-09 10:14:42Z j-etienne $
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

/*!
 * @header
 * @abstract Definitions for Deconvolution processing.
 */
#ifndef __MYUNSHARPMASK_H
#define __MYUNSHARPMASK_H

#import <Foundation/Foundation.h>

#include "processing_core.h"
#include "LynkeosProcessing.h"

/*!
 * @abstract Unsharp mask processing parameters
 * @ingroup Processing
 */
@interface MyUnsharpMaskParameters : LynkeosImageProcessingParameter
{
@public
   double   _radius;    //!< Half width of the gaussian blur
   double   _gain;      //!< Amplification of the gradient in the final image
   BOOL     _gradientOnly; //!< Do not add the original image to the gradient

   NSLock   *_loopLock;           //!< Exclusive access to members below
   LynkeosFourierBuffer *_spectrum;    //!< Spectrum being processed
   u_short  _livingThreadsNb;     //!< Number of threads still living
   u_short  _nextY;               //!< Next line to process
   REAL     *_expX;               //!< X term of the unsharp gauss
   REAL     *_expY;               //!< Y term of the unsharp gauss
}
@end

/*!
 * @abstract Unsharp mask processing
 * @ingroup Processing
 */
@interface MyUnsharpMask : NSObject <LynkeosProcessing>
{
   MyUnsharpMaskParameters  *_params; //!< Unsharp mask parameters
   id <LynkeosProcessableItem> _item; //!< The item being processed
   //! Strategy (vector or not) method for processing one image line
   void(*_process_One_Line)(MyUnsharpMaskParameters*,u_short);
   void (*_lock)(id, SEL);        //!< Static access to the lock (for locking)
   void (*_unlock)(id, SEL);      //!< Static access to the lock (for unlocking)
}

@end
#endif
