//
//  Lynkeos
//  $Id: LynkeosCommon.h 452 2008-09-14 12:35:29Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Mon Aug 9 2004.
//  Copyright (c) 2003-2008. Jean-Etienne LAMIAUD
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

/*!
 * @header
 * @abstract Common definitions for the Lynkeos project
 */
#ifndef __LYNKEOSCOMMON_H
#define __LYNKEOSCOMMON_H

#include <sys/types.h>

// Integer cartesian types

/*!
 * @abstract Integer coordinates.
 */
typedef struct
{
   short x;    //!< X coordinate (can be negative)
   short y;    //!< Y coordinate (can be negative)
} LynkeosIntegerPoint;

/*!
 * @abstract Integer size.
 */
typedef struct
{
   u_short width;    //!< Width part of the size (>= 0)
   u_short height;   //!< Height part of the size (>=0)
} LynkeosIntegerSize;

/*!
 * @abstract Integer rectangle. It uses the point and size types.
 */
typedef struct
{
   LynkeosIntegerPoint origin;  //!< Origin of the rectangle
   LynkeosIntegerSize  size;    //!< Size of the rectangle
} LynkeosIntegerRect;

// Creators and conversion
static inline LynkeosIntegerPoint LynkeosMakeIntegerPoint(u_short x, u_short y) 
{
   LynkeosIntegerPoint p = {x,y};
   return p; 
}

static inline LynkeosIntegerSize LynkeosMakeIntegerSize(u_short w, u_short h) 
{
   LynkeosIntegerSize s = {w,h};
   return s;
}

static inline LynkeosIntegerRect LynkeosMakeIntegerRect(u_short x, u_short y, u_short w, u_short h) 
{
   LynkeosIntegerRect r = {{x,y},{w,h}};
   return r;
}

static inline LynkeosIntegerRect IntersectIntegerRect( LynkeosIntegerRect r1, 
                                                  LynkeosIntegerRect r2 )
{
   LynkeosIntegerRect result = r1;

   if ( result.origin.x < r2.origin.x )
   {
      if ( result.origin.x + result.size.width > r2.origin.x )
         result.size.width -= r2.origin.x - result.origin.x;
      else
         result.size.width = 0;  // There is no intersection
      result.origin.x = r2.origin.x;
   }
   if ( result.origin.y < r2.origin.y )
   {
      if ( result.origin.y + result.size.height > r2.origin.y )
         result.size.height -= r2.origin.y - result.origin.y;
      else
         result.size.height = 0;  // There is no intersection
      result.origin.y = r2.origin.y;
   }
   if ( result.origin.x + result.size.width > r2.origin.x + r2.size.width )
   {
      if ( result.origin.x < r2.origin.x + r2.size.width )
         result.size.width = r2.origin.x + r2.size.width - result.origin.x;
      else
         result.size.width = 0;  // There is no intersection
   }
   if ( result.origin.y + result.size.height > r2.origin.y + r2.size.height )
   {
      if ( result.origin.y < r2.origin.y + r2.size.height )
         result.size.height = r2.origin.y + r2.size.height - result.origin.y;
      else
         result.size.height = 0;  // There is no intersection
   }

   return( result );
}

#ifdef __OBJC__

#include <Foundation/Foundation.h>

static inline NSPoint NSPointFromIntegerPoint(LynkeosIntegerPoint p)
{
   NSPoint rp = {p.x,p.y}; 
   return rp; 
}

static inline NSSize NSSizeFromIntegerSize(LynkeosIntegerSize s)
{ 
   NSSize rs = {s.width,s.height}; 
   return rs; 
}

static inline NSRect NSRectFromIntegerRect(LynkeosIntegerRect r) 
{
   NSRect rr = {{r.origin.x,r.origin.y},
                {r.size.width,r.size.height}};
   return rr;
}

static inline LynkeosIntegerPoint  LynkeosIntegerPointFromNSPoint(NSPoint p) 
{ 
   LynkeosIntegerPoint rp = {(long)p.x,(long)p.y}; 
   return rp; 
}

static inline LynkeosIntegerSize LynkeosIntegerSizeFromNSSize(NSSize s) 
{ 
   LynkeosIntegerSize rs = {(u_long)s.width,(u_long)s.height}; 
   return rs; 
}

static inline LynkeosIntegerRect LynkeosIntegerRectFromNSRect(NSRect r) 
{
   LynkeosIntegerRect rr = {{(long)r.origin.x,(long)r.origin.y},
                       {(u_long)r.size.width,(u_long)r.size.height}};
   return rr; 
}

#endif

#endif
