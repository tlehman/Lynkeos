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

#include <LynkeosCore/LynkeosObjectCache.h>
#include "ProcessStackManager.h"

NSString * const K_PROCESS_STACK_REF = @"processStackRef";

static NSObject <LynkeosImageBuffer> *intermediateResult = nil;
static LynkeosImageProcessingParameter *intermediateParam = nil;
static ProcessStackManager *owner = nil;

@interface ProcessStackManager(Private)
- (void) setIntermediateResult:(NSObject <LynkeosImageBuffer> *)result
                          copy:(BOOL)copy ;
- (void) setIntermediateParam:(LynkeosImageProcessingParameter*)param ;
- (void) deleteIntermediateResult ;
@end

@implementation ProcessStackManager(Private)
- (void) setIntermediateResult:(NSObject <LynkeosImageBuffer> *)result
                          copy:(BOOL)copy
{
   NSAssert( owner == nil || owner == self,
            @"Access to intermediate result while locked by another document" );
   if ( intermediateResult != nil )
      [intermediateResult release];
   if ( result != nil )
   {
      if ( copy )
         intermediateResult = [result copy];
      else
         intermediateResult = [result retain];
   }
   else
      intermediateResult = nil;
   owner = self;
}

- (void) setIntermediateParam:(LynkeosImageProcessingParameter*)param
{
   NSAssert( owner == nil || owner == self,
            @"Access to intermediate result while locked by another document" );
   if ( intermediateParam != nil )
      [intermediateParam release];
   intermediateParam = param;
   if ( intermediateParam != nil )
      [intermediateParam retain];
   owner = self;
}

- (void) deleteIntermediateResult
{
   if ( intermediateResult != nil )
      [intermediateResult release];
   if ( intermediateParam != nil )
      [intermediateParam release];
   intermediateResult = nil;
   intermediateParam = nil;
   _intermediateRank = NSNotFound;
   owner = nil;
}
@end

@implementation ProcessStackManager

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _item = nil;
      _intermediateRank = NSNotFound;
      _currentRank = NSNotFound;
   }

   return( self );
}

- (void) dealloc
{
   if ( _item != nil )
      [_item release];

   [super dealloc];
}

