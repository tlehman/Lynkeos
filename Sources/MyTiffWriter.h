//
//  Lynkeos
//  $Id: MyTiffWriter.h 271 2005-09-01 21:13:42Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Apr 15 2005.
//  Copyright (c) 2005. Jean-Etienne LAMIAUD
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
 * @abstract Definitions of the TIFF writer class.
 */
#ifndef __MYTIFFFILEWRITER_H
#define __MYTIFFFILEWRITER_H


#import <Foundation//Foundation.h>

#include "LynkeosFileWriter.h"

/*!
 * @class MyTiffWriter
 * @abstract TIFF file format writer class.
 * @ingroup FileAccess
 */
@interface MyTiffWriter : NSObject <LynkeosImageFileWriter>
{
   IBOutlet NSPanel     *_cfgPanel;       //!< Configuration panel

   u_short              _compression;     //!< Kind of compression
   u_short              _nBits;           //!< Number of bits per pixels
}

/*!
 * @method changeCompression:
 * @abstract Action connected to the compression popup
 * @param sender The popup.
 */
- (void) changeCompression :(id)sender ;

/*!
 * @method changeBits:
 * @abstract Action connected to the "bits per pixels" popup
 * @param sender The popup.
 */
- (void) changeBits :(id)sender ;

/*!
 * @method confirmParams:
 * @abstract Action connected to the "OK" button
 * @param sender The button.
 */
- (void) confirmParams :(id)sender ;

/*!
 * @method cancelParams:
 * @abstract Action connected to the "Cancel" button
 * @param sender The button.
 */
- (void) cancelParams :(id)sender ;

@end

#endif
