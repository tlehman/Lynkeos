//
//  Lynkeos
//  $Id: FITSReader.m 498 2010-12-29 15:46:09Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun Apr 17 2005.
//  Copyright (c) 2005-2008. Jean-Etienne LAMIAUD
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
#include <limits.h>

#include "FITSReader.h"

@implementation FITSReader

+ (void) load
{
   // Nothing to do, this is just to force the runtime to load this class
}

+ (void) lynkeosFileTypes:(NSArray**)fileTypes
{
   *fileTypes = [NSArray arrayWithObjects:@"fits",@"fts",@"fit",
                                          @"imh",@"gz",@"z",
                                          nil];
}

+ (BOOL) hasCustomImageBuffer { return( NO ); }

- (id) init
{
   self = [super init];
   if ( self != nil )
      _fits = NULL;
   return( self );
}

- (id) initWithURL:(NSURL*)url
{
   int err = 0;
   int dimension, nbits;
   long size[2];

   self = [self init];

   if ( self != nil )
   {
      const char *file;

      // Unfortunately, CFITSIO does not handle correctly the 
      // file://localhost/... URL given by Cocoa
      if ( [url isFileURL] )
         file = [[url path] fileSystemRepresentation];
      else
         file = [[url absoluteString] UTF8String];

      fits_open_file( &_fits, file, READONLY, &err );
      fits_get_img_param( _fits, 2, &nbits, &dimension, size, &err );

      _width = size[0];
      _height = size[1];

      if ( err == 0 && dimension == 2 )
      {
         // Save the image scale and zero for sample read
         if ( fits_read_key(_fits, TDOUBLE, "BSCALE", &_imageScale, NULL, &err)
              != 0 || 
              fits_read_key(_fits, TDOUBLE, "BZERO", &_imageZero, NULL, &err)
              != 0 )
            _imageScale = 0.0;
         err = 0.0;

         if ( fits_read_key( _fits, TDOUBLE, "DATAMIN", &_minValue, NULL, &err)
              != 0 )
            _minValue = HUGE;
         err = 0.0;
         if ( fits_read_key( _fits, TDOUBLE, "DATAMAX", &_maxValue, NULL, &err)
              != 0 )
            _maxValue = -HUGE;
         err = 0.0;

         // Determine the scale and zero to use when converting to a NSImage
         switch( nbits )
         {
            case BYTE_IMG :
               _scale = 1.0;
               _zero = 0.0;
               if ( _minValue < 0.0 || _maxValue >= 256.0 )
               {
                  // Inconsistents min and max, that may come from a bug in
                  // Lynkeos prior to V2.3
                  _minValue = 0.0;
                  _maxValue = 255.0;
               }
               break;
            case SHORT_IMG :
               _scale = 127.49/SHRT_MAX;
               _zero = 128.0;
               if ( _minValue < SHRT_MIN || _maxValue > SHRT_MAX )
               {
                  // Inconsistents min and max, that may come from a bug in
                  // Lynkeos prior to V2.3
                  _minValue = SHRT_MIN;
                  _maxValue = SHRT_MAX;
               }
               break;
            case LONG_IMG :
               _scale = 127.49/LONG_MAX;
               _zero = 128.0;
               if ( _minValue < LONG_MIN || _maxValue > LONG_MAX )
               {
                  // Inconsistents min and max, that may come from a bug in
                  // Lynkeos prior to V2.3
                  _minValue = LONG_MIN;
                  _maxValue = LONG_MAX;
               }
               break;
            case LONGLONG_IMG :
               _scale = 127.49/LLONG_MAX;
               _zero = 128.0;
               if ( _minValue < LLONG_MIN || _maxValue > LLONG_MAX )
               {
                  // Inconsistents min and max
                  _minValue = LLONG_MIN;
                  _maxValue = LLONG_MAX;
               }
               break;
            case FLOAT_IMG :
            case DOUBLE_IMG :
            {
               if ( _minValue >= _maxValue )
               {
                  // No information, we need to read all the data
                  double *buf = (double*)malloc( sizeof(double)*_width );
                  int anyNull;
                  u_short x, y;

                  fits_set_bscale( _fits, 1.0, 0.0, &err );

                  for( y = 1; y <= _height && err == 0; y++ )
                  {
                     long first[2] = {1,y};
                     fits_read_pix( _fits, TDOUBLE, first, _width,
                                    NULL, buf, &anyNull, &err );
                     for( x = 0; x < _width; x++ )
                     {
                        if ( buf[x] < _minValue )
                           _minValue = buf[x];
                        if ( buf[x] > _maxValue )
                           _maxValue = buf[x];
                     }
                  }

                  // Discard an impossible to understand error
                  if ( err != 0 )
                     fits_report_error( stderr, err );
                  err = 0;
                  free( buf );
               }
               if ( err == 0 )
               {
                  _scale = 255.49/(_maxValue-_minValue);
                  _zero = -_minValue * _scale;
               }
               break;
            }
            default:
               NSAssert1( NO, @"FITS : Unexpected BITPIX value%d", nbits );
         }
      }

      if ( err != 0 || dimension != 2 || _scale == 0.0 )
      {
         NSLog(@"Unable to open FITS image : %@", [url absoluteString] );
         fits_report_error( stderr, err );
         [self release];
         self = nil;
      }
   }

   return( self );
}