- (LynkeosImageProcessingParameter*)
                   getParameterForItem:(LynkeosProcessableImage*)item
                              andParam:(LynkeosImageProcessingParameter*)inParam
{
   LynkeosImageProcessingParameter *outParam = inParam;
   int idx, previousIdx, stackSize, newIntermediate;

   NSAssert( item != nil, @"getParameterForItem called with nil item" );

   // Find the parameter in the stack
   if ( item != _item )
   {
      [self deleteIntermediateResult];
      if ( _item != nil )
         [_item release];
      _item = [item retain];
      _stack = (NSMutableArray*)
                         [item getProcessingParameterWithRef:K_PROCESS_STACK_REF
                                               forProcessing:nil goUp:NO];
   }

   if ( _stack == nil && inParam != nil )
   {
      // Create a brand new one
      _stack = [NSMutableArray array];
      [item setProcessingParameter:(id <LynkeosProcessingParameter>)_stack
                           withRef:K_PROCESS_STACK_REF forProcessing:nil];
   }

   if ( inParam == nil && (_stack == nil || [_stack count] == 0) )
      // Nothing to do
      return( nil );

   // If the intermediate result was taken by another document, take it back
   if ( owner != self )
      [self deleteIntermediateResult];

   if ( inParam != nil )
      idx = [_stack indexOfObject:inParam];
   else
      idx = 0;

   if ( idx == NSNotFound )
   {
      // This is the new topmost item in the stack
      [inParam setExcluded:NO];
      [_stack addObject:inParam];
      [self setIntermediateResult:[item getResult] copy:YES];
      idx = [_stack count]-1;
      _intermediateRank = idx-1;
      if ( _intermediateRank >= 0 )
         [self setIntermediateParam:[_stack objectAtIndex:_intermediateRank]];
      else
         [self setIntermediateParam:nil];
      _currentRank = idx;
   }
   else
   {
      LynkeosObjectCache *cache = [LynkeosObjectCache imageProcessingCache];

      if ( inParam != nil )
         [_stack replaceObjectAtIndex:idx withObject:inParam];
      else
         inParam = [_stack objectAtIndex:0];
      stackSize = [_stack count];

      // Find the previous result index (by skipping excluded processes)
      newIntermediate = NSNotFound;
      for( previousIdx = idx-1; previousIdx >= 0; previousIdx-- )
      {
         LynkeosImageProcessingParameter*p = [_stack objectAtIndex:previousIdx];

         if ( ![p isExcluded] )
         {
            NSObject <LynkeosImageBuffer> *image = nil;

            // Save the new intermediate rank for future processings
            if ( newIntermediate == NSNotFound )
               newIntermediate = previousIdx;

            // Try to find a match in the cache
            if ( cache != nil )
            {
               image = (NSObject<LynkeosImageBuffer>*)[cache getObjectForKey:p];
               if ( image != nil )
               {
                  // Set the cached result as the starting image
                  [_item setResult:[[image copy] autorelease]];
                  break;
               }
            }

            // Otherwise, use the intermediate result if found
            if ( previousIdx == _intermediateRank && p == intermediateParam )
            {
               // Set the intermediate result as the starting image
               [item setResult:[[intermediateResult copy] autorelease]];
               break;
            }
         }
      }
      if ( _intermediateRank != newIntermediate )
      {
         _intermediateRank = newIntermediate;
         if ( _intermediateRank != NSNotFound )
            [self setIntermediateParam:[_stack objectAtIndex:_intermediateRank]];
         else
            [self deleteIntermediateResult];
      }

      if ( previousIdx < 0 )
      {
         // Restart from the begining to get the new intermediate result
         if ( ![item isOriginal] )
            [item revertToOriginal];
         _currentRank = 0;
      }
      else
         // Restart after this process as a cached or intermediate result matches
         _currentRank = previousIdx+1;

      // Skip excluded processes to start at a real one
      for ( ; _currentRank < stackSize; _currentRank++ )
      {
         outParam = [_stack objectAtIndex:_currentRank];
         if ( ![outParam isExcluded] )
            break;
      }

      if ( _currentRank >= stackSize )
      {
         outParam = nil;   // All remaining processes are excluded
         _currentRank = NSNotFound;
      }
   }

   return( outParam );
}

- (LynkeosImageProcessingParameter*) nextParameterToProcess:
                                                  (LynkeosProcessableImage*)item
{
   int stackSize;
   LynkeosImageProcessingParameter *outParam;

   NSAssert( item == _item, @"Change of item before end of stack processing" );
   NSAssert( _currentRank != NSNotFound, @"Process unknown in the stack" );

   LynkeosObjectCache *cache = [LynkeosObjectCache imageProcessingCache];
   if ( cache != nil || _currentRank == _intermediateRank )
   {
      // Save all temporary results in the cache
      id <LynkeosImageBuffer> image =
                              [[(NSObject*)[_item getResult] copy] autorelease];
      if ( cache != nil )
         [cache setObject:image forKey:[_stack objectAtIndex:_currentRank]];

      // Intercept the intermediate result
      if ( _currentRank == _intermediateRank )
         [self setIntermediateResult:image copy:NO];
   }

   // Find the next process to execute
   _currentRank++;
   stackSize = [_stack count];
   for (; _currentRank < stackSize; _currentRank++ )
   {
      outParam = [_stack objectAtIndex:_currentRank];
      if ( ![outParam isExcluded] )
         break;
   }
   if ( _currentRank >= stackSize )
   {
      // Stack ended or all remaining processes are excluded
      outParam = nil;
      _currentRank = NSNotFound;
   }
   return( outParam );
}

@end
