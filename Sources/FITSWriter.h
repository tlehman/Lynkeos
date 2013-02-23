//
//  Lynkeos
//  $Id: FITSWriter.h 506 2011-03-26 18:40:46Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Apr 22 2005.
//  Copyright (c) 2005,2011. Jean-Etienne LAMIAUD
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
 * @abstract Definitions of the FITS writer class.
 */
#ifndef __FITSWRITER_H
#define __FITSWRITER_H


#import <Foundation/Foundation.h>

#include "LynkeosFileWriter.h"

/*!
 * @class FITSWriter
 * @abstract FITS file format writer class.
 * @ingroup FileAccess
 */
@interface FITSWriter : NSObject <LynkeosImageFileWriter>
{
   IBOutlet NSPanel     *_cfgPanel;          //!< Configuration panel

   u_short              _compression;        //!< Kind of compression
   int                  _imgType;            //!< Number of bits per pixels
}

/*!
 * @method changeCompression:
 * @abstract Action connected to the compression popup.
 * @param sender The popup
 */
- (void) changeCompression :(id)sender ;

/*!
 * @method changeBits:
 * @abstract Action connected to the "sample representation" popup
 * @param sender The popup
 */
- (void) changeBits :(id)sender ;

/*!
 * @method confirmParams:
 * @abstract Action connected to the "OK" button
 * @param sender The button
 */
- (void) confirmParams :(id)sender ;

/*!
 * @method cancelParams:
 * @abstract Action connected to the "Cancel" button
 * @param sender The button
 */
- (void) cancelParams :(id)sender ;

@end

#endif
