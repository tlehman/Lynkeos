//
//  Lynkeos
//  $Id: LynkeosProcessingParameterMgr.m 498 2010-12-29 15:46:09Z j-etienne $
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
#include <errno.h>

#include <objc/objc-runtime.h>
#include "LynkeosThreadConnection.h"
#include "LynkeosProcessingParameterMgr.h"

// These notification keys are defined here to avoid a dependency on MyDocument
NSString * const LynkeosItemChangedNotification = @"LynkeosItemChanged";
NSString * const LynkeosUserInfoItem = @"item";

//! Global lock to protect dictionary and rw lock creation
static NSLock *paramLock = nil;

@implementation LynkeosProcessingParameterMgr

+ (void) initialize
{
   paramLock = [[NSLock alloc] init];
}

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _parent = nil;
      _document = nil;
      _parametersDict = nil;
      _mainThread = [NSThread currentThread];
   }

   return( self );
}

- (id) initWithParent: (LynkeosProcessingParameterMgr*)parent
{
   if ( (self = [self init]) != nil )
      _parent = [parent retain];

   return( self );
}

- (id) initWithDocument: (NSDocument <LynkeosDocument> *)document
{
   if ( (self = [self init]) != nil )
      _document = document;   // No retain, because we are agregated to the doc

   return( self );
}

- (void) dealloc
{
   if ( _parent != nil )
      [_parent release];
   if ( _parametersDict != nil )
   {
      [_parametersDict release];
      _parametersDict = nil;
      pthread_rwlock_destroy( &_lock );
   }
   [super dealloc];
}

- (NSDictionary*) getDictionary { return( _parametersDict ); }

- (void) setDictionary:(NSDictionary*)dict
{
   int err;

   if ( _parametersDict == nil && dict != nil )
   {
      [paramLock lock];
      err = pthread_rwlock_init( &_lock, NULL );
      [paramLock unlock];
      NSAssert1( err == 0, @"Failed to create the parameters RW lock : %s",
                 strerror(errno) );
   }

   if ( _parametersDict != nil )
   {
      [_parametersDict release];
      _parametersDict = nil;
   }

   if ( dict != nil )
      _parametersDict =
                   [[NSMutableDictionary dictionaryWithDictionary:dict] retain];
}

- (oneway void) notifyItemModification:(id)item
{
   // Always notify in the main thread
   if ( [NSThread currentThread] != _mainThread )
   {
      NSObject* target = (_parent != nil ? _parent : self);
      [LynkeosThreadConnection performSelectorOnMainThread:
                                              @selector(notifyItemModification:)
                                            forObject:target
                                              withArg:item];
   }
   else
   {
      if ( _parent != nil )
         // Propagate up the chain
         [_parent notifyItemModification:item];
      else
      {
         // We are at the top : notify of the change
         [[NSNotificationCenter defaultCenter] postNotificationName:
                                                  LynkeosItemChangedNotification
                                                          object:_document
                                                        userInfo:
                                         [NSDictionary dictionaryWithObject:item
                                                   forKey:LynkeosUserInfoItem]];
         // To be deleted when all notifiers will implement undo
         if ( ![[_document undoManager] isUndoing]
              && ![_document isDocumentEdited] )
            [_document updateChangeCount:NSChangeDone];
      }
   }
}

- (id <LynkeosProcessingParameter>) getProcessingParameterWithRef:(NSString*)ref 
                                             forProcessing:(NSString*)processing
                                                             goUp:(BOOL)goUp
{
   int err;
   id param = nil;

   if ( _parametersDict != nil )
   {
      // Nil is not authorized as an NSDictionary key
      NSString *processKey =
                        (processing == nil ? @"LynkeosNilProcess" : processing);

      // Get exclusive read access
      err = pthread_rwlock_rdlock( &_lock );
      NSAssert1( err == 0, @"Failed to lock the parameters for reading : %s",
                 strerror(errno) );

      NSDictionary *processDict = [_parametersDict objectForKey:processKey];

      if ( processDict != nil )
         param = [processDict objectForKey:ref];

      err = pthread_rwlock_unlock( &_lock );
      NSAssert1( err == 0, @"Failed to unlock the parameters : %s",
                 strerror(errno) );
   }

   // Forward search to container if needed
   if ( param == nil && _parent != nil && goUp )
      param = [_parent getProcessingParameterWithRef:ref 
                                       forProcessing:processing goUp:YES];

   return( param );
}

- (void) setProcessingParameter:(id <LynkeosProcessingParameter>)parameter
                        withRef:(NSString*)ref 
                  forProcessing:(NSString*)processing
{
   int err;

   if ( _parametersDict == nil )
   {
      [paramLock lock];
      err = pthread_rwlock_init( &_lock, NULL );
      if ( err == 0 )
         _parametersDict = [[NSMutableDictionary dictionary] retain];
      [paramLock unlock];
      NSAssert1( err == 0, @"Failed to create the parameters RW lock : %s",
                 strerror(errno) );
   }

   // Nil is not authorized as an NSDictionary key
   NSString *processKey =
                        (processing == nil ? @"LynkeosNilProcess" : processing);

   // Get exclusive write access
   err = pthread_rwlock_wrlock( &_lock );
   NSAssert1( err == 0, @"Failed to lock the parameters for writing : %s",
              strerror(errno) );

   NSMutableDictionary *processDict = [_parametersDict objectForKey:processKey];

   if ( processDict == nil )
   {
      // Create a fresh one
      processDict = [NSMutableDictionary dictionary];
      [_parametersDict setObject:processDict forKey:processKey];
   }

   // setValue will delete the entry if parameter is nil,
   // if the entry already exists, the parameter replaces the previous one.
   [processDict setValue:parameter forKey:ref];

   err = pthread_rwlock_unlock( &_lock );
   NSAssert1( err == 0, @"Failed to unlock the parameters : %s",
              strerror(errno) );
}

@end
