//
//  Lynkeos
//  $Id: LynkeosColumnDescriptor.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Mon Apr 9 2007.
//  Copyright (c) 2007-2008. Jean-Etienne LAMIAUD
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

#include "LynkeosColumnDescriptor.h"

/*!
 * @abstract Concrete implementation of the subclassing of NSMutableDictionary
 * @discussion The direct subclassing of NSMutableDictionary is not possible.
 *    This class simulates it by agregating a dictionary and forwarding
 *    invocations to it.
 */
@interface MyConcreteColumnDescriptor : NSObject
{
   NSMutableDictionary *_dict; //!< The aggregated dictionary
}

/*!
 * @abstract Register an outline wiew column to display some processing info
 * @param key The string identifying the column
 * @param proc The reference of the process to which this information belongs
 * @param ref The reference under which this parameter is stored
 * @param field The name of the field used for key value coding
 * @param format The format used for displaying this parameter
 */
- (void) registerColumn:(NSString*)key forProcess:(NSString*)proc
              parameter:(NSString*)ref field:(NSString*)field
                 format:(NSString*)format;
@end

static MyConcreteColumnDescriptor *columnDescriptorInstance = nil;

@implementation LynkeosColumnDescription
- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _processingRef = nil;
      _parameterReference = nil;
      _fieldName = nil;
      _format = nil;
   }

   return( self );
}

- (void) dealloc
{
   if ( _processingRef != nil )
      [_processingRef release];
   if ( _parameterReference != nil )
      [_parameterReference release];
   if ( _fieldName != nil )
      [_fieldName release];
   if ( _format != nil )
      [_format release];

   [super dealloc];
}
@end

@implementation LynkeosColumnDescriptor

+ (LynkeosColumnDescriptor*) defaultColumnDescriptor
{
   // Create the singleton if needed
   if ( columnDescriptorInstance == nil )
      // Create an instance of the concrete implementation
      [[MyConcreteColumnDescriptor alloc] init];

   NSAssert( columnDescriptorInstance != nil,
             @"Failed to create the columns descriptor singleton" );

   return( (LynkeosColumnDescriptor*)columnDescriptorInstance );
}

- (id) init
{
   [self release];
   NSAssert( NO,@"Abstract class MyColumnDescriptor does not implement init" );

   return( self );
}

- (void) registerColumn:(NSString*)key forProcess:(NSString*)proc
              parameter:(NSString*)ref field:(NSString*)field
                 format:(NSString*)format
{
   NSAssert( NO,
       @"Abstract class MyColumnDescriptor does not implement registerColumn" );
}

@end


@implementation MyConcreteColumnDescriptor

- (id) init
{
   NSAssert( columnDescriptorInstance == nil,
             @"Attempt to create more than one MyConcreteColumnDescriptor" );
   if ( (self = [super init]) != nil )
   {
      columnDescriptorInstance = self;
      _dict = [[NSMutableDictionary dictionary] retain];
   }

   return( self );
}

- (void) deallocate
{
   if ( self != columnDescriptorInstance )
      NSLog( @"Deallocated MyConcreteColumnDescriptor is not the singleton instance" );
   else
      columnDescriptorInstance = nil;

   [_dict release];

   [super dealloc];
}

- (void) registerColumn:(NSString*)key forProcess:(NSString*)proc
               parameter:(NSString*)ref field:(NSString*)field
                 format:(NSString*)format
{
   LynkeosColumnDescription *desc = [[[LynkeosColumnDescription alloc] init] autorelease];

   desc->_processingRef = proc;
   desc->_parameterReference = ref;
   desc->_fieldName = field;
   desc->_format = format;

   [_dict setObject:desc forKey:key];
}

// Forward other invocations to the dictionary (direct inheritance is not possible)
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
   return( [_dict methodSignatureForSelector: aSelector] );
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
   [anInvocation invokeWithTarget:_dict];
}

@end
