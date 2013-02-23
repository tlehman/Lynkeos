/*
 * Connection between threads in the same adress space
 * $Id: LynkeosThreadConnection.h 501 2010-12-30 17:21:17Z j-etienne $
 *
 * Created by Jean-Etienne LAMIAUD on Wed May 21 2006
 * Copyright (C) 2006-2008 Jean-Etienne Lamiaud 
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

/*! \defgroup Support Support classes
 * Support classes offer utility features to other classes
 */

/*!
* @header
 * @abstract Connection between threads in the same adress space
 */
#ifndef __LYNKEOSTHREADCONNECTION_H
#define __LYNKEOSTHREADCONNECTION_H

#import <Foundation/Foundation.h>

@class LynkeosThreadCnxEnd;

/*!
 * @abstract This class implements a connection between threads in the same
 *   adress space.
 * @discussion Contrary to the standard NSConnection, the arguments to
 *    inter-thread calls are passed by address. This saves time but forbid
 *    use in inter-process or network messaging.<br>
 *    The thread which creates the connection is called "main" hereunder, even
 *    though it can be any thread.
 * @ingroup Support
 */
@interface LynkeosThreadConnection : NSObject
{
@private
   id _rootObject;     //!< Object controlling the connection in the main thread
   id _rootProxy;                   //!< Proxy for the controlling object
   LynkeosThreadCnxEnd *_endPoint[2];    //!< Main and thread enpoints
   //! Strategy for sending in the Mach port
   BOOL (*_sendInMachPort)( NSPortMessage *message,
                            id cnx,
                            LynkeosThreadCnxEnd *sendPoint,
                            NSInvocation *inv );

}

/*!
 * @abstract Accessor to the port of the "main" end of the connection
 * @result The port
 */
- (NSPort*) mainPort;

/*!
 * @abstract Accessor to the port of the "thread" end of the connection
 * @result The port
 */
- (NSPort*) threadPort;

/*!
 * @abstract Check wether some message remains to be processed
 * @discussion You do not need to call this before releasing the connection
 *    as it itself waits for idle state before deallocating.
 * @result YES if no message is waiting to be processed
 */
- (BOOL) connectionIdle ;

/*!
 * @abstract Creation of a proxy for the object controlling one thread
 * @discussion The proxy shall be released (in either thread) before its
 *    connection is deallocated.
 * @param object The controlling object
 * @param inThread Selects the created thread if YES
 * @result The proxy for the object controlling the requested thread
 */
- (NSProxy*) proxyForObject:(id)object inThread:(BOOL)inThread ;

/*!
 * @abstract Set the object controlling the creating thread
 * @param anObject The controlling object
 */
- (void)setRootObject:(id)anObject;

/*!
 * @abstract Access to the proxy for the object controlling the creating thread
 * @discussion This method shall be called at least once from the created thread
 *    as the first call registers the connection in the thread run loop.
 * @result The proxy for the object controlling the creating thread
 */
- (NSProxy*)rootProxy;

/*!
 * @abstract Call a selector on an object on the main thread
 * @discussion The selector shall take only one argument of type id, or no
 *    argument at all.<br>
 *    The LynkeosThreadConnection registered for the current thread will be
 *    used for sending the request.
 * @param sel The selector to perform
 * @param target The target object
 * @param arg The only argument of the method being called
 */
+ (void) performSelectorOnMainThread:(SEL)sel forObject:(NSObject*)target
                            withArg:(id)arg;

/*!
 * @abstract Connection initialization
 * @param mainPort The port of the creating thread
 * @param threadPort The port for the created thread
 * @result The new connection
 */
- (id)initWithMainPort:(NSPort*)mainPort threadPort:(NSPort*)threadPort;

   /*!
   * @abstract Connection initialization
    * @param mainPort The port of the creating thread
    * @param threadPort The port for the created thread
    * @param queueSize Number of elements to queue when Mach port is full
    * @result The new connection
    */
- (id)initWithMainPort:(NSPort*)mainPort threadPort:(NSPort*)threadPort
             queueSize:(int)queueSize;

@end

#endif
