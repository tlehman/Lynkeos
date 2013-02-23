//
//  Lynkeos
//  $Id: MyCalibrationLock.m 452 2008-09-14 12:35:29Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Mon Aug 16 2004.
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

#include "MyCalibrationLock.h"

@implementation MyCalibrationLock

/*!
 * @discussion A calibration item can be added if it is able to calibrate all 
 *   the images in the "calibrable" list..
 */
- (BOOL) addCalibrationItem :(MyImageListItem*)item ;
{
   id <LynkeosFileReader> calibrationReader = [item getReader];
   NSEnumerator *iter = [_imageList objectEnumerator];
   BOOL firstCalibration = ([_calibrationList count] == 0);
   BOOL customCalibration;
   id <LynkeosFileReader> imageReader;
   LynkeosIntegerSize calSize;
   u_short np;

   customCalibration = [[calibrationReader class] hasCustomImageBuffer];
   [calibrationReader imageWidth:&calSize.width height:&calSize.height];
   np = [calibrationReader numberOfPlanes];

   // If there are already some calibration frames, verify "geometrical 
   // compatibility"
   if ( !firstCalibration 
        && ( calSize.width != _size.width || calSize.height != _size.height
             || np != _nPlanes) )
      return( NO );

   // Check against every image
   while ( (imageReader = [iter nextObject]) != nil )
   {
      // If there are not any calibration images yet, verify "geometrical 
      // compatibility" with each image
      if ( firstCalibration )
      {
         LynkeosIntegerSize imageSize;

         [imageReader imageWidth:&imageSize.width height:&imageSize.height];

         if ( imageSize.width != calSize.width 
              || imageSize.height != calSize.height
              || [imageReader numberOfPlanes] != np )
            return( NO );
      }

      // Verify "added" compatibilty
      if ( customCalibration )
      {
         if ( ![[imageReader class] hasCustomImageBuffer]
              || ![imageReader canBeCalibratedBy:calibrationReader] )
            return( NO );
      }
      else
      {
         if ( [[imageReader class] hasCustomImageBuffer] )
            return( NO );
      }
   }

   if ( [_calibrationList count] == 0 )
   {
      // First calibration image
      _size = calSize;
      _nPlanes = np;
   }

   [_calibrationList addObject:calibrationReader];

   return( YES );
}

/*!
 * @discussion An image item can be added if it can be calibrated by all 
 *   the images in the "calibration" list..
 */
- (BOOL) addImageItem :(MyImageListItem*)item 
{
   id <LynkeosFileReader> imageReader = [item getReader];
   LynkeosIntegerSize imageSize;
   u_short np;

   [imageReader imageWidth:&imageSize.width height:&imageSize.height];
   np = [imageReader numberOfPlanes];

   // Nothing to check if there are no calibration frames
   if ( [_calibrationList count] != 0 )
   {
      NSEnumerator *iter = [_calibrationList objectEnumerator];
      id <LynkeosFileReader> calibrationReader;   
      BOOL customImage = [[imageReader class] hasCustomImageBuffer];

      // verify "geometrical compatibility" first
      if ( imageSize.width != _size.width ||
           imageSize.height != _size.height ||
           np != _nPlanes )
         return( NO );

      // Check "added compatibility" against every calibration frame
      while ( (calibrationReader = [iter nextObject]) != nil )
      {
         if ( customImage )
         {
            if ( ![[calibrationReader class] hasCustomImageBuffer]
                 || ![imageReader canBeCalibratedBy:calibrationReader] )
               return( NO );
         }
         else
         {
            if ( [[calibrationReader class] hasCustomImageBuffer] )
               return( NO );
         }
      }
   }

   [_imageList addObject:imageReader];

   return( YES );
}

- (void) removeItem :(MyImageListItem*)item ;
{
   id <LynkeosFileReader> reader = [item getReader];
   [_calibrationList removeObjectIdenticalTo:reader];
   [_imageList removeObjectIdenticalTo:reader];

   if ( [_calibrationList count] == 0 )
   {
      // No more calibration frames, reset the "geometry"
      _size = LynkeosMakeIntegerSize(0,0);
      _nPlanes = 0;
   }
}

- (LynkeosIntegerSize) calibrationSize { return( _size ); }

// Constructors
- (id) init
{
   self = [super init];

   if ( self != nil )
   {
      _calibrationList = [[NSMutableArray array] retain];
      _imageList = [[NSMutableArray array] retain];
      _size = LynkeosMakeIntegerSize(0,0);
      _nPlanes = 0;
   }

   return( self );
}

- (void) dealloc
{
   [_calibrationList release];
   [_imageList release];
   [super dealloc];
}

+ (id) calibrationLock
{
   return( [[[self alloc] init] autorelease] );
}

@end
