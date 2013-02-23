//
//  Lynkeos
//  $Id: LynkeosBasicAlignResult.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Thu May 8 2008.
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

#include "LynkeosBasicAlignResult.h"

/* For compatibility, we kkep the same string as MyImageAligner */
NSString * const LynkeosAlignRef = @"MyImageAligner";
NSString * const LynkeosAlignResultRef = @"AlignResult";

#define K_ALIGN_OFFSET        @"offset"

@implementation LynkeosBasicAlignResult
- (id) init
{
   if ( (self = [super init]) != nil )
      _alignOffset = NSMakePoint(0.0, 0.0);

   return( self );
}

- (NSPoint) offset { return( _alignOffset ); }
- (NSNumber*) dx { return( [NSNumber numberWithDouble:_alignOffset.x] ); }
- (NSNumber*) dy { return( [NSNumber numberWithDouble:_alignOffset.y] ); }

- (NSAffineTransform*) alignTransform
{
   NSAffineTransform *tr = [NSAffineTransform transform];
   [tr translateXBy:_alignOffset.x yBy:_alignOffset.y];

   return( tr );
}

- (NSPoint) correctedCoordinatesFor:(NSPoint)source
{
   NSPoint p = { source.x - _alignOffset.x, source.y - _alignOffset.y };
   return( p );
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [encoder encodePoint: _alignOffset forKey: K_ALIGN_OFFSET];
}

- (id) initWithCoder:(NSCoder *)decoder
{
   self = [self init];

   if ( self != nil && [decoder containsValueForKey:K_ALIGN_OFFSET] )
      _alignOffset = [decoder decodePointForKey:K_ALIGN_OFFSET];

   return( self );
}
@end

/*!
* @abstract Class for reading files up to V2.2
 */
@interface MyImageAlignerResult : NSObject <LynkeosProcessingParameter>
{
}
@end

@implementation MyImageAlignerResult
- (id) init
{
   [self release];
   return( [[LynkeosBasicAlignResult alloc] init] );
}

- (void)encodeWithCoder:(NSCoder *)encoder
{ [self doesNotRecognizeSelector:_cmd]; }

- (id) initWithCoder:(NSCoder *)decoder
{
   [self release];
   return( [[LynkeosBasicAlignResult alloc] initWithCoder:decoder] );
}

@end