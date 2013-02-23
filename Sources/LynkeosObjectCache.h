//
//  Lynkeos
//  $Id: LynkeosObjectCache.h 479 2008-11-23 14:28:07Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Mar 14 2008.
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
 * @abstract Class used to cache any kind of object
 */
#ifndef __MYOBJECTCACHE_H
#define __MYOBJECTCACHE_H

#import <Foundation/Foundation.h>

//! Policy for refreshing the cache (ie: putting an object on top of the cache)
enum
{
   ReadRefresh  = 0x0001,
   WriteRefresh = 0x0002
};

//! Cache strategy for maximum capacity
typedef enum
{
   CacheNumberOfObjects = 0,
   CacheMemorySize
} CacheCapacityStrategy_t;

/*!
 * @abstract This class caches any kind of object
 */
@interface LynkeosObjectCache : NSObject
{
@private
   CacheCapacityStrategy_t _capacityStrategy; //!< Cache capacity strategy
   NSMutableDictionary *_cacheDict;    //!< Objects stored by keys
   NSMutableArray      *_keyAge;       //!< Keys stored by age
   u_long               _capacity;     //!< Maximum number or size
   u_long               _size;         //!< Current size
   u_short              _policy;       //!< Refresh policy
}

/*!
 * @abstract Common cache for movie classes
 * @result The movie class common cache
 */
+ (void) setMovieCache:(LynkeosObjectCache*)cache ;

/*!
 * @abstract Common cache for processing images
 * @result The image processing common cache
 */
+ (void) setImageProcessingCache:(LynkeosObjectCache*)cache ;

/*!
 * @abstract Common cache for movie classes
 * @result The movie class common cache
 */
+ (LynkeosObjectCache*) movieCache ;

/*!
 * @abstract Common cache for processing images
 * @result The image processing common cache
 */
+ (LynkeosObjectCache*) imageProcessingCache ;

/*!
 * @abstract Initializer
 * @discussion When first added to the cache, objects are always at the top,
 *    whatever the policy
 * @param strategy Caching strategy (memory size or number of objects)
 * @param capacity The maximum number of objects, or maximum memory in the cache
 * @param policy The refresh policy of the cache
 * @result The initialized cache object
 */
- (id) initWithStrategy:(CacheCapacityStrategy_t)strategy
               capacity:(u_long)capacity policy:(u_short)policy ;

/*!
 * @abstract Put an object in the cache
 * @discussion The object is retained by the cache and released when deleted
 *    from it
 * @param obj The object to add to the cache
 * @param key The key to identify this object
 */
- (void) setObject:(NSObject*)obj forKey:(id)key ;

/*!
 * @abstract Retrieve an object from the cache
 * @param key the key for this object
 * @result The object it it was found in the cache, nil otherwise
 */
- (NSObject*) getObjectForKey:(id)key ;

/*!
 * @abstract Adapt the cache to a new size
 * @param capacity The new size
 */
- (void) setCapacity:(u_long)capacity ;
@end

#endif