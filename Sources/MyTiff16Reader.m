//
//  Lynkeos
//  $Id: MyTiff16Reader.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Tue Mar 29 2005.
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

#import <AppKit/NSGraphics.h>

#include <LynkeosCore/LynkeosStandardImageBuffer.h>

#include "processing_core.h"
#include "MyTiff16Reader.h"

@implementation MyTiff16Reader
+ (void) load
{
   // Nothing to do, this is just to force the runtime to load this class
}

+ (void) lynkeosFileTypes:(NSArray**)fileTypes
{
   *fileTypes = [NSArray arrayWithObjects:[NSNumber numberWithInt:1],@"tif",
                                          [NSNumber numberWithInt:1],@"tiff",
                                          nil];
}

+ (BOOL) hasCustomImageBuffer { return( NO ); }

- (id) init
{
   self = [super init];
   if ( self != nil )
   {
      _tiffFile = NULL;
      _min = HUGE;
      _max = -HUGE;
   }

   return( self );
}

- (id) initWithURL:(NSURL*)url
{
   self = [self init];

   if ( self != nil )
   {
      const char *filePath = [[url path] fileSystemRepresentation];
      // Is this file a TIFF image ?
      TIFF *tiff = TIFFOpen( filePath, "r" );

      if ( tiff == NULL )
      {
         [self release];
         self = nil;
      }
      else
      {
         TIFFGetField(tiff, TIFFTAG_IMAGEWIDTH, &_width);
         TIFFGetField(tiff, TIFFTAG_IMAGELENGTH, &_height);
         TIFFGetField(tiff, TIFFTAG_ROWSPERSTRIP, &_stripH);
         TIFFGetField(tiff, TIFFTAG_BITSPERSAMPLE, &_nBits);
         TIFFGetField(tiff, TIFFTAG_SAMPLEFORMAT, &_sampleType);
         TIFFGetField(tiff, TIFFTAG_PLANARCONFIG, &_planar);
         TIFFGetField(tiff, TIFFTAG_SAMPLESPERPIXEL, &_nPlanes );

         if ( (_nPlanes == 1                       /* Monochrome */
               || (_nPlanes == 3 || _nBits > 8) )  /* or 16/32 bits RGB image */
              && ( ( (_sampleType == 0 || _sampleType == SAMPLEFORMAT_UINT)
                     && (_nBits == 16 || _nBits == 8)) /* Only 8, 16 uint */
                   || ( _sampleType == SAMPLEFORMAT_IEEEFP
                        && _nBits == 32) )              /* Or 32 float */
              && _stripH != 0 )                       /* Organized as strips */
         {
            _tiffFile = (char*)malloc( strlen(filePath) + 1 );
            strcpy( _tiffFile, filePath );
         }
         else
         {
            /* Not an image worth of us !... */
            [self release];
            self = nil;
         }

         TIFFClose( tiff );
      }
   }

   return( self );
}

- (void) dealloc
{
   if ( _tiffFile != NULL )
      free( _tiffFile );
   [super dealloc];
}

- (void) imageWidth:(u_short*)w height:(u_short*)h
{
   *w = _width;
   *h = _height;
}

- (u_short) numberOfPlanes
{
   return( _nPlanes );
}

- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax
{
   if ( _min > _max )
   {
      // for IEEE_FP images, provide the real min and max
      if ( _sampleType == SAMPLEFORMAT_IEEEFP )
      {
         LynkeosStandardImageBuffer *buf =
             [LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:_nPlanes
                                                                 width:_width
                                                                height:_height];
         [self getImageSample:[buf colorPlanes]
                withPrecision:PROCESSING_PRECISION
                   withPlanes:_nPlanes atX:0 Y:0 W:_width H:_height
                    lineWidth:buf->_padw];
         [buf getMinLevel:&_min maxLevel:&_max];
      }
      else
      {
         _min = 0.0;
         _max = 255.0;
      }
   }

   *vmin = _min;
   *vmax = _max;
}

