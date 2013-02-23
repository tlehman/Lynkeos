/*
 * Connection between threads in the same adress space
 * $Id: LynkeosThreadConnection.m 501 2010-12-30 17:21:17Z j-etienne $
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
#import <AppKit/AppKit.h>

#include "LynkeosThreadConnection.h"

NSString const * const MyMainThreadConnection = @"MyMainThreadConnection";

#define K_QUEUE_TIMEOUT 0.02

#define K_QUEUE_DEBUG_LEVEL 1
#define K_FULL_DEBUG_LEVEL 2
int debug = 0;

/*!
 * @abstract Utility class used to queue messages when the port is full
 */
@interface MyThreadCnxQueue : NSObject
{
@private
   u_int           _size;      //!< Size of the queue
   NSPortMessage **_queue;     //!< 2nd level queue
   BOOL            _full;      //!< Whether the queue is full
   u_int           _insert;    //!< Insert pointer
   u_int           _extract;   //!< Extract pointer
}

/*!
 * @abstract Designated initializer.
 * @param size The queue size
 * @result The initialized queue
 */
- (id) initWithQueueSize:(u_int)size ;

/*!
 * @abstract Place a message in the queue.
 * @discussion If the queue is full, an assertion is raised 
 * @param msg The message to queue
 */
- (void) queueMessage: (NSPortMessage*)msg ;

/*!
 * @abstract Get the first message  without dequeuing or nil if the queue is empty
 * @result The message
 */
- (NSPortMessage*) firstMessage ;

/*!
 * @abstract Retrieves a message from the queue or nil if the queue is empty
 * @result The message
 */
- (NSPortMessage*) dequeueMessage ;

/*!
 * @abstract Whether the queue is full
 * @result Guess !
 */
- (BOOL) queueFull ;

/*!
 * @abstract Whether the queue is empty
 * @result See abstract
 */
- (BOOL) queueEmpty ;
@end

@implementation MyThreadCnxQueue

- (id) initWithQueueSize:(u_int)size
{
   if ( (self = [super init]) != nil )
   {
      _queue = (NSPortMessage**)malloc( size*sizeof(NSPortMessage*) );
      NSAssert( _queue != nil, @"Cannot allocate 2nd level queue" );
      _size = size;
      _full = NO;
      _insert = 0;
      _extract = 0;
   }

   return( self );
}

- (void) dealloc
{
   free( _queue );
   [super dealloc];
}

- (void) queueMessage: (NSPortMessage*)msg
{
   NSAssert( !_full, @"queueMessage in a full queue" );
   NSAssert( _insert < _size, @"Queue insert index is invalid" );
   _queue[_insert] = msg;
   _insert++;
   if ( _insert == _size )
      _insert = 0;
   if ( _insert == _extract )
      _full = YES;
}

- (NSPortMessage*) firstMessage
{
   NSPortMessage* msg = nil;
   if ( _insert != _extract || _full )
      msg = _queue[_extract];
   return( msg );
}

- (NSPortMessage*) dequeueMessage
{
   NSAssert( _extract < _size, @"Queue extract index is invalid" );
   NSPortMessage* msg = nil;
   if ( _insert != _extract || _full )
   {
      msg = _queue[_extract];
      _extract++;
      if ( _extract == _size )
         _extract = 0;
      _full = NO;
   }
   return( msg );
}

- (BOOL) queueFull { return( _full ); }

- (BOOL) queueEmpty { return( _insert == _extract && !_full ); }

@end

/*!
 * @abstract Connection states
 * @discussion The waiting values are flags
 */
typedef enum
{
   InvocationIdle = 0,
   WaitingInvocationEnd = 1,
   WaitingQueue = 2
} ThreadCnxState_t;

/*!
 * @abstract Connection endpoint
 */
@interface LynkeosThreadCnxEnd : NSObject
{
@public
   NSPort           *_port;           //!< This end mach port
   MyThreadCnxQueue *_queue;          //!< Second level queue
   ThreadCnxState_t  _state;          //!< The current cnx end state
   NSLock           *_countLock;       //!< To protect the counters
   int               _messageCount;    //!< Number of pending messages
}

/*!
 * @abstract Dedicated initializer
 * @param port This endpoint mach port
 * @param queueSize Second level queue size (can be 0)
 * @result Initialized connection endpoint
 */
- (id) initWithPort:(NSPort*)port queueSize:(int)queueSize;
/*!
 * @abstract Change the number of pending messages in the connection
 * @param n The number of messages to add (can be negative)
 */
