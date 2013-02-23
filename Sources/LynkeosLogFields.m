//
//  Lynkeos
//  $Id: LynkeosLogFields.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Dec 28 2007.
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

#include "LynkeosLogFields.h"


@implementation LynkeosLogFields
- (id) initWithSlider:(NSSlider*)slider andTextField:(NSTextField*)text
{
   if ( (self = [self init]) != nil )
   {
      _slider = slider;
      _text = text;
      _offset = 0.0;
   }

   return( self );
}

- (double) valueFrom:(id)sender
{
   double v = 0.0;
   if ( sender == _slider )
   {
      v = exp([_slider doubleValue]) + _offset;
      [_text setDoubleValue:v];
   }
   else if ( sender == _text )
   {
      const double sliderMin = exp([_slider minValue]) + _offset;

      v = [sender doubleValue];

      if ( v < sliderMin )
      {
         if ( v <= 0.0 )
            _offset = v - 1.0;
         [_slider setMinValue:log(v - _offset)];
      }

      double l = log(v - _offset);
      if ( l > [_slider maxValue] )
         [_slider setMaxValue:l];
      [_slider setDoubleValue:l];
   }
   else
      NSAssert( NO, @"Inconsistent control" );

   return( v );
}

- (void) setDoubleValue:(double)v
{
   const double sliderMin = exp([_slider minValue]) + _offset;
   if ( v < sliderMin )
   {
      if ( v <= 0.0 )
         _offset = v - 1.0;
      [_slider setMinValue:log(v - _offset)];
   }

   double l = log(v - _offset);

   if ( [_text doubleValue] != v )
      [_text setDoubleValue:v];
   if ( [_slider doubleValue] != l )
   {
      if ( l > [_slider maxValue] )
         [_slider setMaxValue:l];
      [_slider setDoubleValue:l];
   }
}
@end
