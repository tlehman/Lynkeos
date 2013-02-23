//
//  Lynkeos
//  $Id: MyProcessingThread.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun Nov 13 2005.
//  Copyright (c) 2005-2008. Jean-Etienne LAMIAUD
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

#include "MyDocument.h"
#include "MyProcessingThread.h"

NSString * const K_PROCESS_CONNECTION =     @"prCnx";
NSString * const K_PROCESS_CLASS_KEY =      @"prClass";
NSString * const K_PROCESS_ENUMERATOR_KEY = @"prEnum";
NSString * const K_PROCESS_ITEM_KEY =       @"prItem";
NSString * const K_PROCESS_PARAMETERS_KEY = @"param";

/*!
 * @abstract Private methods of MyProcessingThread class
 */
@interface MyProcessingThread(Private)

/*!
 * @abstract Thread controller initialization.
 * @param attributes Thread attributes in a dictionary
 * @param document The document which launch this thread.
 * @param cnx The connection with the main thread
 */
- (id) initWithAttributes: (NSDictionary*)attributes 
                 document: (MyDocument*)document
               connection: (LynkeosThreadConnection*)cnx;

/*!
 * @abstract Process all the items in the list
 * @discussion The loop exits when the last item is processed or if the main 
 *   thread stopped the processing.
 *
 *   The run loop is run at each iteration to allow inter-threads method call.
 *   The run loop is just queried for a pending inter-thread message.
 */
- (void) processList ;

@end

@implementation MyProcessingThread(Private)

- (id) initWithAttributes :(NSDictionary*)attributes 
                 document :(MyDocument*)document
                connection: (LynkeosThreadConnection*)cnx
{
   if ( (self = [self init]) != nil )
   {
      _document = document;
      _processEnded = NO;
      _itemList = [[attributes objectForKey:K_PROCESS_ENUMERATOR_KEY] retain];
      _item = [[attributes objectForKey:K_PROCESS_ITEM_KEY] retain];
      NSAssert( _itemList == nil || _item == nil,
                @"Cannot process a list and an item");

      _processingInstance =
         [[[attributes objectForKey:K_PROCESS_CLASS_KEY] alloc]
                  initWithDocument:document
                        parameters:
                              [attributes objectForKey:K_PROCESS_PARAMETERS_KEY]
                         precision:PROCESSING_PRECISION];
      _proxy = [[cnx proxyForObject:self inThread:YES] retain];
   }

   return( self );
}

- (void) processList
{
   // Create a run loop for this thread
   NSRunLoop* runLoop = [NSRunLoop currentRunLoop];

   if ( _item != nil )
   {
      @try
      {
         [_processingInstance processItem:_item];
      }
      @catch( NSException *e )
      {
         NSLog( @"*** Exception %@ raised in item processing thread: \"%@\"",
               [e name], [e reason] );
      }
   }

   else
   {
      while ( ! _processEnded )
      {
         NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

         @try
         {
            // Null timeout and process next item immediately after
            [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate date]];
            if ( ! _processEnded  )
            {
               id <LynkeosProcessableItem> item = [_itemList nextObject];

               if ( item == nil )
                  // Process is finished
                  [self stopProcessing];
               else
                  [_processingInstance processItem:item];         
            }
         }
         @catch( NSException *e )
         {
            NSLog( @"*** Exception %@ raised in list processing thread: \"%@\"",
                   [e name], [e reason] );
         }
         @finally
         {
            [pool release];
         }
      }
   }

   [_processingInstance finishProcessing];
   [_document processEnded:_proxy];
}

@end

@implementation MyProcessingThread

+ (void) threadWithAttributes:(NSDictionary*)attr
{
   NSAutoreleasePool *pool;
   NSPort *rxPort;
   LynkeosThreadConnection *cnx;
   MyProcessingThread *threadController;
   MyDocument *doc;

   pool = [[NSAutoreleasePool alloc] init];

   @try
   {
      cnx = [attr objectForKey:K_PROCESS_CONNECTION];
      rxPort = [cnx threadPort];
      // Install the port as an input source on the current run loop.
      [[NSRunLoop currentRunLoop] addPort:rxPort
                                  forMode:NSDefaultRunLoopMode];

      doc = (MyDocument*)[cnx rootProxy];
      {
         @try
         {
            threadController = [[self alloc] initWithAttributes:attr document:doc
                                                     connection:cnx];
         }
         @catch( NSException *e )
         {
            NSLog( @"*** Exception %@ raised in processing thread initialization:"
                  "\"%@\"",
                  [e name], [e reason] );
         }
      }

      if ( threadController != nil )
      {
         [doc processStarted:threadController->_proxy connection:cnx];

         [threadController processList];
      }
      else         // In case an exception was caught during controller init
      {
         [doc processStarted:nil connection:cnx];
         [doc processEnded:nil];
      }

      while ( ![cnx connectionIdle] )
         [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                  beforeDate:
                                       [NSDate dateWithTimeIntervalSinceNow:0.2]];

      if ( threadController != nil )
         [threadController release];
   }
   @catch( NSException *e )
   {
      NSLog( @"*** Exception %@ raised in processing thread :\"%@\"",
            [e name], [e reason] );
   }
   @finally
   {
      [pool release];
   }
}

- (oneway void) stopProcessing 
{
   _processEnded = YES;
}

- (void) dealloc
{
   [_processingInstance release];
   [_proxy release];
   [_itemList release];
   [_item release];
   [super dealloc];
}

@end
