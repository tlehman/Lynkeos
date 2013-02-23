//
//  Lynkeos 
//  $Id: MyDocument.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Thu Jul 29 2004.
//  Copyright (c) 2004-2008. Jean-Etienne LAMIAUD
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

#if !defined GNUSTEP
#include <IOKit/pwr_mgt/IOPMLib.h>
#include <IOKit/IOMessage.h>
#endif

#include "LynkeosThreadConnection.h"
#include "LynkeosFourierBuffer.h"
#include "LynkeosStandardImageBufferAdditions.h"
#include "LynkeosBasicAlignResult.h"
#include "MyCustomAlert.h"
#include "MyImageListWindow.h" // Only for allocation purpose

// Temporary includes to allow file format backward compatibility
#ifndef NO_FILE_FORMAT_COMPATIBILITY_CODE
#include "MyImageAnalyzer.h"
#include "MyImageStacker.h"
#endif

#include "MyDocument.h"

#include "MyDocumentData.h"
#include "MyGeneralPrefs.h"

// Needed for setting calibration frames align offset (it's a bad hack)
#include "MyImageAligner.h"

#define K_DOCUMENT_TYPE		@"Lynkeos project"

// A bad hack for relative URL resolution (until I find a better solution)
NSString *basePath = nil;

//==============================================================================
// Private part of MyDocument
//==============================================================================

/*!
 * @class ThreadControl
 * @abstract Structure used to keep track of spawned thread
 */
@interface ThreadControl : NSObject
{
   @public
   LynkeosThreadConnection*	_cnx;  //!< Connection to the thread
   id                   _threaded;     //!< Threaded object (proxy)
}
@end

@interface MyDocument(Private)
#if !defined GNUSTEP
- (void) allowSleep :(natural_t) messageType arg:(void*)messageArgument ;
#endif
- (void) finalizeMyDocument ;
- (void) startProcess: (Class) processingClass
       withEnumerator:(NSEnumerator*)enumerator
               orItem: (id <LynkeosProcessableItem>)item
           parameters: (id <NSObject>)params ;
- (BOOL) continueProcessing ;
@end

#if !defined GNUSTEP
static void MySleepCallBack(void * x, io_service_t y, natural_t messageType, 
                            void * messageArgument)
{
   [(MyDocument*)x allowSleep:messageType arg:messageArgument];
}
#endif

@implementation ThreadControl

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _cnx = nil;
      _threaded = nil;
   }
   return self;
}

- (void) dealloc
{
   [_cnx release];
   [super dealloc];
}

@end

@implementation MyDocument(Private)
#if !defined GNUSTEP
- (void) allowSleep :(natural_t) messageType arg:(void*)messageArgument
{
   switch ( messageType )
   {
      case kIOMessageSystemWillSleep:
         IOAllowPowerChange(_rootPort, (long)messageArgument);
         break;
      case kIOMessageCanSystemSleep:
         if( [_threads count] != 0 )
            IOCancelPowerChange(_rootPort, (long)messageArgument);
         else
            IOAllowPowerChange(_rootPort, (long)messageArgument);
         break;
      case kIOMessageSystemHasPoweredOn:
         break;
   }
}
#endif

- (void) finalizeMyDocument
{
   // Connect the parameters chain
   [_imageList setParametersParent:_parameters];
   [_darkFrameList setParametersParent:_parameters];
   [_flatFieldList setParametersParent:_parameters];

   // Initialize dark frame and flat field alignment to no offset
   LynkeosBasicAlignResult *r =
                           [[[LynkeosBasicAlignResult alloc] init] autorelease];
   [_darkFrameList setProcessingParameter:r withRef:LynkeosAlignResultRef 
                            forProcessing:LynkeosAlignRef];      
   [_flatFieldList setProcessingParameter:r withRef:LynkeosAlignResultRef 
                            forProcessing:LynkeosAlignRef];
   [self updateChangeCount:NSChangeCleared];
}

