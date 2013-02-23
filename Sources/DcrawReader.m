//
//  Lynkeos
//  $Id: DcrawReader.m 500 2010-12-30 16:06:27Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Wed Apr 27 2005.
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

#include <AppKit/NSGraphics.h>

#include "DcrawReaderPrefs.h"
#include "DcrawReader.h"

#define K_COUNTER_KEY @"ImageCount"

static NSMutableArray *rawFilesTypes = nil;

/*!
 * @category DcrawReader(Private)
 * @abstract Private part of the DCRAW readder class
 * @ingroup FileAccess
 */
@interface DcrawReader(Private)
/*!
 * @method waitForConversion:
 * @abstract Wait for the dcraw task to complete the conversion.
 * @result None
 */
- (void) waitForConversion ;

/*!
 * @method getPPMsample:atX:Y:W:H:
 * @abstract Extract a data sample in the converted PPM file
 * @param data The data buffer to fill
 * @param x X coordinate of the sample
 * @param y Y coordinate of the sample
 * @param w Width of the sample
 * @param h Height of the sample
 */
- (void) getPPMsample:(u_short*)data 
                  atX:(u_short)x Y:(u_short)y 
                    W:(u_short)w H:(u_short)h;
@end

@implementation DcrawReader(Private)
- (void) waitForConversion
{
   // If the conversion is not finished, wait for its completion
   if (  _dcrawTask != nil )
   {
      if ( [_dcrawTask isRunning] )
         [_dcrawTask waitUntilExit];

      // When succesful, initialize the PPM file access
      if ( [_dcrawTask terminationStatus] == 0 )
      {
         char line[40];
         _ppmFile = fopen( [_ppmFilePath fileSystemRepresentation], "rb" );
         fgets( line, 40, _ppmFile ); // First line of input "P6"
         fgets( line, 40, _ppmFile ); // Second line "w h"
         if ( sscanf( line, "%hu %hu", &_width, &_height ) != 2 )
         {
            _width = 0;
            _height = 0;
         }
         fgets( line, 40, _ppmFile ); // Third line "max"
         if ( sscanf( line, "%hu", &_dataMax ) != 1 )
            _dataMax = 0;

         if ( _width == 0 || _height == 0 || _dataMax == 0 )
         {
            // Bad file
            fclose( _ppmFile );
            _ppmFile = NULL;
         }
         else
            _ppmDataOffset = ftell( _ppmFile );
      }

      // Anyway, the task has ended
      [_dcrawTask release];
      _dcrawTask = nil;
   }
}

- (void) getPPMsample:(u_short*)data 
                  atX:(u_short)x Y:(u_short)y 
                    W:(u_short)w H:(u_short)h
{
   [self waitForConversion];

   if( _ppmFile != NULL )
   {
      u_short ys;

      // Transfer "w" pixels from "h" lines
      for( ys = 0; ys < h; ys++ )
      {
         // Jump to the line start
         fseek( _ppmFile, 
                _ppmDataOffset + sizeof(u_short)*3*((y+ys)*_width+x), 
                SEEK_SET );
         fread( &data[ys*w*3], 3*sizeof(u_short), w, _ppmFile );
      }
   }
}
@end

@implementation DcrawReader

+ (void) load
{
   // Nothing to do, this is just to force the runtime to load this class
}

+ (void) lynkeosFileTypes:(NSArray**)fileTypes
{
   // Read the file extensions in the configuration file
   if ( rawFilesTypes == nil )
   {
      NSNumber *pri = [NSNumber numberWithInt:1];
      NSString *cfgFile;
      NSArray *cfgFileTypes;
      cfgFile = [[NSBundle bundleForClass:[self class]] pathForResource:
                                                        @"dcraw_file_extensions"
                                                               ofType:@"plist"];
      NSData *plistData;
      NSString *error;
      NSPropertyListFormat format;
      NSMutableDictionary *dict;
      plistData = [NSData dataWithContentsOfFile:cfgFile];
      dict = [NSPropertyListSerialization propertyListFromData:plistData
                                mutabilityOption:NSPropertyListMutableContainers
                                                        format:&format
                                              errorDescription:&error];
      NSAssert( dict != nil, @"Failed to read RAW files configuration" );
      cfgFileTypes = [dict objectForKey:@"extensions"];
      NSAssert( cfgFileTypes != nil,
               @"Failed to access to RAW files extensions" );

      rawFilesTypes =
             [[NSMutableArray arrayWithCapacity:[cfgFileTypes count]*2] retain];

      NSEnumerator *list;
      NSString *fileType;
      for( list = [cfgFileTypes objectEnumerator];
           (fileType = [list nextObject]) != nil ; )
      {
         [rawFilesTypes addObject:pri];
         [rawFilesTypes addObject:fileType];
      }

   }
   *fileTypes = rawFilesTypes;
}

