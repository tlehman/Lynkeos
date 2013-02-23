//
//  Lynkeos
//  $Id:$
//
//  Created by Jean-Etienne LAMIAUD on Fri Nov 14 2008.
//  Copyright (c) 2008, Jean-Etienne LAMIAUD.
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
 * @abstract Definitions of the processing stack manager
 */

#ifndef __PROCESSSTACKMANAGER_H
#define __PROCESSSTACKMANAGER_H

#import <Foundation/Foundation.h>

#include <LynkeosCore/LynkeosProcessableImage.h>

/*!
 * @abstract Access to the processings stack in any processing parameters
 * @discussion The process ref is nil
 */
extern NSString * const K_PROCESS_STACK_REF;

/*!
 * @abstract This class ensures the processing of the whole stack
 * @ingroup Processing
 */
@interface ProcessStackManager : NSObject
{
   LynkeosProcessableImage *_item;              //!< Item being processed
   int                      _intermediateRank;  //!< Intermediate result rank
   int                      _currentRank;      //!< Rank of last applied process
   NSMutableArray          *_stack;             //!< Process stack for this item
}

/*!
 * @abstract Get the starting parameter in an item's stack
 * @discussion Given a parameter, get the parameter at which the process shall
 *    restart to yield the correct item's final result for the whole stack.
 * @param item The item to process
 * @param inParam The parameters for which the item needs to be re-processed.
 *    If nil, the first applicable parameter is returned.
 * @result The parameter at which the processing shall start
 */
- (LynkeosImageProcessingParameter*)
                  getParameterForItem:(LynkeosProcessableImage*)item
                             andParam:(LynkeosImageProcessingParameter*)inParam;

/*!
 * @abstract Get the next parameter to process
 * @discussion This method is called when one process (with given parameters)
 *    has been processed.
 * @param item The item being processed
 * @result The next parameter to process
 */
- (LynkeosImageProcessingParameter*) nextParameterToProcess:
                                                 (LynkeosProcessableImage*)item;

@end

#endif /* __PROCESSSTACKMANAGER_H */
