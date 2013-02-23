//
//  Lynkeos
//  $Id: FITSWriter.m 498 2010-12-29 15:46:09Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Apr 22 2005.
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

#include <fitsio.h>

#include "FITSWriter.h"

#define K_NO_COMPRESSION   0
#define K_GZIP_COMPRESSION 1

@implementation FITSWriter

+ (void) load
{
   // Nothing to do, this is just to force the runtime to load this class
}

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      [NSBundle loadNibNamed:@"FITSWriter" owner:self];

      _compression = K_NO_COMPRESSION;
      _imgType = USHORT_IMG;
   }

   return( self );
}

+ (NSString*) writerName { return( @"FITS" ); }

+ (NSString*) fileExtension { return( @"fits" ); }

+ (BOOL) canSaveDataWithPlanes:(u_short)nPlanes 
                         width:(u_short)w height:(u_short)h
                      metaData:(NSDictionary*)metaData
{
   return( nPlanes == 1 );
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
   fitsfile *fits;
   double *buf = nil;
   u_short x, y;
   double max, offset, scale, datamax, datamin;
   int err = 0;
   NSString *suffix = ( _compression == K_NO_COMPRESSION ? @"" : @".gz" );
   const char *file;
   long size[2] = {w,h};

   // Unfortunately, CFITSIO does not handle correctly the 
   // file://localhost/... URL given by Cocoa
   if ( [url isFileURL] )
      file = [[@"!" stringByAppendingString:
                        [[url path] stringByAppendingString:suffix]]
                                                     fileSystemRepresentation];
   else
      file = [[[url absoluteString]  stringByAppendingString:suffix] UTF8String];

   fits_create_file( &fits, file, &err );

   if ( err != 0 )
   {
      fits_report_error( stderr, err );
      return;
   }

   fits_create_img(fits, _imgType, 2, size, &err);

   offset = 0.0;
   switch( _imgType )
   {
      case BYTE_IMG:
         max = 255.4;
         break;
      case USHORT_IMG:
         max = 65535.4;
         break;
      case ULONG_IMG:
         max = 4294967295.4;
         break;
      case FLOAT_IMG:
      case DOUBLE_IMG:
      default:
         // No translation
         max = white;
         offset = black;
         break;
   }
   scale = max - offset;

   // Allocate a translation buffer
   buf = (double*)malloc( w*sizeof(double) );

   // Save line by line and convert to the FITS coordinate system
   datamin = HUGE;
   datamax = -HUGE;
   for( y = 0; y < h; y++ )
   {
      long first[2] = {1,y+1};

      // Translate the values in a buffer before saving
      for( x = 0; x < w; x++ )
      {
         double v = GET_SAMPLE(data[0],precision,x,h-y-1,lineW);

         v = v*scale + offset;

         // Still look for extrema
         if ( v < datamin )
            datamin = v;
         if ( v > datamax )
            datamax = v;

         buf[x] = v;
      }
      fits_write_pix( fits, TDOUBLE, first, w, buf, &err );
   }

   // Adjust extrema to the coding
   switch( _imgType )
   {
      case BYTE_IMG:
         datamin = (long)(datamin+0.5);
         datamax = (long)(datamax+0.5);
         datamin -= 128.0;
         datamax -= 128.0;
         break;
      case USHORT_IMG:
         datamin = (long)(datamin+0.5);
         datamax = (long)(datamax+0.5);
         datamin -= 32768.0;
         datamax -= 32768.0;
         break;
      case ULONG_IMG:
         datamin = (long)(datamin+0.5);
         datamax = (long)(datamax+0.5);
         datamin -= 2147483648.0;
         datamax -= 2147483648.0;
         break;
      case FLOAT_IMG:
      case DOUBLE_IMG:
      default:
         break;
   }


   fits_update_key( fits, TDOUBLE, "DATAMIN", &datamin, 
                    "Minimum sample value", &err);
   fits_update_key( fits, TDOUBLE, "DATAMAX", &datamax, 
                    "Maximum sample value", &err);

   if ( err != 0 )
      fits_report_error( stderr, err );

   err = 0;
   fits_close_file( fits, &err );

   if ( err != 0 )
      fits_report_error( stderr, err );

   if ( max != 0 )
      free( buf );
}

- (void) changeCompression :(id)sender
{
   _compression = [[sender selectedItem] tag];
}

- (void) changeBits :(id)sender
{
   _imgType = [[sender selectedItem] tag];
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