- (void) adjustMessageCount:(int)n ;
@end

@implementation LynkeosThreadCnxEnd

- (id) initWithPort:(NSPort*)port queueSize:(int)queueSize
{
   if ( (self = [self init]) != nil )
   {
      _port = [port retain];
      if ( queueSize == 0 )
         _queue = nil;
      else
         _queue = [[MyThreadCnxQueue alloc] initWithQueueSize:queueSize];
      _state = InvocationIdle;
      _countLock = [[NSLock alloc] init];
      _messageCount = 0;
   }

   return( self );
}

- (void) dealloc
{
   [_port release];
   [_queue release];
   [_countLock release];
   [super dealloc];
}

- (void) adjustMessageCount:(int)n
{
   [_countLock lock];
   _messageCount += n;
   [_countLock unlock];
}
@end

/*!
 * @abstract Internal part of the connection class
 */
@interface LynkeosThreadConnection(QueueMgt)
/*!
 * @abstract Send a method invocation to an object over the connection
 * @param inv The invocation
 * @param inThread NO if the receiver is in the main thread
 */
- (void) sendInvocation:(NSInvocation*)inv inThread:(BOOL)inThread ;
@end

#define K_MAIN_ENDPOINT   0
#define K_THREAD_ENDPOINT 1

/*!
 * @abstract Proxy object for an object accessed across a MyThreadConnection
 */
@interface MyThreadProxy : NSProxy
{
@private
   id                  _object;    //!< Object for which we are a proxy
   BOOL                _inThread;  //!< Is the proxy for a "thread side" object
   LynkeosThreadConnection *_cnx;       //!< Owner connection
}

/*!
 * @abstract Creation of a proxy object
 * @param object The object for which we will be a proxy
 * @param cnx The connection through wich messages are sent and received
 * @param inThread Wether the object is in the thread
 * @result The new proxy object
 */
- (id) initWithObject:(id)object cnx:(LynkeosThreadConnection*)cnx
             inThread:(BOOL)inThread;

@end

@implementation MyThreadProxy

- (id) init
{
   _object = nil;
   _cnx = nil;

   return( self );
}

- (id) initWithObject:(id)object cnx:(LynkeosThreadConnection*)cnx
             inThread:(BOOL)inThread
{
   if ( (self = [self init]) != nil )
   {
      // Do not retain object because we are agregated to it
      _object = object;
      _cnx = cnx;  // Loose binding
      _inThread = inThread;
   }

   return( self );
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
   return( [_object methodSignatureForSelector: aSelector] );
}


- (void)forwardInvocation:(NSInvocation *)anInvocation
{
   [anInvocation setTarget:_object];
   [_cnx sendInvocation:anInvocation inThread:!_inThread];
}

@end

// Message ids used to switch state
#define InvocationMessage 100
#define InvocationEnd     101
#define QueueFreed        102

/*!
 * @abstract Private part of the class
 */
@interface LynkeosThreadConnection(Private)
/*!
 * @abstract Delegate called when a message is received on our port
 * @param portMessage The received message
 */
- (void) handlePortMessage:(NSPortMessage*)portMessage;
/*!
 * @abstract Handle retransmission timeout
 * @param timer The retransmission timer
 */
- (void) handleQueueTimer:(NSTimer*)timer ;
/*!
 * @abstract Try to send second level queue messages in the port
 * @param endPoint The endpoint to process
 */
- (void) handleQueue:(LynkeosThreadCnxEnd*)endPoint ;
@end

// Mach port handling: strategy without queue
static BOOL sendInMachPort_WithoutQueue( NSPortMessage *message,
                                         id cnx,
                                         LynkeosThreadCnxEnd *sendPoint,
                                         NSInvocation *inv )
{
   while( ![message sendBeforeDate:
                        [NSDate dateWithTimeIntervalSinceNow:K_QUEUE_TIMEOUT]] )
      ;
   return( YES );
}

