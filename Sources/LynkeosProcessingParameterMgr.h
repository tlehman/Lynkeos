//
//  Lynkeos
//  $Id: LynkeosProcessingParameterMgr.h 498 2010-12-29 15:46:09Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Thu Sep 14 2006.
//  Copyright (c) 2006-2008. Jean-Etienne LAMIAUD
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
 * @abstract Processing parameter base class
 */
#ifndef __LYNKEOSSPROCESSINGPARAMETERMGR_H
#define __LYNKEOSSPROCESSINGPARAMETERMGR_H

#include <pthread.h>

#include <LynkeosCore/LynkeosProcessing.h>

/*!
 * @abstract Processing parameter management class
 */
@interface LynkeosProcessingParameterMgr : NSObject
{
@public
   LynkeosProcessingParameterMgr *_parent;           //!< Parameters of the container
   NSDocument <LynkeosDocument> *_document;  //!< The top document
@private
   NSMutableDictionary   *_parametersDict;   //!< Parameters dictionary
   //! The thread in which notifications are made
   NSThread              *_mainThread;
   //! To protect NSMutableDictionary against concurrent access while writing
   pthread_rwlock_t       _lock;
}

/*!
 * @abstract Dedicated initializer.
 * @param parent Parent manager object
 * @result Initialized object
 */
- (id) initWithParent: (LynkeosProcessingParameterMgr*)parent;

/*!
 * @abstract Document initializer.
 * @param document Document top object
 * @result Initialized object
 */
- (id) initWithDocument: (NSDocument <LynkeosDocument> *)document;

/*!
 * @abstract Accessor to the parameters dictionary
 * @result The dictionary
 */
- (NSDictionary*) getDictionary ;

/*!
 * @abstract Set the dictionary
 * @param dict An already filled in dictionary
 */
- (void) setDictionary:(NSDictionary*)dict ;

/*!
 * @abstract Returns the required processing parameter
 * @param ref A string identifying this parameter in its class.
 * @param processing A string identifying the owner of this parameter. nil is 
 *    valid, if the parameter is of general scope.
 * @param goUp Whether to look for the parameter up in the hierarchy
 * @result The required parameter
 */
- (id <LynkeosProcessingParameter>) getProcessingParameterWithRef:(NSString*)ref 
                                             forProcessing:(NSString*)processing
                                                             goUp:(BOOL)goUp ;

/*!
 * @abstract Updates the required processing parameter
 * @param parameter The new parameter value
 * @param ref A string identifying this parameter in its class.
 * @param processing A string identifying the owner of this parameter. nil is 
 *    valid, if the parameter is of general scope.
 * @result The required parameter
 */
- (void) setProcessingParameter:(id <LynkeosProcessingParameter>)parameter
                        withRef:(NSString*)ref 
                  forProcessing:(NSString*)processing ;
/*!
 * @abstract Propagate upward, a notification for object modification.
 * @param item The modified item
 */
- (oneway void) notifyItemModification:(id)item ;

@end

#endif