- (void) startProcess: (Class)processingClass
       withEnumerator: (NSEnumerator*)enumerator
               orItem: (id <LynkeosProcessableItem>)item
           parameters: (id <NSObject>)params
{
   u_char i, nListThreads;

   NSAssert( enumerator == nil || item == nil,
             @"Cannot start a process for a list AND an item" );
   NSAssert( enumerator != nil || item != nil,
             @"Cannot start a process for nothing" );

   NSAssert( [_threads count] == 0, 
             @"Trying to start a process while one is already running" );

   // Start the process according to user preferences
   nListThreads = 1;

   ParallelOptimization_t optim = [processingClass supportParallelization];

   if ( (optim & ListThreadsOptimizations) != 0 )
      // Parallel list processing
      nListThreads = numberOfCpus;
   FFTW_PLAN_WITH_NTHREADS( (optim & FFTW3ThreadsOptimization) != 0 ?
                            numberOfCpus : 1 );

   // Notify that the processing is starting
   _currentProcessingClass = processingClass;
   [_notifCenter postNotificationName: LynkeosProcessStartedNotification
                               object: self
                             userInfo:
      [NSDictionary dictionaryWithObject:_currentProcessingClass
                                  forKey:LynkeosUserInfoProcess]];

   // Create the required number of processing threaded object
   for( i = 0; i < nListThreads; i++ )
   {
      NSMutableDictionary *attrib = 
                                 [NSMutableDictionary dictionaryWithCapacity:4];

      ThreadControl *thr = [[[ThreadControl alloc] init] autorelease];
      [_threads addObject:thr];

      thr->_cnx =
               [[LynkeosThreadConnection alloc] initWithMainPort:[NSPort port]
                                                      threadPort:[NSPort port]];
      [thr->_cnx setRootObject:self];

      // Give attributes to the thread controller
      [attrib setObject:thr->_cnx forKey: K_PROCESS_CONNECTION];
      [attrib setObject:processingClass forKey: K_PROCESS_CLASS_KEY];
      if ( enumerator != nil )
         [attrib setObject:enumerator forKey: K_PROCESS_ENUMERATOR_KEY];
      if ( item != nil )
         [attrib setObject:item forKey: K_PROCESS_ITEM_KEY];
      if ( params != nil )
         [attrib setObject:params forKey:K_PROCESS_PARAMETERS_KEY];

      [NSThread detachNewThreadSelector:@selector(threadWithAttributes:)
                               toTarget:[MyProcessingThread class]
                             withObject:attrib];
   }
}

- (BOOL) continueProcessing
{
   _processedItem = nil;
   while( _processedItem == nil && _initialProcessEnum != nil )
   {
      if ( _initialProcessEnum != nil )
      {
         _processedItem = [_initialProcessEnum nextObject];
         if ( _processedItem == nil )
         {
            // No more items in the list, switch to the list itself
            _processedItem = _imageList;
            [_initialProcessEnum release];
            _initialProcessEnum = nil;
         }
      }

      // Check first if there is an image to process
      if ( [_processedItem imageSize].width != 0 )
      {
         // Launch the next processing for this item, if any
         LynkeosImageProcessingParameter *param =
                            [_processStackMgr getParameterForItem:
                                        (LynkeosProcessableImage*)_processedItem
                                                         andParam:nil];

         if ( param != nil )
            [self startProcess:[param processingClass]
                withEnumerator:nil orItem:_processedItem parameters:param];
         else
            // No more process to apply to this item
            _processedItem = nil;
      }
      else
         _processedItem = nil;

   }

   if ( _processedItem == nil && _isInitialProcessing )
   {
      [self updateChangeCount:NSChangeCleared];
      _isInitialProcessing = NO;
   }

   return( _processedItem != nil );
}
@end

@implementation MyDocument

//==============================================================================
// Initializers, creators and destructors
//==============================================================================
- (id)init
{
#if !defined GNUSTEP
   IONotificationPortRef  notify;
   io_object_t            anIterator;
#endif

   self = [super init];

   if (self)
   {
      _imageList = [[MyImageList imageListWithArray:nil] retain];
      _darkFrameList = [[MyImageList imageListWithArray:nil] retain];
      _flatFieldList = [[MyImageList imageListWithArray:nil] retain];
      _currentList = _imageList;
      _dataMode = ListData;
      _calibrationLock = [[MyCalibrationLock calibrationLock] retain];
      _windowSizes = nil;
      _myWindow = nil;

      _threads = [[NSMutableArray array] retain];
      _currentProcessingClass = nil;
      _processedItem = nil;
      _processStackMgr = [[ProcessStackManager alloc] init];
      _initialProcessEnum = nil;
      _isInitialProcessing = NO;
      _imageListSequenceNumber = 0;

      _notifCenter = [NSNotificationCenter defaultCenter];
      _notifQueue = [NSNotificationQueue defaultQueue];

#if !defined GNUSTEP
      _rootPort = IORegisterForSystemPower(self, &notify, MySleepCallBack, 
                                           &anIterator);

      if ( _rootPort == IO_OBJECT_NULL )
         NSLog(@"IORegisterForSystemPower failed");

      else
         CFRunLoopAddSource([[NSRunLoop currentRunLoop] getCFRunLoop],
                            IONotificationPortGetRunLoopSource(notify),
                            kCFRunLoopCommonModes);
#endif

      // Until Undo is better handled, limit to one undo
      [[self undoManager] setLevelsOfUndo:1];

      _parameters = [[LynkeosProcessingParameterMgr alloc] initWithDocument:self];

      [self finalizeMyDocument];
   }

   return self;
}

