//
//  Lynkeos
//  $Id: MyThreadConnectionTest.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Mar 3 2008.
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

#include <time.h>

#include "MyThreadConnectionTest.h"

static BOOL beforeCall = NO, afterCall = NO, syncCalled = NO;

@interface ThreadedTester: NSObject
{
   BOOL _ended;
   NSProxy* _proxy;
   id _testCase;
}

+ (void) startTesterWithConnection:(LynkeosThreadConnection*)cnx ;

- (id) initWithConnection:(LynkeosThreadConnection*)cnx ;
- (void) mainLoop ;

- (oneway void) sendMessages:(int)n ;
- (oneway void) sendSyncMessage ;
- (oneway void) sendOnMainThread:(SEL)sel forObject:(NSObject*)obj ;
- (oneway void) endThread ;
@end

@interface MyThreadConnectionTest(Thread)
- (oneway void) threadStarted:(ThreadedTester*)tester ;
- (oneway void) processMessage ;
- (void) processSync ;
@end

@interface MainThreadTester : NSObject
{
@public
   BOOL _wasCalledOnMainThread;
   NSThread* _mainThread;
}

- (oneway void) mainThreadCall ;
@end

@implementation ThreadedTester
+ (void) startTesterWithConnection:(LynkeosThreadConnection*)cnx
{
   NSAutoreleasePool *pool;
   NSPort *rxPort;
   ThreadedTester *tester;

   pool = [[NSAutoreleasePool alloc] init];

   rxPort = [cnx threadPort];
   // Install the port as an input source on the current run loop.
   [[NSRunLoop currentRunLoop] addPort:rxPort
                               forMode:NSDefaultRunLoopMode];

   tester = [[self alloc] initWithConnection:cnx];

   [tester mainLoop];

   while ( ![cnx connectionIdle] )
      [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                               beforeDate:
       [NSDate dateWithTimeIntervalSinceNow:0.2]];

   [tester release];

   [pool release];
}

- (id) initWithConnection:(LynkeosThreadConnection*)cnx
{
   if ( (self = [self init]) != nil )
   {
      _ended = NO;
      _testCase = [cnx rootProxy];
      _proxy = [[cnx proxyForObject:self inThread:YES] retain];
      [_testCase threadStarted:(ThreadedTester*)_proxy];
   }
   return( self );
}

- (void) dealloc
{
   [_proxy release];
   [super dealloc];
}

- (void) mainLoop
{
   NSRunLoop* runLoop = [NSRunLoop currentRunLoop];

   while( ! _ended )
   {
      NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

      [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];

      [pool release];
   }
}

- (oneway void) sendMessages:(int)n
{
   int i;
   for( i = 0; i < n; i++ )
      [_testCase processMessage];
}

- (oneway void) sendSyncMessage
{
   beforeCall = YES;
   [_testCase processSync];
   afterCall = YES;
}

- (oneway void) sendOnMainThread:(SEL)sel forObject:(NSObject*)obj
{
   [LynkeosThreadConnection performSelectorOnMainThread:sel forObject:obj
                                           withArg:nil];
}

- (oneway void) endThread
{
   _ended = YES;
}
@end

@implementation MainThreadTester
- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _mainThread = [NSThread currentThread];
      _wasCalledOnMainThread = NO;
   }

   return( self );
}

- (void) mainThreadCall
{
   NSThread *currThread = [NSThread currentThread];
   _wasCalledOnMainThread = (currThread == _mainThread);
}
@end

@implementation MyThreadConnectionTest(Thread)
- (oneway void) threadStarted:(ThreadedTester*)tester
{
   _threadedTester = tester;
}

- (oneway void) processMessage
{
   _messageCounter++;
}

- (void) processSync
{
   syncCalled = YES;
}
@end

@implementation MyThreadConnectionTest
+ (void) initialize
{
   [[NSUserDefaults standardUserDefaults] setInteger:2
                                              forKey:@"ThreadConnectionDebug"];
}

- (void) setUp
{
   _threadedTester = nil;
   _cnx = [[LynkeosThreadConnection alloc] initWithMainPort:[NSPort port]
                                            threadPort:[NSPort port]];
   [_cnx setRootObject:self];

   [NSThread detachNewThreadSelector:@selector(startTesterWithConnection:)
                            toTarget:[ThreadedTester class]
                          withObject:_cnx];
   while( _threadedTester == nil )
      [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                               beforeDate:[NSDate distantFuture]];
}

