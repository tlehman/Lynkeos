//
//  Lynkeos
//  $Id: MyTiffWriter.m 471 2008-11-02 15:00:54Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Apr 15 2005.
//  Copyright (c) 2005-2007. Jean-Etienne LAMIAUD
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

#include <AppKit/AppKit.h>

#include <tiffio.h>

#include "MyTiffWriter.h"

@implementation MyTiffWriter

+ (void) load
{
   // Nothing to do, this is just to force the runtime to load this class
}

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      [NSBundle loadNibNamed:@"TiffWriter" owner:self];

      _compression = COMPRESSION_LZW;
      _nBits = 16;
   }

   return( self );
}

+ (NSString*) writerName { return( @"TIFF" ); }

+ (NSString*) fileExtension { return( @"tiff" ); }

+ (BOOL) canSaveDataWithPlanes:(u_short)nPlanes 
                         width:(u_short)w height:(u_short)h
                      metaData:(NSDictionary*)metaData
{
   return( nPlanes == 1 || nPlanes == 3 );
}

- (NSPanel*) configurationPanel { return( _cfgPanel ); }

+ (id <LynkeosFileWriter>) writerForURL:(NSURL*)url 
                                  planes:(u_short)nPlanes 
                                   width:(u_short)w height:(u_short)h
                                metaData:(NSDictionary*)metaData
{
   // No pre-processing needed
   return( [[[self alloc] init] autorelease] );
}

- (void) saveImageAtURL:(NSURL*)url
              withData:(const void * const * const)data
         withPrecision:(floating_precision_t)precision
            blackLevel:(double)black whiteLevel:(double)white
            withPlanes:(u_short)nPlanes
                 width:(u_short)w
             lineWidth:(u_short)lineW 
                height:(u_short)h
              metaData:(NSDictionary*)metaData
{
   TIFF *tiff = TIFFOpen( [[url path] fileSystemRepresentation], "w" );
   const u_long scanLineW = w*nPlanes*_nBits/8;
   void *buf;
   u_short s, x, y, c;
   u_long hstrip;
   double max;

   // Choose a strip size
   hstrip = 256*1024/scanLineW;
   if ( hstrip == 0 )
      hstrip = 1;
   else if ( hstrip > h )
      hstrip = h;

   // Save the needed tags
   TIFFSetField(tiff,TIFFTAG_COMPRESSION,_compression);
   TIFFSetField(tiff,TIFFTAG_IMAGEWIDTH,w);
   TIFFSetField(tiff,TIFFTAG_IMAGELENGTH,h);
   TIFFSetField(tiff,TIFFTAG_BITSPERSAMPLE,_nBits);
   if ( _nBits == 32 )
   {
      TIFFSetField(tiff, TIFFTAG_SAMPLEFORMAT, SAMPLEFORMAT_IEEEFP);
      TIFFSetField(tiff, TIFFTAG_PREDICTOR, PREDICTOR_FLOATINGPOINT);
      TIFFSetField(tiff, TIFFTAG_SMINSAMPLEVALUE, black);
      TIFFSetField(tiff, TIFFTAG_SMAXSAMPLEVALUE, white);
   }
   else
   {
      TIFFSetField(tiff, TIFFTAG_SAMPLEFORMAT, SAMPLEFORMAT_UINT);
      TIFFSetField(tiff, TIFFTAG_PREDICTOR, PREDICTOR_HORIZONTAL);
   }
   TIFFSetField(tiff,TIFFTAG_SAMPLESPERPIXEL,nPlanes);
   TIFFSetField(tiff,TIFFTAG_PLANARCONFIG,PLANARCONFIG_CONTIG);
   TIFFSetField(tiff, TIFFTAG_ROWSPERSTRIP, hstrip);
   TIFFSetField(tiff, TIFFTAG_PHOTOMETRIC, 
                (nPlanes == 1 ? PHOTOMETRIC_MINISBLACK : PHOTOMETRIC_RGB) );

   switch( _nBits )
   {
      case 8 :  max = 255.9;   break;
      case 16 : max = 65535.9; break;
      case 32 : max = white - black; break;
      default : NSAssert( NO, @"Inconsistent TIFF sample size" );
   }
   buf = _TIFFmalloc(TIFFStripSize(tiff));

   // Save strip by strip
   for( s = 0; s < (h+hstrip-1)/hstrip; s++ )
   {
      // Are we in the last strip ?
      u_short maxY = h - s*hstrip;

      if ( maxY > hstrip )
         // Not yet
         maxY = hstrip;

      for( y = 0; y < maxY ; y++ )
      {
         for( x = 0; x < w; x++ )
         {
            for( c = 0; c < nPlanes; c++ )
            {
               double v = GET_SAMPLE(data[c],precision,x,s*hstrip+y,lineW);
               if ( _nBits == 32 )
                  ((float*)buf)[(y*w+x)*nPlanes+c] = (float)(v*max + black);

               else
               {
                  v = v*max;
                  if ( v < 0.0 )
                     v = 0.0;
                  if ( v > max )
                     v = max;

                  if ( _nBits == 16 )
                     ((u_short*)buf)[(y*w+x)*nPlanes+c] = (u_short)v;
                  else
                     ((u_char*)buf)[(y*w+x)*nPlanes+c] = (u_char)v;
               }
            }
         }
      }

      TIFFWriteEncodedStrip(tiff, s, buf, hstrip*scanLineW);
   }

   TIFFClose( tiff );
}

- (void) changeCompression :(id)sender
{
   _compression = [[sender selectedItem] tag];
}

- (void) changeBits :(id)sender
{
   _nBits = [[sender selectedItem] tag];
}

- (void) confirmParams :(id)sender
{
   [NSApp stopModalWithCode:NSOKButton];
   [_cfgPanel close];
}

- (void) cancelParams :(id)sender 
{
   [NSApp stopModalWithCode:NSCancelButton];
   [_cfgPanel close];
}
@end