- (void) dealloc
{
   [_myWindow release];
   [_imageList release];
   [_darkFrameList release];
   [_flatFieldList release];
   [_calibrationLock release];
   [_processStackMgr release];

   [_windowSizes release];

   [_threads release];

   [_parameters release];

   [super dealloc];
}

//==============================================================================
// Document load and save
//==============================================================================
- (BOOL)saveToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName
 forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError
{
   // A bad hack for relative URL resolution (until I find a better solution)
    if ( saveOperation != NSAutosaveOperation )
      basePath = [[absoluteURL path] stringByDeletingLastPathComponent];
   else
      basePath = nil;

   BOOL res = [super saveToURL:absoluteURL ofType:typeName
              forSaveOperation:saveOperation error:outError];

   basePath = nil;

   return( res );
}

- (BOOL) readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName
              error:(NSError **)outError
{
   // The URLs of resouces inside the document are first read as absolute and a
   // try to resolve them as relative against the document base URL only happens
   // if the absolute URL read did fail.
   basePath = [[absoluteURL path] stringByDeletingLastPathComponent];

   NSFileWrapper *wrap =
          [[[NSFileWrapper alloc] initWithPath:[absoluteURL path]] autorelease];
   BOOL res = [self readFromFileWrapper:wrap ofType:typeName error:outError];

   basePath = nil;

   return( res );
}


- (NSData *)dataRepresentationOfType:(NSString *)aType
{
   MyDocumentDataV2 *myData;

   NSAssert( [aType isEqual:K_DOCUMENT_TYPE], @"Unknown type to export" );

   myData = [[[MyDocumentDataV2 alloc] init] autorelease];
   myData->_imageList = _imageList;
   myData->_darkFrameList = _darkFrameList;
   myData->_flatFieldList = _flatFieldList;
   myData->_windowSizes = [_myWindow windowSizes];
   myData->_parameters = [_parameters getDictionary];

   NSData *docData = [NSKeyedArchiver archivedDataWithRootObject:myData];

   basePath = nil;

   return( docData );
}

- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)aType
{
   @try
   {
      id myData;
      NSEnumerator* files;
      NSMutableArray* lostFiles;
      MyImageListItem* item;
      MyImageList *list;

      NSAssert( [aType isEqual:K_DOCUMENT_TYPE], @"Unknown type to import" );

      // Get document data from the file data
      myData = [NSKeyedUnarchiver unarchiveObjectWithData:data];

      if ( myData == nil )
         return( NO );

      if ( [myData isMemberOfClass:[MyDocumentDataV2 class]] )
      {
         MyDocumentDataV2 *myV2Data = (MyDocumentDataV2*)myData;

         if ( myV2Data->_formatRevision != K_DATA_REVISION )
            NSRunAlertPanel(NSLocalizedString(@"DeprecatedFormat",
                                              @"Deprecated format alert panel title"),
                            NSLocalizedString(@"DeprecatedFormatText",
                                              @"Deprecated format text"),
                            nil, nil, nil );

         [_imageList release];
         _imageList = myV2Data->_imageList;
         [_darkFrameList release];
         _darkFrameList = myV2Data->_darkFrameList;
         [_flatFieldList release];
         _flatFieldList = myV2Data->_flatFieldList;

         [_parameters setDictionary:myV2Data->_parameters];
         [myV2Data->_parameters release];
         _windowSizes = myV2Data->_windowSizes;
      }
      else if ( [myData isMemberOfClass:[MyDocumentDataV1 class]] )
      {
         // V1 file format : alert that it is now deprecated
         NSRunAlertPanel(NSLocalizedString(@"DeprecatedFormat",
                                        @"Deprecated format alert panel title"),
                         NSLocalizedString(@"DeprecatedFormatText",
                                           @"Deprecated format text"),
                         nil, nil, nil );
         [_imageList release];
         _imageList = ((MyDocumentDataV1*)myData)->_imageList;
         [_darkFrameList release];
         _darkFrameList = ((MyDocumentDataV1*)myData)->_darkFrameList;
         [_flatFieldList release];
         _flatFieldList = ((MyDocumentDataV1*)myData)->_flatFieldList;

         // Compatibility code
#ifndef NO_FILE_FORMAT_COMPATIBILITY_CODE
         if ( ((MyDocumentDataV1*)myData)->_monochromeFlat )
         {
            MyImageStackerParameters *stacker =
              [_flatFieldList getProcessingParameterWithRef:
                                                     myImageStackerParametersRef
                                               forProcessing:myImageStackerRef];
            if ( stacker == nil )
               stacker = [[[MyImageStackerParameters alloc] init] autorelease];
            stacker->_monochromeStack =
                                   ((MyDocumentDataV1*)myData)->_monochromeFlat;
            [_flatFieldList setProcessingParameter:stacker
                                        withRef:myImageStackerParametersRef
                                  forProcessing:myImageStackerRef];
         }
         MyImageAnalyzerParameters *analysis =
          [_imageList getProcessingParameterWithRef:myImageAnalyzerParametersRef
                                      forProcessing:myImageAnalyzerRef];
         if ( analysis == nil )
            analysis = [[[MyImageAnalyzerParameters alloc] init] autorelease];
         analysis->_method = ((MyDocumentDataV1*)myData)->_analysisMethod;
         [_imageList setProcessingParameter:analysis
                                    withRef:myImageAnalyzerParametersRef
                              forProcessing:myImageAnalyzerRef];
#endif
      }
      else
      {
         NSLog( @"Unknown file format on load : %@", [myData description] );
         return( NO );
      }
      _currentList = _imageList;
      [self finalizeMyDocument];

      // Check erroneous items
      lostFiles = [NSMutableArray array];
      for ( list = _imageList; list != nil ; )
      {
         files = [[list imageArray] objectEnumerator];
         while ( (item = [files nextObject]) != nil )
         {
            if ( [item getURL] != nil && [item getReader] == nil )
               [lostFiles addObject:item];
         }

         if ( list == _imageList )
            list = _darkFrameList;
         else if ( list == _darkFrameList )
            list = _flatFieldList;
            else
         list = nil;
      }

      // If some items could not be initialized, remove them from the document
      if ( [lostFiles count] != 0 )
      {
         NSMutableString* message = [NSMutableString stringWithString:
                                                     NSLocalizedString(
                                                        @"FilesNotFound",
                               @"First line of lost file alert panel message")];
         files = [lostFiles objectEnumerator];
         while ( (item = [files nextObject]) != nil )
         {
            [message appendFormat:@"\n%@",
                              [[[item getURL] absoluteString]
                                   stringByReplacingPercentEscapesUsingEncoding:
                                                         NSUTF8StringEncoding]];
            if ( [[_imageList imageArray] containsObject:item] )
               [_imageList deleteItem:item];
            else if ( [[_darkFrameList imageArray] containsObject:item] )
               [_darkFrameList deleteItem:item];
            else if ( [[_flatFieldList imageArray] containsObject:item] )
               [_flatFieldList deleteItem:item];
         }
         [MyCustomAlert runAlert:NSLocalizedString(@"LostFile",
                                                @"Lost file alert panel title")
                        withText:message];
      }

      // Update the calibrationLock and reject non compliant files
      files = [[_imageList imageArray] objectEnumerator];
      while ( (item = [files nextObject]) != nil )
      {
         if ( ![_calibrationLock addImageItem: item] )
         {
            // This should not happen (whatever the user do), so log it
            NSLog( @"CalibrationLock addImageItem failed for %@ , file discarded",
                   [[item getURL] absoluteString] );
            [_imageList deleteItem: item];
         }
      }

      for ( list = _darkFrameList; 
            list != nil ; 
            list = (list == _darkFrameList ? _flatFieldList : nil) )
      {
         files = [[list imageArray] objectEnumerator];
         while ( (item = [files nextObject]) != nil )
         {
            if ( ![_calibrationLock addCalibrationItem: item] )
            {
               // This should not happen (whatever the user do), so log it
               NSLog( @"CalibrationLock addCalibrationItem failed for %@ ,"
                      "file discarded", 
                      [[item getURL] absoluteString] );
               [list deleteItem: item];
            }
         }
      }

      // Notify of the load
      [[NSNotificationCenter defaultCenter] postNotificationName:
                                              LynkeosDocumentDidLoadNotification
                                                          object:self];

      // Start saved processing, if any
      _initialProcessEnum = [[_imageList imageEnumerator] retain];
      _isInitialProcessing = YES;
      [self continueProcessing];

      return ( YES );
   }
   @catch( NSException *e )
   {
      NSLog( @"Load aborted because of exception %@ :\n%@",
             [e name], [e reason] );
      return( NO );
   }
   return( NO );
}

