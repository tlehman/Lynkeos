//
//  Lynkeos
//  $Id: MyLucyRichardson.h 475 2008-11-09 10:14:42Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Nov 2 2007.
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
 * @abstract Definitions for Lucy Richardson deconvolution processing
 */
#ifndef __MYLUCYRICHARDSON_H
#define __MYLUCYRICHARDSON_H

#import <Foundation/Foundation.h>

#include "LynkeosProcessing.h"
#include "LynkeosFourierBuffer.h"

/*!
 * @abstract This protocol is used to inform the view about the progress.
 * @ingroup Processing
 */
@protocol MyLucyRichardsonDelegate
- (oneway void) iterationEnded ; //!< Perform updates for an iteration end
@end

/*!
 * @abstract Lucy Richardson deconvolution parameters
 * @ingroup Processing
 */
@interface MyLucyRichardsonParameters : LynkeosImageProcessingParameter
{
@public
   unsigned int   _numberOfIteration;     //!< Number of algorithm iterations
   LynkeosStandardImageBuffer *_psf;      //!< Point spread function
   NSObject <MyLucyRichardsonDelegate> *_delegate; //!< Called on main thread
}

/*!
 * @abstract Dedicated initializer
 * @param psf The point spread function
 * @param nb The number of algorithm iterations
 */
- (id) initWithPSF:(LynkeosStandardImageBuffer*)psf
     andIterations:(unsigned int)nb ;
@end

/*!
 * @abstract Lucy Richardson deconvolution class
 * @ingroup Processing
 */
@interface MyLucyRichardson : NSObject <LynkeosProcessing>
{
   LynkeosFourierBuffer *_psfSpectrum;      //!< Point Spread Function spectrum
   unsigned int    _numberOfIteration;      //!< Number of algorithm iterations
   NSObject <MyLucyRichardsonDelegate> *_delegate; //!< Called on main thread
}
@end

#endif