// Mach port handling: strategy with queue
static BOOL sendInMachPort_WithQueue( NSPortMessage *message,
                                      id cnx,
                                      LynkeosThreadCnxEnd *sendPoint,
                                      NSInvocation *inv )
{
   BOOL sent = ( (sendPoint->_state & WaitingQueue) == InvocationIdle
                 && [message sendBeforeDate:[NSDate date]] );
   if ( !sent )
   {
      // The port is full, use the second level queue
      if ( debug >= K_QUEUE_DEBUG_LEVEL )
         NSLog( @"Forward : enqueuing %s", sel_getName([inv selector]) );
      // Arm a timer for trying periodically to empty the queue
      [[NSRunLoop currentRunLoop] addTimer:
         [NSTimer timerWithTimeInterval:K_QUEUE_TIMEOUT
                                 target:cnx
                               selector:@selector(handleQueueTimer:)
                               userInfo:sendPoint
                                repeats:NO]
                                   forMode:NSDefaultRunLoopMode];
      // Avoid to enqueue in a full queue
      while ( [sendPoint->_queue queueFull] )
      {
         if ( debug >= K_QUEUE_DEBUG_LEVEL )
            NSLog( @"Forward : Queue full, waiting" );
         [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
              beforeDate:[NSDate dateWithTimeIntervalSinceNow:K_QUEUE_TIMEOUT]];
      }
      // Enqueue now
      sendPoint->_state |= WaitingQueue;
      [sendPoint->_queue queueMessage:message];
   }

   return( sent );
}

@implementation LynkeosThreadConnection(QueueMgt)

- (void) sendInvocation:(NSInvocation*)inv inThread:(BOOL)inThread
{
   BOOL sync = ![[inv methodSignature] isOneway];
   LynkeosThreadCnxEnd *sendPoint =
                     _endPoint[inThread ? K_MAIN_ENDPOINT : K_THREAD_ENDPOINT ];
   LynkeosThreadCnxEnd *recvPoint =
                     _endPoint[inThread ? K_THREAD_ENDPOINT : K_MAIN_ENDPOINT ];

   // Retain the arguments because they may be autoreleased before invovation
   // in the thread
   [inv retainArguments];

   if ( ! sync )
      // Retain the invocation because it will be released by the caller
      // and will not be retained by the port message (cf. "by address")
      [inv retain];

   // Send the invocation by address through the port
   NSPortMessage* messageObj =
      [[NSPortMessage alloc] initWithSendPort:sendPoint->_port
                                  receivePort:recvPoint->_port
                                   components:
                  [NSArray arrayWithObject:
                     [NSData dataWithBytes:&inv length:sizeof(NSInvocation*)]]];
   [messageObj setMsgid:InvocationMessage];

   // Prepare synchronous calls
   if ( sync )
      sendPoint->_state |= WaitingInvocationEnd;

   // Send with the selected strategy
   if ( _sendInMachPort( messageObj, self, sendPoint, inv ) )
   {
      [sendPoint adjustMessageCount:1];
      if ( debug >= K_FULL_DEBUG_LEVEL )
         NSLog( @"Forward : sent %s", sel_getName([inv selector]) );
   }

   // Wait synchronous call end
   if ( sync )
   {
      if ( debug >= K_FULL_DEBUG_LEVEL )
         NSLog( @"Forward : Sync call waiting for end" );
      while ( sendPoint->_state != InvocationIdle )
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                     beforeDate:[NSDate distantFuture]];
      if ( debug >= K_FULL_DEBUG_LEVEL )
         NSLog( @"Forward : Sync call ended" );
   }
}
@end