//==============================================================================
// GUI control
//==============================================================================
- (void) makeWindowControllers
{
   _myWindow = [[MyImageListWindow alloc] init];
   [self addWindowController:_myWindow];

   // A processing may have been started before creating the window controller
   if ( _currentProcessingClass != nil )
      // Therefore, notify again (but let the window controller start)
      [[NSNotificationQueue defaultQueue] enqueueNotification:
         [NSNotification notificationWithName:LynkeosProcessStartedNotification
                                       object:self
                                    userInfo:
                     [NSDictionary dictionaryWithObject:_currentProcessingClass
                                                 forKey:LynkeosUserInfoProcess]]
                                                 postingStyle:NSPostWhenIdle];
}

//==============================================================================
// Read accessors
//==============================================================================
- (id <LynkeosImageList>) imageList { return( _imageList ); }
- (id <LynkeosImageList>) darkFrameList { return( _darkFrameList ); }
- (id <LynkeosImageList>) flatFieldList { return( _flatFieldList ); }
- (id <LynkeosImageList>) currentList { return( _currentList ); }
- (LynkeosIntegerSize) calibrationSize 
                              { return( [_calibrationLock calibrationSize] ); }
- (NSDictionary*) savedWindowSizes { return( _windowSizes ); }

- (ListMode_t) listMode ;
{
   if ( _currentList == _imageList )
      return( ImageMode );
   else if ( _currentList == _flatFieldList )
      return( FlatFieldMode );
   else if ( _currentList == _darkFrameList )
      return( DarkFrameMode );
   else
      NSAssert( NO, @"Inconsistent current list");

   return( 0 );
}

- (DataMode_t) dataMode { return( _dataMode ); }

//==============================================================================
// Actions
//==============================================================================
- (void) setListMode :(ListMode_t)mode
{
   MyImageList *oldList = _currentList;

   switch( mode )
   {
      case ImageMode:
         _currentList = _imageList;
         break;
      case FlatFieldMode:
         _currentList = _flatFieldList;
         break;
      case DarkFrameMode:
         _currentList = _darkFrameList;
         break;
      default :
         NSAssert1( NO, @"Invalid list mode %d", mode );
         break;
   }

   if ( _currentList != oldList )
      [[NSNotificationCenter defaultCenter] postNotificationName:
                                                   LynkeosListChangeNotification
                                                          object:self];
}

- (void) setDataMode:(DataMode_t)mode
{
   if ( mode != _dataMode )
   {
      _dataMode = mode;
      [[NSNotificationCenter defaultCenter] postNotificationName:
                                               LynkeosDataModeChangeNotification
                                                          object:self];
   }
}

