//
//  Lynkeos
//  $Id: LynkeosProcessingDefs.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun May 12 2008.
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

#include "processing_core.h"
#include "LynkeosPreferences.h"
#include "LynkeosProcessingView.h"

NSString * const LynkeosProcessStartedNotification = @"LynkeosProcessStarted";
NSString * const LynkeosProcessEndedNotification =   @"LynkeosProcessEnded";
NSString * const LynkeosProcessStackEndedNotification =
                                                    @"LynkeosProcessStackEnded";
NSString * const LynkeosItemImageChangedNotification = 
                                                     @"LynkeosItemImageChanged";
NSString * const LynkeosItemWasProcessedNotification = 
                                                     @"LynkeosItemWasProcessed";
NSString * const LynkeosItemAddedNotification =      @"LynkeosItemAdded";
NSString * const LynkeosItemRemovedNotification =    @"LynkeosItemRemoved";
NSString * const LynkeosListChangeNotification =     @"LynkeosListChange";
NSString * const LynkeosDataModeChangeNotification = @"LynkeosDataModeChange";

NSString * const LynkeosUserInfoProcess = @"process";

NSString * const LynkeosDocumentDidLoadNotification = @"LynkeosDocumentDidLoad";

NSString * const LynkeosDocumentDidOpenNotification = @"LynkeosDocumentDidOpen";
NSString * const LynkeosUserinfoWindowController =
                                             @"LynkeosUserinfoWindowController";
NSString * const LynkeosDocumentWillCloseNotification =
                                                     @"LynkeosDocumentDidClose";
NSString * const LynkeosOutlineViewWillDisplayCellNotification =
                                           @"LynkeosOutlineViewWillDisplayCell";
NSString * const LynkeosOutlineViewItem = @"LynkeosOutlineViewItem";
NSString * const LynkeosOutlineViewCell = @"LynkeosOutlineViewCell";
NSString * const LynkeosOutlineViewColumn = @"LynkeosOutlineViewColumn";

NSString *const LynkeosImageViewSelectionRectDidChangeNotification
                                    = @"LynkeosImageViewSelectionRectDidChange";
NSString * const LynkeosImageViewSelectionRectIndex =
                                          @"LynkeosImageViewSelectionRectIndex";
NSString * const LynkeosImageViewZoomDidChangeNotification
                                                = @"LynkeosImageViewZoomChange";
NSString * const LynkeosImageViewRedrawNotification = @"LynkeosImageViewRedraw";

const floating_precision_t LynkeosProcessingPrecision = PROCESSING_PRECISION ;

// This is not necessarily the best place for this...
void getNumericPref( double *pref, NSString *key, double minv, double maxv )
{
   NSString* stringValue =
   [[NSUserDefaults standardUserDefaults] stringForKey:key];
   double v;

   if ( stringValue != nil )
   {
      v = [stringValue doubleValue];
      if ( v < minv )
         v = minv;
      else if ( v > maxv )
         v = maxv;
      *pref = v;
   }
}

// Adjust a value to the nearest power of 2, 3, 5, 7
u_short adjustFFTside( u_short n )
{
   int v, i2, i3, i5, i7, inf, sup;

   inf = 0;
   sup = INT_MAX;

   for ( i7 = 1 ; ; i7 *= 7 )
   {
      for( i5 = 1; ; i5 *= 5 )
      {
         for( i3 = 1; ; i3 *= 3 )
         {
            for( i2 = 1; ; i2 *= 2 )
            {
               v = i2*i3*i5*i7;
               if ( v >= n && v < sup )
                  sup = v;
               if ( v <= n && v > inf )
                  inf =v;

               if ( v >= n )
                  break;
            }
            if ( i3*i5*i7 >= n || v == n )
               break;
         }
         if ( i5*i7 >= n || v == n )
            break;
      }
      if ( i7 >= n || v == n )
         break;
   }

   return( n >= (sup+inf)/2 ? sup : inf );
}

void adjustFFTrect( LynkeosIntegerRect *r )
{
   LynkeosIntegerSize oldSize = r->size;

   r->size.width = adjustFFTside( r->size.width );
   r->size.height = adjustFFTside( r->size.height );
   r->origin.x += (oldSize.width - r->size.width)/2;
   r->origin.y += (oldSize.height - r->size.height)/2;
}