@implementation LynkeosThreadConnection(Private)
- (void)handlePortMessage:(NSPortMessage *)portMessage
{
   switch( [portMessage msgid] )
   {
      case InvocationMessage:
      {
         NSPortMessage *reply;
         NSInvocation *inv;
         [[[portMessage components] objectAtIndex:0] getBytes:&inv
                                                  length:sizeof(NSInvocation*)];
         BOOL sync = ![[inv methodSignature] isOneway];
         LynkeosThreadCnxEnd* recvPoint = 
            ([portMessage sendPort] == _endPoint[K_MAIN_ENDPOINT]->_port ?
             _endPoint[K_THREAD_ENDPOINT] : _endPoint[K_MAIN_ENDPOINT] );

         if ( (recvPoint->_state & WaitingQueue) != InvocationIdle )
         {
            // We extracted one message from the port, restart the sender
            reply = [[NSPortMessage alloc] initWithSendPort:
                                                       [portMessage sendPort]
                                                receivePort:
                                                       [portMessage receivePort]
                                                 components:nil];
            [reply setMsgid:QueueFreed];
            if ( ![reply sendBeforeDate:[NSDate date]]
                 && debug >= K_QUEUE_DEBUG_LEVEL )
               NSLog( @"Failed to restart sender thread after queue full,"
                      " it will restart itself on timeout" );
         }

         [inv invoke];
         [recvPoint adjustMessageCount:-1];
         if ( debug >= K_FULL_DEBUG_LEVEL )
            NSLog( @"Handle  : %s", sel_getName([inv selector]) );

         if ( sync )
         {
            // Send the reply 
            reply = [[NSPortMessage alloc] initWithSendPort:
                                                       [portMessage sendPort]
                                                receivePort:
                                                       [portMessage receivePort]
                                                 components:nil];
            [reply setMsgid:InvocationEnd];
            while ( ![reply sendBeforeDate:
                       [NSDate dateWithTimeIntervalSinceNow:K_QUEUE_TIMEOUT]] )
            {
               if ( debug >= K_QUEUE_DEBUG_LEVEL )
                  NSLog( @"Failed to reply to a synchronous call, retrying..." );
            }
            if ( debug >= K_FULL_DEBUG_LEVEL )
               NSLog( @"Handle  : Sync call reply" );
         }
         else
            // Release async invocations here
            [inv release];
      }
      break;

      case InvocationEnd:
      {
         LynkeosThreadCnxEnd* sendPoint = 
            ([portMessage sendPort] == _endPoint[K_MAIN_ENDPOINT]->_port ?
             _endPoint[K_MAIN_ENDPOINT] : _endPoint[K_THREAD_ENDPOINT] );

         NSAssert1( (sendPoint->_state & WaitingInvocationEnd) != InvocationIdle,
                   @"Invocation end in unexpected state %d", sendPoint->_state );
         sendPoint->_state &= ~WaitingInvocationEnd;
      }
      break;

      case QueueFreed:
      {
         LynkeosThreadCnxEnd* sendPoint = 
            ([portMessage sendPort] == _endPoint[K_MAIN_ENDPOINT]->_port ?
             _endPoint[K_MAIN_ENDPOINT] : _endPoint[K_THREAD_ENDPOINT] );
         if ( (sendPoint->_state & WaitingQueue) == InvocationIdle
              && debug >= K_QUEUE_DEBUG_LEVEL)
            NSLog( @"Queue freed message in unexpected state %d",
                   sendPoint->_state );
         else
            [self handleQueue:sendPoint];
      }
      break;

      default:
         NSAssert1( NO, @"Unknown thread message id %d", [portMessage msgid] );
         break;
   }
}

- (void) handleQueueTimer:(NSTimer*)timer
{
   if ( debug >= K_QUEUE_DEBUG_LEVEL )
      NSLog( @"Forward : timeout" );
   [self handleQueue:[timer userInfo]];
}

- (void) handleQueue:(LynkeosThreadCnxEnd*)endPoint
{
   NSPortMessage *msg = [endPoint->_queue firstMessage];

   if ( msg != nil )
   {
      if ( [msg sendBeforeDate:[NSDate date]] )
      {
         [endPoint adjustMessageCount:1];
         [endPoint->_queue dequeueMessage];
         if ( debug >= K_FULL_DEBUG_LEVEL )
         {
            NSInvocation *inv;
            [[[msg components] objectAtIndex:0] getBytes:&inv
                                                  length:sizeof(NSInvocation*)];
            NSLog( @"Forward : dequeuing %s", sel_getName([inv selector]) );
         }

      }

      if ( [endPoint->_queue queueEmpty] )
         endPoint->_state &= ~WaitingQueue;

      else
         // Rearm the timer
         [[NSRunLoop currentRunLoop] addTimer:
            [NSTimer timerWithTimeInterval:K_QUEUE_TIMEOUT
                                    target:self
                                  selector:@selector(handleQueueTimer:)
                                  userInfo:endPoint
                                   repeats:NO]
                                      forMode:NSDefaultRunLoopMode];
   }
}
@end

@implementation LynkeosThreadConnection

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _endPoint[K_MAIN_ENDPOINT] = nil;
      _endPoint[K_THREAD_ENDPOINT] = nil;
      _rootObject = nil;
      _rootProxy = nil;
      _sendInMachPort = NULL;
      debug = [[NSUserDefaults standardUserDefaults] integerForKey:
                                                      @"ThreadConnectionDebug"];
   }

   return( self );
}

