//
//  Lynkeos
//  $Id: LynkeosBasicAlignResult.h 462 2008-10-05 21:31:44Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Thu May 8 2008.
//  Copyright (c) 2008. Jean-Etienne LAMIAUD
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
 * @abstract Image alignment result class
 */
#ifndef __LYNKEOSBASICALIGNERSULT_H
#define __LYNKEOSBASICALIGNERSULT_H

#import <Foundation/Foundation.h>

#include "LynkeosCore/LynkeosProcessingView.h"

/*!
 * @abstract Process string for this result
 */
extern NSString * const LynkeosAlignRef;

/*!
 * @abstract Reference for reading/setting the alignment result.
 */
extern NSString * const LynkeosAlignResultRef;

/*!
 * @abstract Default class for working with alignment results
 * @discussion It shall not be assumed that all alignment results use this class.
 */
@interface LynkeosBasicAlignResult : NSObject <LynkeosViewAlignResult>
{
@public
   NSPoint          _alignOffset;        //!< Result of alignment!
}
@end

#endif
