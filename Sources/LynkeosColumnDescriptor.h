//
//  Lynkeos
//  $Id: LynkeosColumnDescriptor.h 462 2008-10-05 21:31:44Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Mon Apr 9 2007.
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
 * @abstract Outline view columns registering.
 */

#ifndef __LYNKEOSCOLUMNDESCRIPTOR_H
#define __LYNKEOSCOLUMNDESCRIPTOR_H
#import <Foundation/Foundation.h>

/*!
 * @abstract Column description (to be put in the dictionary)
 * @ingroup Models
 */
@interface LynkeosColumnDescription : NSObject
{
@public
   /*!
    * @abstract Name of the process owning the value to display
    * @discussion This is used as a key for retrieving the
    *    LynkeosProcessingParameter which contains the value to display.
    */
   NSString *_processingRef;
   /*!
    * @abstract Name of the parameter
    * @discussion This is used as the second key for retrieving the
    *    LynkeosProcessingParameter which contains the value to display.
    */
   NSString *_parameterReference;
   //! Name of the field in the LynkeosProcessingParameter
   NSString *_fieldName;
   //! Display format for NSString stringWithFormat: method
   NSString *_format;
}
@end

/*!
 * @abstract Singleton class for registering outline view columns.
 * @discussion The processing view classes register the parameters which can
 *    be displayed in the outline view.<br>
 *    The \ref LynkeosWindowController "window controller" uses this singleton
 *    to display the values.
 * @ingroup Models
 */
@interface LynkeosColumnDescriptor : NSMutableDictionary
{
}

/*!
 * @abstract Access to the singleton instance
 * @result The singleton instance
 */
+ (LynkeosColumnDescriptor*) defaultColumnDescriptor ;

/*!
 * @abstract Shortcut to fill the dictionary with a column description
 * @param key The string identifying the column
 * @param proc The reference of the process to which this information belongs
 * @param ref The reference under which this parameter is stored
 * @param field The name of the field used for key value coding
 * @param format The format used for displaying this parameter
 */
- (void) registerColumn:(NSString*)key forProcess:(NSString*)proc
              parameter:(NSString*)ref field:(NSString*)field
                 format:(NSString*)format;
@end

#endif // __MYCOLUMNDESCRIPTOR_H