- (void) addEntry :(MyImageListItem*)item
{
   NSUndoManager *undo = [self undoManager];
   MyImageListItem *parent = [item getParent];

   if ( parent != nil )
      // This add is actually an undo inside a movie
      [parent addChild :item];

   else
   {
      if ( _currentList == _imageList )
      {
         // Check for possible add of an image item
         if ( ! [_calibrationLock addImageItem:item] )
         {
            NSRunAlertPanel(NSLocalizedString(@"CannotAddTitle",
                                              @"Cannot add alert panel title"),
                            NSLocalizedString(@"CannotAddText",
                                              @"Cannot add alert panel text"),
                            nil, nil, nil );
            return;
         }
      }
      else
      {
         // Check for possible add of a calibration item
         if ( ! [_calibrationLock addCalibrationItem:item] )
         {
            NSRunAlertPanel(NSLocalizedString(@"CannotLockTitle",
                                              @"Cannot lock alert panel title"),
                            NSLocalizedString(@"CannotLockText",
                                              @"Cannot lock alert panel text"),
                            nil, nil, nil );
            return;
         }
      }

      // OK add it
      [_currentList addItem: item];
   }

   // Notify with coalescence of multiple adds
   [_notifQueue enqueueNotification:
               [NSNotification notificationWithName:LynkeosItemAddedNotification
                                             object:self]
                       postingStyle:NSPostASAP];

   [undo registerUndoWithTarget:self
                       selector:@selector(deleteEntry:)
                         object:item];
   if ( [undo isUndoing] )
      [undo setActionName: 
                     NSLocalizedString(@"Delete image",@"Delete image action")];
   else
      [undo setActionName:NSLocalizedString(@"Add image",@"Add image action")];
}

- (void) deleteEntry :(MyImageListItem*)item
{
   NSUndoManager *undo = [self undoManager];

   [undo registerUndoWithTarget:self
                       selector:@selector(addEntry:)
                         object:item]; 
   if ( [undo isUndoing] )
      [undo setActionName:NSLocalizedString(@"Add image",@"Add image action")];
   else
      [undo setActionName:
                     NSLocalizedString(@"Delete image",@"Delete image action")];

   [_currentList deleteItem:item];

   // Remove it from the calibration lock
   [_calibrationLock removeItem:item];

   // Notify with coalescence of multiple removings
   [_notifQueue enqueueNotification:
             [NSNotification notificationWithName:LynkeosItemRemovedNotification
                                           object:self]
                        postingStyle:NSPostASAP];
}

- (void) changeEntrySelection :(MyImageListItem*)item value:(BOOL)v
{
   if ( [_currentList changeItemSelection:item value:v] )
   {
      [self updateChangeCount:NSChangeDone];
      [_notifCenter postNotificationName: LynkeosItemChangedNotification
                                  object:self
                                userInfo:
                       [NSDictionary dictionaryWithObject:item
                                                   forKey:LynkeosUserInfoItem]];
   }
}

// Process management
- (void) startProcess: (Class) processingClass 
       withEnumerator: (NSEnumerator*)enumerator
           parameters:(id <NSObject>)params
{
   // Prepare to detect a change in the original image, even though we don't
   // know if the image list is being processed
   _imageListSequenceNumber = [_imageList originalImageSequence];
   _processedItem = nil;
   [self startProcess:processingClass withEnumerator:enumerator orItem:nil
           parameters:params];
}

- (void) startProcess: (Class) processingClass
              forItem: (LynkeosProcessableImage*)item
           parameters: (LynkeosImageProcessingParameter*)params 
{
   LynkeosImageProcessingParameter *procParam;

   // Save the processing class in  the parameter
   [params setProcessingClass:processingClass];

   // Manage the stack and get the parameter to process first
   procParam = [_processStackMgr getParameterForItem:
                                                  (LynkeosProcessableImage*)item
                                            andParam:params];

   // And launch that process
   if ( procParam != nil )
   {
      NSAssert( ![procParam isExcluded], @"Trying to start an excluded process" );

      _processedItem = item;
      [self startProcess:[procParam processingClass] withEnumerator:nil
                  orItem:item parameters:procParam];
   }
   else
   {
      // Nothing left to process
      [_notifCenter postNotificationName: LynkeosProcessStackEndedNotification
                                  object: self
                                userInfo:
                       [NSDictionary dictionaryWithObject:item
                                                   forKey:LynkeosUserInfoItem]];
   }
}

- (oneway void) processStarted: (id)proxy connection:(LynkeosThreadConnection*)cnx
{
   NSEnumerator *threadList;
   ThreadControl *thr;

   // Find which thread it is
   threadList = [_threads objectEnumerator];
   while( (thr = [threadList nextObject]) != nil && thr->_cnx != cnx )
      ;
   NSAssert( thr != nil, @"Unknown created thread" );

   // Keep a reference on the new threaded object proxy
   thr->_threaded = proxy;
}

