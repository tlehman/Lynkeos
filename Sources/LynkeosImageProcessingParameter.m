//
//  Lynkeos
//  $Id: LynkeosImageProcessingParameter.m 498 2010-12-29 15:46:09Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Tue Aug 15 2007.
//  Copyright (c) 2007. Jean-Etienne LAMIAUD
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

#include <LynkeosCore/LynkeosProcessing.h>

static NSString * const K_PROCESSCLASS_KEY = @"procClass";
static NSString * const K_PROCESSEXCLUDED_KEY = @"procExcluded";

static unsigned long nextSequence = 0;

@interface LynkeosImageProcessingParameter(Private)
- (id) initWithoutSequence;
@end
@implementation LynkeosImageProcessingParameter(Private)
- (id) initWithoutSequence
{
   if ( (self = [super init]) != nil )
   {
      _processingClass = nil;
      _excluded = NO;
   }

   return( self );
}
@end

@implementation LynkeosImageProcessingParameter
- (id) init
{
   if ( (self = [self initWithoutSequence]) != nil )
   {
      _sequence = nextSequence;
      nextSequence++;
   }

   return( self );
}

- (id)copyWithZone:(NSZone *)zone
{
   LynkeosImageProcessingParameter *cp =
                        [[[self class] allocWithZone:zone] initWithoutSequence];

   if ( cp != nil )
   {
      cp->_processingClass = _processingClass;
      cp->_sequence = _sequence;
      cp->_excluded = _excluded;
   }

   return( cp );
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [encoder encodeObject:[_processingClass className] 
                  forKey:K_PROCESSCLASS_KEY];
   [encoder encodeBool:_excluded forKey:K_PROCESSEXCLUDED_KEY];
}

- (id) initWithCoder:(NSCoder *)decoder
{
   if ( (self = [self init]) != nil )
   {
      NSString *className = [decoder decodeObjectForKey:K_PROCESSCLASS_KEY];
      if ( className != nil )
         _processingClass = objc_getClass([className UTF8String]);
      _excluded = [decoder decodeBoolForKey:K_PROCESSEXCLUDED_KEY];
   }

   return( self );
}

- (u_int) hash { return( _sequence ); }

- (BOOL) isEqual: (id)anObject
{
   return( [anObject isKindOfClass:[self class]]
       && ((LynkeosImageProcessingParameter*)
           anObject)->_sequence == _sequence );
}
- (BOOL) isExcluded { return( _excluded ); }

- (void) setExcluded:(BOOL)excluded { _excluded = excluded; }

- (void) setProcessingClass:(Class)c
{
   _processingClass = c;
}

- (Class) processingClass { return(_processingClass); }
@end