- (NSImage*) getNSImage
{
   NSImage *image = nil;
   NSBitmapImageRep* bitmap;
   TIFF *tiff = TIFFOpen( _tiffFile, "r" );
   u_long i;

   NSAssert( tiff != NULL, @"Unable to open the TIFF file" );

   if ( _sampleType != SAMPLEFORMAT_IEEEFP )
   {
      // Create a RGBA bitmap
      bitmap = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                            pixelsWide:_width
                                            pixelsHigh:_height
                                         bitsPerSample:8
                                       samplesPerPixel:4
                                              hasAlpha:YES
                                              isPlanar:NO
                                        colorSpaceName:NSCalibratedRGBColorSpace
                                           bytesPerRow:_width*4
                                          bitsPerPixel:32] autorelease];
      NSAssert( bitmap != nil, @"Failed to create a bitmap for a TIFF image" );
      uint32 *pixels = (uint32*)[bitmap bitmapData];

      TIFFReadRGBAImageOriented( tiff, _width, _height, pixels, 
                                 ORIENTATION_TOPLEFT, 0 );

      // Unfortunately libtiff put it in little endian order
      for( i = 0; i < _width*_height; i++ )
         pixels[i] = NSSwapLittleLongToHost(pixels[i]);
   }

   // TIFFReadRGBAImageOriented is unable to read IEEE fp images
   else
   {
      double tmin[_nPlanes+1], tmax[_nPlanes+1], tgamma[_nPlanes+1];

      LynkeosStandardImageBuffer *buf =
             [LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:_nPlanes
                                                                 width:_width
                                                                height:_height];
      [self getImageSample:[buf colorPlanes] withPrecision:PROCESSING_PRECISION
                withPlanes:_nPlanes atX:0 Y:0 W:_width H:_height
                 lineWidth:buf->_padw];
      if ( _min > _max )
         [buf getMinLevel:&_min maxLevel:&_max];
      for( i = 0; i <= _nPlanes; i++ )
      {
         tmin[i] = _min;
         tmax[i] = _max;
         tgamma[i] = 1.0;
      }
      bitmap = [buf getNSImageWithBlack:tmin white:tmax gamma:tgamma];
   }

   TIFFClose( tiff );

   image = [[[NSImage alloc] initWithSize:NSMakeSize(_width,_height)]
                                                                   autorelease];

   if ( image != nil )
      [image addRepresentation:bitmap];

   return( image );
}

/* Macro to insert the monochromatic conversion with the required precision */
#define PLANAR_MONOCHROMATIC_CONVERSION(floating_type)                   \
{                                                                        \
   floating_type *s = &((floating_type*)sample[0])[(ys-y)*lineW+xs-x]; \
   if ( cs == 0 )                                                        \
      *s = v;                                                            \
   else                                                                  \
      *s += v;                                                           \
   if ( cs == _nPlanes-1 )                                               \
      *s /= (float)_nPlanes;                                             \
}

/*! Pixels values are scaled to remain with a 256 maximum while retaining
 * 16 bits precision (because they are floating precision numbers) when 
 * applicable
 */