- (void) stopProcess
{
   NSEnumerator *threadList;
   ThreadControl *thr;

   threadList = [_threads objectEnumerator];
   while( (thr = [threadList nextObject]) != nil )
      [thr->_threaded stopProcessing];
}

- (oneway void) processEnded: (id)obj
{
   NSEnumerator *threadList;
   ThreadControl *thr;

   // Find which thread it is
   threadList = [_threads objectEnumerator];
   while( (thr = [threadList nextObject]) != nil && thr->_threaded != obj )
      ;
   NSAssert( thr != nil, @"Unknown finishing thread" );

   // Remove that thread from the list
   [_threads removeObject:thr];

   // Check if all threads have finished working
   if ( [_threads count] == 0 )
   {
      BOOL listProcessing = YES;

      // Notify of processing end
      [_notifCenter postNotificationName: LynkeosProcessEndedNotification
                                  object: self
                                userInfo:
                    [NSDictionary dictionaryWithObject:_currentProcessingClass
                                                forKey:LynkeosUserInfoProcess]];
      _currentProcessingClass = nil;

      // If it is an image processing, launch next process in the stack
      if ( _processedItem != nil )
      {
         LynkeosImageProcessingParameter *p =
                       [_processStackMgr nextParameterToProcess:
                                      (LynkeosProcessableImage*)_processedItem];
         listProcessing = NO;
         if ( p != nil )
         {
            [self startProcess:[p processingClass] withEnumerator:nil
                        orItem:_processedItem parameters:p];
            return;
         }
         else
         {
            // All processings in the stack were applied
            // If we are in the initial enumeration, continue with the next item
            if ( _initialProcessEnum != nil )
            {
               [self continueProcessing];
            }
            // Otherwise, notify
            else
            {
               [_notifCenter postNotificationName:
                                            LynkeosProcessStackEndedNotification
                                           object: self
                                         userInfo:
                       [NSDictionary dictionaryWithObject:_processedItem
                                                   forKey:LynkeosUserInfoItem]];
               _processedItem = nil;
            }
         }
      }

      // Otherwise (list processing or image processing stack exhausted)

#if !defined GNUSTEP
      // Wake up the screen if needed
      UpdateSystemActivity(HDActivity);
#endif

      if (listProcessing )
      {
         // Announce the great news
         NSString *soundName = [[NSUserDefaults standardUserDefaults]
                                         objectForKey:K_PREF_END_PROCESS_SOUND];
         if ( [soundName length] != 0 )
         {
            NSSound *snd = [NSSound soundNamed:soundName];
            [snd play];
         }

         // Restart image processing if needed
         if ( _imageListSequenceNumber != [_imageList originalImageSequence] )
         {
            _processedItem = _imageList;
            LynkeosImageProcessingParameter *p =
                                [_processStackMgr getParameterForItem:_imageList
                                                             andParam:nil];
            if ( p != nil )
               [self startProcess:[p processingClass] withEnumerator:nil
                           orItem:_imageList parameters:p];
         }
      }
   }
}

- (oneway void) itemWasProcessed:(id <LynkeosProcessableItem>) item
{
   // Notify of processing progress
   [_notifCenter postNotificationName: LynkeosItemWasProcessedNotification
                               object: self
                             userInfo: [NSDictionary dictionaryWithObject:item
                                                   forKey:LynkeosUserInfoItem]];
}

- (void) setProcessingParameter:(id <LynkeosProcessingParameter>)parameter
                        withRef:(NSString*)ref 
                  forProcessing:(NSString*)processing
{
   [_parameters setProcessingParameter:parameter withRef:ref 
                         forProcessing:processing];

   // Notify of the change
   [_parameters notifyItemModification:self];
}

- (id <LynkeosProcessingParameter>) getProcessingParameterWithRef:(NSString*)ref 
                                             forProcessing:(NSString*)processing
{
   return( [_parameters getProcessingParameterWithRef:ref
                                        forProcessing:processing goUp:YES] );
}
- (id <LynkeosProcessingParameter>) getProcessingParameterWithRef:(NSString*)ref 
                                             forProcessing:(NSString*)processing
                                                             goUp:(BOOL)goUp
{
   return( [_parameters getProcessingParameterWithRef:ref
                                        forProcessing:processing goUp:goUp] );
}
@end
