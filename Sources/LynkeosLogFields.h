//
//  Lynkeos
//  $Id: LynkeosLogFields.h 462 2008-10-05 21:31:44Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Dec 28 2007.
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

#ifndef __LYNKEOSLOGFIELDS_H
#define __LYNKEOSLOGFIELDS_H
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

/*!
 * @abstract This class ties together a slider's log values and a textfield
 * @ingroup Views
 */
@interface LynkeosLogFields : NSObject
{
   NSSlider *_slider;   //!< The log slider
   NSTextField *_text;  //!< The linked text field
   double _offset;      //!< Offset to allow negative values
}
/*!
 * @abstract Designated initializer for LynkeosLogFields
 * @param slider The slider which will use a log sclae
 * @param text The numeric text field displaying the value
 * @result An initialized LynkeosLogFields
 */
- (id) initWithSlider:(NSSlider*)slider andTextField:(NSTextField*)text ;
/*!
 * @abstract Accessor to the linear value
 * @param sender The control wich value is retrieved
 * @result The linear value
 */
- (double) valueFrom:(id)sender ;
/*!
 * @abstract Set the linear value
 * @param v The new value
 */
- (void) setDoubleValue:(double)v ;
@end
#endif