+ (BOOL) hasCustomImageBuffer { return( NO ); }

- (id) init
{
   self = [super init];
   if ( self != nil )
   {
      _dcrawTask = nil;
      _ppmFilePath = nil;
      _ppmFile = NULL;
   }
   return( self );
}

- (id) initWithURL:(NSURL*)url
{
   NSFileManager *fileMgr = [NSFileManager defaultManager];
   if ( [fileMgr isReadableFileAtPath:[url path]] )
      self = [self init];

   else
   {
      [self release];
      self = nil;
   }

   if ( self != nil )
   {
      // Prepare a task for the conversion
      _dcrawTask = [[NSTask alloc] init];

      if ( _dcrawTask != nil )
      {
         NSUserDefaults *pref = [NSUserDefaults standardUserDefaults];
         int cnt;
         const char *tmpdir = NULL;

         // Set its executable path to dcraw in our ressources
         NSString *dcrawPath = [[NSBundle bundleForClass:[self class]] 
                                                        pathForResource:@"dcraw"
                                                                 ofType:nil];
         [_dcrawTask setLaunchPath:dcrawPath];

         // Create a temporary filename for the converted PPM
         NSString *tmpdirStr = [pref stringForKey:K_TMPDIR_KEY];
         if ( tmpdirStr != nil )
            tmpdir = [[tmpdirStr stringByExpandingTildeInPath] UTF8String];
         if ( tmpdir == NULL || *tmpdir == '\0' )
            tmpdir = getenv("TMPDIR");
         if ( tmpdir == NULL || *tmpdir == '\0' )
            tmpdir = "/tmp";
         // with a count suffix shared by all documents
         cnt = [pref integerForKey:K_COUNTER_KEY] % 10000;
         _ppmFilePath = [[NSString stringWithFormat:@"%s/%@%04d.ppm", 
                                  tmpdir, 
                                  [fileMgr displayNameAtPath:[url path]],
                                  cnt] retain];
         cnt++;
         [pref setInteger:cnt forKey:K_COUNTER_KEY];
         // Create an empty file by this name
         [fileMgr createFileAtPath:_ppmFilePath contents:nil attributes:nil];
         [_dcrawTask setStandardOutput:
                        [NSFileHandle fileHandleForWritingAtPath:_ppmFilePath]];
         // Basic options to dcraw are "output on stdout", "16 bits" PPM
         NSMutableArray *args = [NSMutableArray arrayWithObjects: 
                                          @"-c", @"-4", nil];

         // More options
         if ( [pref boolForKey:K_MANUALWB_KEY] )
         {
            // Custom white balance
            [args addObject:@"-r"];
            [args addObject:[pref stringForKey:K_RED_KEY]];
            [args addObject:[pref stringForKey:K_GREEN1_KEY]];
            [args addObject:[pref stringForKey:K_BLUE_KEY]];
            [args addObject:[pref stringForKey:K_GREEN2_KEY]];
         }
         else
            [args addObject:@"-w"];    // Camera white balance

         if ( [pref boolForKey:K_LEVELS_KEY] )
         {
            // Custom dark and saturation levels
            [args addObject:@"-k"];
            [args addObject:[pref stringForKey:K_DARK_KEY]];
            [args addObject:@"-S"];
            [args addObject:[pref stringForKey:K_SATURATION_KEY]];
         }

         if ( ![pref boolForKey:K_ROTATION_KEY] )
         {
            // Override camera auto image rotation
            [args addObject:@"-t"];
            [args addObject:@"0"];
         }

         // The last arg is the file to convert
         [args addObject:[url path]];

         [_dcrawTask setArguments:args];

         // Start the conversion
         [_dcrawTask launch];
      }

      if ( _dcrawTask == nil 
           || ( ![_dcrawTask isRunning] 
                && [_dcrawTask terminationStatus] != 0 ) )
      {
         [self release];
         self = nil;
      }
   }

   return( self );
}