- (void) dealloc
{
   int err = 0;
   if ( _fits != NULL )
      fits_close_file( _fits, &err );
   [super dealloc];
   NSAssert( err == 0, @"FITS closing error" );
   [super dealloc];
}

- (void) imageWidth:(u_short*)w height:(u_short*)h
{
   *w = _width;
   *h = _height;
}

- (u_short) numberOfPlanes
{
   return( 1 );
}

- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax
{
   if ( _minValue < _maxValue && _imageScale != 0.0 )
   {
      *vmin = _minValue*_imageScale + _imageZero;
      *vmax = _maxValue*_imageScale + _imageZero;
   }
   else
   {
      *vmin = 0.0;
      *vmax = 255.0;
   }
}

- (NSImage*) getNSImage
{
   NSImage *image = nil;
   NSBitmapImageRep* bitmap;

   // Create a RGBA bitmap
   bitmap = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil
                                   pixelsWide:_width
                                   pixelsHigh:_height
                                bitsPerSample:8
                              samplesPerPixel:1
                                     hasAlpha:NO
				     isPlanar:NO
                               colorSpaceName:NSCalibratedWhiteColorSpace
                                  bytesPerRow:0
                                 bitsPerPixel:8] autorelease];

   if ( bitmap != nil )
   {
      u_short y;
      int err = 0;
      u_char *pixels = (u_char*)[bitmap bitmapData];
      // Retrieve the geometry allocated by the runtime
      int bpr = [bitmap bytesPerRow];

      NSAssert( [bitmap bitsPerPixel] == 8, @"Hey, I asked bpp to be 8 !" );

      fits_set_bscale( _fits, _scale, _zero, &err );

      if ( err == 0 )
      {
         for( y = 0; y < _height; y++ )
         {
            long first[2] = {1,y+1};
            fits_read_pix( _fits, TBYTE, first, _width, NULL, 
                           &pixels[(_height-y-1)*bpr], NULL, &err );
         }
      }

      if ( err != 0 )
         fits_report_error( stderr, err );

      image = [[[NSImage alloc] initWithSize:NSMakeSize(_width,_height)]
                                                                   autorelease];

      if ( image != nil )
         [image addRepresentation:bitmap];
   }

   return( image );
}

- (void) getImageSample:(void * const * const)sample 
          withPrecision:(floating_precision_t)precision
             withPlanes:(u_short)nPlanes
                    atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
              lineWidth:(u_short)lineW
{
   u_short xs, ys, yl;
   int err = 0;

   // Convert to FITS coordinate system
   xs = x + 1;
   ys = _height - y - h + 1;

   NSAssert( nPlanes == 1, @"Try to read multiplane FITS" );

   if ( _imageScale == 0.0 )
      fits_set_bscale( _fits, _scale, _zero, &err );
   else
      fits_set_bscale( _fits, _imageScale, _imageZero, &err );


   if ( err == 0 )
   {
      for( yl = 0; yl < h; yl++ )
      {
         long first[2] = {xs,ys+yl};
         void *buf;

         if ( precision == DOUBLE_PRECISION )
            buf = &((double*)sample[0])[(h-yl-1)*lineW];
         else
            buf = &((float*)sample[0])[(h-yl-1)*lineW];

         fits_read_pix(_fits, 
                       (precision == DOUBLE_PRECISION ? TDOUBLE : TFLOAT), 
                       first, w, NULL, buf, NULL, &err );
      }
   }

   if ( err != 0 )
      fits_report_error( stderr, err );
}

- (NSDictionary*) getMetaData 
{
   return( nil );
}

- (id <LynkeosImageBuffer>) getCustomImageSampleAtX:(u_short)x Y:(u_short)y 
                                                  W:(u_short)w H:(u_short)h
{
   NSAssert( NO, @"FITSReader does not provides custom image class" );
   return( nil );
}

- (BOOL) canBeCalibratedBy:(id <LynkeosFileReader>)reader
{
   NSAssert( NO, @"FITSReader does not provides custom image class" );
   return( NO );
}

@end