- (void) tearDown
{
   [_threadedTester endThread];
   _threadedTester = nil;
   while( ![_cnx connectionIdle] )
      [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                          beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
   [_cnx release];
}

- (void) testOneMessage
{
   NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
   _messageCounter = 0;
   [_threadedTester sendMessages:1];

   usleep( 10000 );
   STAssertEquals( _messageCounter, 0, @"Bad message count" );

   [runLoop runMode:NSDefaultRunLoopMode
         beforeDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
   STAssertEquals( _messageCounter, 1, @"Bad message count" );

   [runLoop runMode:NSDefaultRunLoopMode beforeDate:
                                    [NSDate dateWithTimeIntervalSinceNow:0.1]];
   STAssertEquals( _messageCounter, 1, @"Bad message count at end" );
}

- (void) testMachQueue
{
   NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
   _messageCounter = 0;
   [_threadedTester sendMessages:2];

   usleep( 15000 );
   STAssertEquals( _messageCounter, 0, @"Bad message count" );

   [runLoop runMode:NSDefaultRunLoopMode
         beforeDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
   STAssertEquals( _messageCounter, 1, @"Bad message count" );

   [runLoop runMode:NSDefaultRunLoopMode
         beforeDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
   STAssertEquals( _messageCounter, 2, @"Bad message count" );

   [runLoop runMode:NSDefaultRunLoopMode beforeDate:
                                     [NSDate dateWithTimeIntervalSinceNow:0.1]];
   STAssertEquals( _messageCounter, 2, @"Bad message count at end" );
}

- (void) testSecondLevelQueue
{
   int i;
   NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
   _messageCounter = 0;
   [_threadedTester sendMessages:12];

   usleep( 15000 );
   STAssertEquals( _messageCounter, 0, @"Bad message count" );

   for( i = 1; i <=  12; i++ )
   {
      [runLoop runMode:NSDefaultRunLoopMode
            beforeDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
      STAssertEquals( _messageCounter, i, @"Bad message count" );
   }

   [runLoop runMode:NSDefaultRunLoopMode beforeDate:
                                     [NSDate dateWithTimeIntervalSinceNow:0.1]];
   STAssertEquals( _messageCounter, 12, @"Bad message count at end" );
}

- (void) testSecondLevelQueueFull
{
   int i;
   NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
   _messageCounter = 0;
   [_threadedTester sendMessages:20];

   usleep( 15000 );
   STAssertEquals( _messageCounter, 0, @"Bad message count" );

   for( i = 1; i <=  20; i++ )
   {
      [runLoop runMode:NSDefaultRunLoopMode
            beforeDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
      STAssertEquals( _messageCounter, i, @"Bad message count" );
      usleep( 15000 );
   }

   [runLoop runMode:NSDefaultRunLoopMode beforeDate:
                                    [NSDate dateWithTimeIntervalSinceNow:0.1]];
   STAssertEquals( _messageCounter, 20, @"Bad message count at end" );
}

- (void) testSecondLevelQueueTimeout
{
   int i;
   NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
   _messageCounter = 0;
   [_threadedTester sendMessages:7];

   usleep( 50000 );
   STAssertEquals( _messageCounter, 0, @"Bad message count" );

   for( i = 1; i <=  7; i++ )
   {
      [runLoop runMode:NSDefaultRunLoopMode
            beforeDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
      STAssertEquals( _messageCounter, i, @"Bad message count" );
   }

   [runLoop runMode:NSDefaultRunLoopMode beforeDate:
                                    [NSDate dateWithTimeIntervalSinceNow:0.1]];
   STAssertEquals( _messageCounter, 7, @"Bad message count at end" );
}

- (void) testSynchronous
{
   NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
   beforeCall = NO;
   syncCalled = NO;
   afterCall = NO;
   [_threadedTester sendSyncMessage];

   usleep( 10000 );
   STAssertTrue( beforeCall, @"No synchronous call" );
   STAssertFalse( syncCalled, @"Early synchronous call" );
   STAssertFalse( afterCall, @"Early return of synchronous call" );

   [runLoop runMode:NSDefaultRunLoopMode
         beforeDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
   STAssertTrue( beforeCall, @"No synchronous call" );
   STAssertTrue( syncCalled, @"Synchronous call not performed" );

   usleep( 10000 );
   STAssertTrue( afterCall, @"No return of synchronous call" );
}

- (void) testMainThreadCall
{
   NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
   MainThreadTester* mainThreadTester =
                                  [[[MainThreadTester alloc] init] autorelease];

   [_threadedTester sendOnMainThread:@selector(mainThreadCall)
                           forObject:mainThreadTester];

   usleep( 10000 );
   STAssertFalse( mainThreadTester->_wasCalledOnMainThread,
                 @"Early call on main thread" );

   [runLoop runMode:NSDefaultRunLoopMode
         beforeDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
   STAssertTrue( mainThreadTester->_wasCalledOnMainThread,
                 @"No call on main thread" );
}
@end