- (void) dealloc
{
   if ( _dcrawTask != nil )
   {
      if ( [_dcrawTask isRunning] )
         [_dcrawTask terminate];
      [_dcrawTask release];
   }

   if ( _ppmFile != NULL )
      fclose( _ppmFile );

   if ( _ppmFilePath != nil )
      [[NSFileManager defaultManager] removeFileAtPath:
                                         _ppmFilePath handler:nil];
   [super dealloc];
}

- (void) imageWidth:(u_short*)w height:(u_short*)h
{
   [self waitForConversion];

   *w = _width;
   *h = _height;
}

- (u_short) numberOfPlanes
{
   return( 3 );
}

- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax
{
   *vmin = 0.0;
   *vmax = 255.0;
}

- (NSImage*) getNSImage
{
   NSImage *image = nil;
   NSBitmapImageRep* bitmap;

   // Create a RGB bitmap
   bitmap = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil
                                   pixelsWide:_width
                                   pixelsHigh:_height
                                bitsPerSample:8
                              samplesPerPixel:3
                                     hasAlpha:NO
				     isPlanar:NO
                               colorSpaceName:NSCalibratedRGBColorSpace
                                  bytesPerRow:0
                                 bitsPerPixel:0] autorelease];

   if ( bitmap != nil )
   {
      u_char *pixels = (u_char*)[bitmap bitmapData];
      u_short *sample = (u_short*)malloc( sizeof(u_short)*3*_width*_height );
      u_long x, y;
      double scale = 255.9/_dataMax;
      int bpp = [bitmap bitsPerPixel];
      int bpr = [bitmap bytesPerRow];

      NSAssert( (bpp%8) == 0,
                @"Hey, I do not intend to work on non byte boudaries" );
      bpp /= 8;

      [self getPPMsample:sample atX:0 Y:0 W:_width H:_height];

      for( y = 0; y < _height; y++ )
      {
         for( x = 0; x < _width; x++ )
         {
            u_short *v = &sample[(y*_width+x)*3];

            pixels[y*bpr+x*bpp+0] = CFSwapInt16BigToHost(v[0])*scale;
            pixels[y*bpr+x*bpp+1] = CFSwapInt16BigToHost(v[1])*scale;
            pixels[y*bpr+x*bpp+2] = CFSwapInt16BigToHost(v[2])*scale;
         }
      }

      free( sample );

      image = [[[NSImage alloc] initWithSize:NSMakeSize(_width,_height)]
                                                                   autorelease];

      if ( image != nil )
         [image addRepresentation:bitmap];
   }

   return( image );
}

/*! Pixels values are scaled to remain with a 256 maximum while retaining
 * 16 bits precision (because they are floating precision numbers)
 */
- (void) getImageSample:(void * const * const)sample 
          withPrecision:(floating_precision_t)precision
             withPlanes:(u_short)nPlanes
                    atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
              lineWidth:(u_short)lineW
{
   u_short xs, ys, cs;
   u_short *ppmData;

   NSAssert( x+w <= _width && y+h <= _height, 
             @"Sample at least partly outside the image" );

   ppmData = (u_short*)malloc( sizeof(u_short)*3*w*h );

   [self getPPMsample:ppmData atX:x Y:y W:w H:h];

   for ( ys = 0; ys < h; ys++ )
   {
      for( xs = 0; xs < w; xs++ )
      {
         if ( nPlanes == 1 )
         {
            u_short *v = &ppmData[(ys*w+xs)*3];

            // Convert to monochrome
            SET_SAMPLE( sample[0],precision,xs,ys,lineW, 
                        (CFSwapInt16BigToHost(v[0])
                         +CFSwapInt16BigToHost(v[1])
                         +CFSwapInt16BigToHost(v[2]))/3.0/256.0 );
         }
         else
         {
            for( cs = 0; cs < nPlanes; cs++ )
               SET_SAMPLE( sample[cs],precision,xs,ys,lineW, 
                          CFSwapInt16BigToHost(ppmData[(ys*w+xs)*3+cs])/256.0 );
         }
      }
   }

   free( ppmData );
}

- (NSDictionary*) getMetaData 
{
   return( nil );
}

- (id <LynkeosImageBuffer>) getCustomImageSampleAtX:(u_short)x Y:(u_short)y 
                                                  W:(u_short)w H:(u_short)h
{
   NSAssert( NO, @"DcrawReader does not provides custom image class" );
   return( nil );
}

- (BOOL) canBeCalibratedBy:(id <LynkeosFileReader>)reader
{
   NSAssert( NO, @"DcrawReader does not provides custom image class" );
   return( NO );
}

@end