- (void) getImageSample:(void * const * const)sample 
          withPrecision:(floating_precision_t)precision
             withPlanes:(u_short)nPlanes
                    atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
              lineWidth:(u_short)lineW
{
   TIFF *tiff = TIFFOpen( _tiffFile, "r" );
   BOOL monoConversion = (nPlanes == 1 && _nPlanes != 1 );
   tdata_t buf;
   u_short xs, ys, cs, ystr;

   NSAssert( tiff != NULL, @"Unable to open the TIFF file" );
   NSAssert2( nPlanes == _nPlanes || nPlanes == 1,
              @"Illegal transfer from %d planes to %d planes", 
              _nPlanes, nPlanes );

   NSAssert( x+w <= _width && y+h <= _height, 
             @"Sample at least partly outside the image" );

   buf = _TIFFmalloc(TIFFStripSize(tiff));
   NSAssert( buf != NULL, @"Unable to allocate a strip buffer" );

   if (_planar == PLANARCONFIG_SEPARATE)
   {
      /* We go through all our planes, if the caller wants monochrome data, 
       * we will accumulate our planes in the output buffer */
      for( cs = 0; cs < _nPlanes; cs++ )
      {
         for (ys = y, ystr = -1; ys < y+h; ys++)
         {
            uint32 strip = (ys+cs*_height)/_stripH, 
                   yoffset = (ys+cs*_height)%_stripH;

            if ( strip != ystr )
            {
               /* Start of a new strip */
               ystr = strip;
               TIFFReadEncodedStrip(tiff, strip, buf, (tsize_t) -1);
            }

            for( xs = x; xs < x+w; xs++ )
            {
               float v;

               switch ( _nBits )
               {
                  case 8 :
                     v = (float)((u_char*)buf)[xs+yoffset*_width];
                     break;
                  case 16 :
                     v = (float)((u_short*)buf)[xs+yoffset*_width] / 256.0;
                     break;
                  case 32 :
                     v = ((float*)buf)[xs+yoffset*_width];
                     break;
                  default:
                     NSAssert( NO, @"Inconsistent sample size" );
               }

               if ( monoConversion )
               {
                  if ( precision == SINGLE_PRECISION )
                     PLANAR_MONOCHROMATIC_CONVERSION(float)
                  else
                     PLANAR_MONOCHROMATIC_CONVERSION(double)
               }
               else
                  SET_SAMPLE(sample[cs],precision,xs-x,ys-y,lineW,v);
            }
         }
      }
   }
   else
   {
      for (ys = y, ystr = -1; ys < y+h; ys++)
      {
         uint32 strip = ys/_stripH, 
                yoffset = ys%_stripH;

         if ( strip != ystr )
         {
            /* Start of a new strip */
            ystr = strip;
            TIFFReadEncodedStrip(tiff, strip, buf, (tsize_t) -1);
         }

         for( xs = x; xs < x+w; xs++ )
         {
            u_long i = yoffset*_width*_nPlanes+xs*_nPlanes;

            if ( monoConversion )
            {
               float v = 0;

               for( cs = 0; cs < _nPlanes; cs++ )
               {
                  switch ( _nBits )
                  {
                     case 8 :
                        v += (float)((u_char*)buf)[i+cs];
                        break;
                     case 16 :
                        v += (float)((u_short*)buf)[i+cs] / 256.0;
                        break;
                     case 32 :
                        v += ((float*)buf)[i+cs];
                        break;
                     default:
                        NSAssert( NO, @"Inconsistent sample size" );
                  }                        
               }
               SET_SAMPLE(sample[0],precision,xs-x,ys-y,lineW,
                          v/(float)_nPlanes);
            }
            else
            {
               for( cs = 0; cs < _nPlanes; cs++ )
               {
                  switch ( _nBits )
                  {
                     case 8 :
                        SET_SAMPLE(sample[cs],precision,xs-x,ys-y,lineW,
                                   ((u_char*)buf)[i+cs])
                        break;
                     case 16 :
                        SET_SAMPLE(sample[cs],precision,xs-x,ys-y,lineW,
                                   ((u_short*)buf)[i+cs]/256.0)
                        break;
                     case 32 :
                        SET_SAMPLE(sample[cs],precision,xs-x,ys-y,lineW,
                                   ((float*)buf)[i+cs])
                        break;
                     default:
                        NSAssert( NO, @"Inconsistent sample size" );
                  }
               }
            }
         }
      }
   }

   _TIFFfree(buf);
   TIFFClose( tiff );
}

- (NSDictionary*) getMetaData 
{
   return( nil );
}

- (id <LynkeosImageBuffer>) getCustomImageSampleAtX:(u_short)x Y:(u_short)y 
                                                  W:(u_short)w H:(u_short)h
{
   NSAssert( NO, @"MyTiff16Reader does not provides custom image class" );
   return( nil );
}

- (BOOL) canBeCalibratedBy:(id <LynkeosFileReader>)reader
{
   NSAssert( NO, @"MyTiff16Reader does not provides custom image class" );
   return( NO );
}

@end