- (void) dealloc
{
   // Wait first for processing of all messages
   while ( _endPoint[K_MAIN_ENDPOINT]->_messageCount != 0
           || _endPoint[K_THREAD_ENDPOINT]->_messageCount != 0 )
      [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                               beforeDate:
                         [NSDate dateWithTimeIntervalSinceNow:K_QUEUE_TIMEOUT]];

   if ( _endPoint[K_MAIN_ENDPOINT] != nil )
   {
      if ( _endPoint[K_MAIN_ENDPOINT]->_port != nil )
         [[NSRunLoop currentRunLoop] removePort:_endPoint[K_MAIN_ENDPOINT]->_port
                                        forMode:NSDefaultRunLoopMode];
      [_endPoint[K_MAIN_ENDPOINT] release];
   }
   if ( _endPoint[K_THREAD_ENDPOINT] != nil )
      [_endPoint[K_THREAD_ENDPOINT] release];

   if ( _rootObject != nil )
      [_rootObject release];
   if ( _rootProxy != nil )
      // The proxy is aggregated to us
      [_rootProxy dealloc];

   [super dealloc];
}

- (NSPort*) mainPort { return _endPoint[K_MAIN_ENDPOINT]->_port; }

- (NSPort*)threadPort { return _endPoint[K_THREAD_ENDPOINT]->_port; }

- (BOOL) connectionIdle
{
   return( _endPoint[K_MAIN_ENDPOINT]->_messageCount == 0
           && _endPoint[K_THREAD_ENDPOINT]->_messageCount == 0 );
}

- (void) setRootObject:(id)anObject
{
   NSAssert(_rootObject == nil,@"Forbidden change of connection root object");
   _rootObject = [anObject retain];
}

- (NSProxy*) proxyForObject:(id)object inThread:(BOOL)inThread
{
   return( [[[MyThreadProxy alloc] initWithObject:object cnx:self
                                         inThread:inThread] autorelease]);
}

- (NSProxy*) rootProxy
{
   NSAssert( _rootObject != nil, @"Call to rootProxy without root object" );
   if ( _rootProxy == nil )
   {
      _rootProxy = [[self proxyForObject:_rootObject inThread:NO] retain];
      // Register the port 
      [[NSRunLoop currentRunLoop] addPort:_endPoint[K_THREAD_ENDPOINT]->_port
                                  forMode:NSDefaultRunLoopMode];
      // And register that we are the connection with the main thread
      NSMutableDictionary *dict = [[NSThread currentThread] threadDictionary];
      [dict setObject:self forKey:MyMainThreadConnection];
   }
   return( _rootProxy );
}

+ (void) performSelectorOnMainThread:(SEL)sel forObject:(NSObject*)target
                             withArg:(id)arg
{
   LynkeosThreadConnection* cnx =
      [[[NSThread currentThread] threadDictionary] objectForKey:
                                                        MyMainThreadConnection];
   NSAssert( cnx != nil, @"no connection in thread" );

   NSMethodSignature* sig = [target methodSignatureForSelector:sel];
   NSInvocation* inv = [NSInvocation invocationWithMethodSignature:sig];
   [inv setSelector:sel];
   [inv setTarget:target];
   if ( arg != nil )
      [inv setArgument:&arg atIndex:2];

   [cnx sendInvocation:inv inThread:YES];
}


- (id)initWithMainPort:(NSPort*)mainPort threadPort:(NSPort*)threadPort
             queueSize:(int)queueSize
{
   if ( (self = [self init]) != nil )
   {
      if ( queueSize == 0 )
         _sendInMachPort = sendInMachPort_WithoutQueue;
      else
         _sendInMachPort = sendInMachPort_WithQueue;

      _endPoint[K_MAIN_ENDPOINT] =
             [[LynkeosThreadCnxEnd alloc] initWithPort:mainPort queueSize:queueSize];
      _endPoint[K_THREAD_ENDPOINT] =
           [[LynkeosThreadCnxEnd alloc] initWithPort:threadPort queueSize:queueSize];

      [mainPort setDelegate:self];
      [threadPort setDelegate:self];

      // Install the port as an input source on the current run loop
      // (creator thread).
      [[NSRunLoop currentRunLoop] addPort:_endPoint[K_MAIN_ENDPOINT]->_port
                                  forMode:NSDefaultRunLoopMode];
      // and also for event tracking in the main thread
      [[NSRunLoop currentRunLoop] addPort:_endPoint[K_MAIN_ENDPOINT]->_port
                                  forMode:NSEventTrackingRunLoopMode];
   }

   return( self );
}

- (id)initWithMainPort:(NSPort*)mainPort threadPort:(NSPort*)threadPort
{
   return( [self initWithMainPort:mainPort threadPort:threadPort queueSize:0] );
}
@end
