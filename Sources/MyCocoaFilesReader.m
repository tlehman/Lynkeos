//
//  Lynkeos
//  $Id: MyCocoaFilesReader.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Mar 03 2005.
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

/** The size by which the "time" array is enlarged. */
#define K_TIME_PAGE_SIZE 1024

#include <AppKit/NSAffineTransform.h>

#include <pthread.h>

#include <QTKit/QTTrack.h>
#include <QTKit/QTMedia.h>

#include "processing_core.h"
#include "MyCachePrefs.h"

#include "MyCocoaFilesReader.h"

/** Mutex used to avoid a deadlock when drawing offscreen from many threads */
static pthread_mutex_t offScreenLock;

/** Common function to retrieve a sample from an NSImage. */
static void getImageSample( void * const * const sample, 
                            floating_precision_t precision, u_char nPlanes,
                            u_short atx, u_short aty, u_short atw, u_short ath, 
                            u_short width,
                            NSImage* image, LynkeosIntegerSize imageSize )
{
   NSRect cocoaRect;
   NSImageRep* srcImageRep;
   NSImage* offScreenImage;
   NSBitmapImageRep* bitMap;
   u_char *plane[5];
   u_short x, y, rowSize, pixelSize;
   BOOL planar;
   float color[3];

   if( image == nil )
      return;

   // Convert this rectangle to Cocoa coordinates system
   cocoaRect = NSMakeRect(atx,
                          imageSize.height - ath - aty,
                          atw,ath );

   // Create an image to draw the NSImage in
   offScreenImage = [[[NSImage alloc] initWithSize:cocoaRect.size] autorelease];
   pthread_mutex_lock( &offScreenLock );
   [offScreenImage lockFocus];

   NSAffineTransform * xform = [NSAffineTransform transform];
   [xform translateXBy: -cocoaRect.origin.x yBy: -cocoaRect.origin.y];
   [xform concat];

   srcImageRep = [image bestRepresentationForDevice:nil];
   // Force full pixel scale
   [srcImageRep drawInRect:NSMakeRect(0,0,imageSize.width,imageSize.height)];

   bitMap = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:cocoaRect] 
                                                                   autorelease];
   [offScreenImage unlockFocus];
   pthread_mutex_unlock( &offScreenLock );

   // Access the data
   [bitMap getBitmapDataPlanes:plane];
   rowSize = [bitMap bytesPerRow];
   pixelSize = [bitMap bitsPerPixel]/8;

   planar = [bitMap isPlanar];

   for ( y = 0; y < ath; y++ )
   {
      for ( x = 0; x < atw; x++ )
      {
         u_short c;

         // Read the data in the bitmap
         if ( planar )
         {
            color[RED_PLANE] = plane[0][y*rowSize+x];
            color[GREEN_PLANE] = plane[1][y*rowSize+x];
            color[BLUE_PLANE] = plane[2][y*rowSize+x];
         }
         else
         {
            color[RED_PLANE] = plane[0][y*rowSize+x*pixelSize];
            color[GREEN_PLANE] = plane[0][y*rowSize+x*pixelSize+1];
            color[BLUE_PLANE] = plane[0][y*rowSize+x*pixelSize+2];
         }

         // Convert to monochrome, if needed
         if ( nPlanes == 1 )
            color[0] = (color[RED_PLANE] 
                        + color[GREEN_PLANE] 
                        + color[BLUE_PLANE]) / 3.0;

         // Fill in the sample buffer
         for( c = 0; c < nPlanes; c++ )
            SET_SAMPLE(sample[c],precision,x,y,width,color[c]);
      }
   }
}

@implementation MyCocoaImageReader

+ (void) initialize
{
   pthread_mutex_init( &offScreenLock, NULL );
}

+ (void) lynkeosFileTypes:(NSArray**)fileTypes
{
   *fileTypes = [NSImage imageFileTypes];
}

+ (BOOL) hasCustomImageBuffer { return( NO ); }

- (id) initWithURL:(NSURL*)url
{
   self = [super init];

   if ( self != nil )
   {
      NSImage *image;

      _path = [[url path] retain];

      image = [self getNSImage];
      if ( image != nil )
      {
         NSImageRep *rep = [image bestRepresentationForDevice:nil];

         _size = LynkeosMakeIntegerSize([rep pixelsWide],[rep pixelsHigh]);
      }
      else
      {
         [self release];
         self = nil;
      }
   }

   return( self );
}

- (void) dealloc
{
   [_path release];
   [super dealloc];
}

- (void) imageWidth:(u_short*)w height:(u_short*)h
{
   *w = _size.width;
   *h = _size.height;
}

// We deal only with RGB images
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
   return( [[[NSImage alloc] initWithContentsOfFile: _path] autorelease] );
}

- (void) getImageSample:(void * const * const)sample 
          withPrecision:(floating_precision_t)precision
             withPlanes:(u_short)nPlanes
                    atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
              lineWidth:(u_short)width
{
   getImageSample( sample, precision, nPlanes, x, y, w, h, width, 
                   [self getNSImage], _size );
}

- (NSDictionary*) getMetaData
{
   return( nil );
}

- (id <LynkeosImageBuffer>) getCustomImageSampleAtX:(u_short)x Y:(u_short)y 
                                                  W:(u_short)w H:(u_short)h
{
   NSAssert( NO, @"MyCocoaImageReader does not provides custom image class" );
   return( nil );
}

- (BOOL) canBeCalibratedBy:(id <LynkeosFileReader>)reader
{
   NSAssert( NO, @"MyCocoaImageReader does not provides custom image class" );
   return( NO );
}
@end

#if !defined GNUSTEP
@interface MyPixelBufferContainer : NSObject
{
@public
   CVPixelBufferRef _pixbuf;
}
- (id) initWithPixelBuffer:(CVPixelBufferRef)pixbuf ;
@end

@implementation MyPixelBufferContainer
- (id) initWithPixelBuffer:(CVPixelBufferRef)pixbuf
{
   if ( (self = [self init]) != nil )
   {
      _pixbuf = pixbuf;
      CVPixelBufferRetain( _pixbuf );
   }
   return( self );
}

- (void) dealloc
{
   CVPixelBufferRelease(_pixbuf);
   [super dealloc];
}
@end

@interface MyQuickTimeReader(Private)
- (CVPixelBufferRef) getPixelBufferAtIndex:(u_long)index ;
@end

@implementation MyQuickTimeReader(Private)
- (CVPixelBufferRef) getPixelBufferAtIndex:(u_long)index
{
   NSString *key = [_url stringByAppendingFormat:@"&%06d",index];
   LynkeosObjectCache *movieCache = [LynkeosObjectCache movieCache];
   MyPixelBufferContainer *pix;
   CVPixelBufferRef img;

   if ( movieCache != nil &&
        (pix=(MyPixelBufferContainer*)[movieCache getObjectForKey:key]) != nil )
   {
      CVPixelBufferRetain( pix->_pixbuf );
      return( pix->_pixbuf );
   }

   Movie qtMovie = [_movie quickTimeMovie];
   OSStatus err;

   NSAssert( index < _imageNumber, @"Access outside the movie" );

   // Go to the required time
   // Try to avoid skipping frames because of multiprocessing
   BOOL doSkip = ( movieCache == nil
                   || index < _currentImage
                   || index > (_currentImage+numberOfCpus+1) );
   do
   {
      if ( index != _currentImage )
      {
         if ( doSkip )
            _currentImage = index;
         else
            _currentImage++;  // This fills the cache with images in between
         [_movie setCurrentTime:_times[_currentImage]];
         // Wait for image availability
         do
         {
            MoviesTask(qtMovie,0);
         } while( !QTVisualContextIsNewImageAvailable(_visualContext,NULL) );
      }

      // And get the pixel buffer content
      err = QTVisualContextCopyImageForTime( _visualContext, kCFAllocatorDefault,
                                            NULL, &img );
      if ( err != 0 )
         NSLog( @"QTVisualContextCopyImageForTime error %d", err );

      else if ( movieCache != nil )
         [movieCache setObject:
          [[[MyPixelBufferContainer alloc] initWithPixelBuffer:img] autorelease]
                        forKey:
                         [_url stringByAppendingFormat:@"&%06d",_currentImage]];
   } while ( index != _currentImage );

   return( img );
}
@end

@implementation MyQuickTimeReader

+ (void) load
{
   // Nothing to do, this is just to force the runtime to load this class
}

+ (void) lynkeosFileTypes:(NSArray**)fileTypes
{
   *fileTypes = [QTMovie movieUnfilteredFileTypes];
}

+ (BOOL) hasCustomImageBuffer { return( NO ); }

- (id) initWithURL:(NSURL*)url
{
   static const OSType vue = VisualMediaCharacteristic;
   NSError *qtErr = nil;
   Rect r;   
   u_long arraySize = K_TIME_PAGE_SIZE;

   if ( (self = [self init]) == nil )
      return( self );

   // Initialize the variables and open the movie
   _qtLock = [[NSLock alloc] init];
   _times = (QTTime*)malloc( arraySize*sizeof(QTTime) );
   _imageNumber = 0;
   _movie = [[QTMovie alloc] initWithURL:url error:&qtErr];
   _url = [[url absoluteString] retain];

   // Cycle through all tracks and media to find the movie characteristics
   NSEnumerator *tracks =
                 [[_movie tracksOfMediaType:QTMediaTypeVideo] objectEnumerator];
   _nPlanes = 0;
   _pixmapPlanes = 0;
   _bitsPerPixel = 8;
   ImageDescriptionHandle desc =
                              (ImageDescriptionHandle)NewHandle(sizeof(Handle));
   QTTrack *track;
   while( (track = [tracks nextObject]) != nil )
   {
      Media media = [[track media] quickTimeMedia];
      int sampleIdx, nSamples = GetMediaSampleDescriptionCount(media);
      for( sampleIdx = 1; sampleIdx <= nSamples; sampleIdx++ )
      {
         GetMediaSampleDescription(media, sampleIdx,
                                   (SampleDescriptionHandle)desc);
         if ( *desc != NULL )
         {
            // QuickTime doc says RGB up to 32, grayscale above
            if( (*desc)->depth <= 32 )
            {
               _pixmapPlanes = 3;
               _bitsPerPixel = 8;   // RGB movie is always 8 bits

               // But some grayscale movie are built as 8 bit indexed with a
               // grayscale color table
               if ( (*desc)->depth == 8 && (*desc)->clutID == 0 )
               {
                  CTabHandle ctab;
                  GetImageDescriptionCTable(desc, &ctab);
                  if ( *ctab != nil )
                  {
                     // Grayscale has all color entries r, g and b equal
                     int colorIdx;
                     for( colorIdx = 0; colorIdx <= (*ctab)->ctSize; colorIdx++ )
                     {
                        RGBColor c = (*ctab)->ctTable[colorIdx].rgb;
                        if ( c.red != c.green || c.red != c.blue )
                        {
                           _nPlanes = 3;
                           break;
                        }
                     }
                     if ( _nPlanes == 0 )
                        _nPlanes = 1; // Read only one component as it is gray
                     DisposeHandle((Handle)ctab);
                  }
               }
               if ( _nPlanes == 0 )
                  _nPlanes = 3; // Could not qualify as a grayscale
            }
            else if ( _nPlanes == 0 ) // Gray only if all tracks are gray
            {
               _pixmapPlanes = 1;
               _nPlanes = 1;
               // QTPixelBufferContext seem to handle only 16 bits grayscale
               _bitsPerPixel = 16;
            }
         }
      }
   }
   DisposeHandle((Handle)desc);

   if ( _movie == nil )
   {
      if ( qtErr != nil )
         NSLog( @"Error creating QTMovie %@", [qtErr localizedDescription] );
      [self release];
      return( nil );
   }

   Movie qt = [_movie quickTimeMovie];
   GetMovieBox( qt, &r );
   _size = LynkeosMakeIntegerSize( r.right - r.left, r.bottom - r.top );

   // Create a pixel buffer visual context and attach it to the movie
   OSType pixFormat;
   if ( _pixmapPlanes == 1 )
   {
      // There seems to be no 8 bit grayscale in Core Video
      pixFormat = k16GrayPixelFormat;
   }
   else // Assumption is made that QT supports either grayscale or RGB
   {
      if ( _bitsPerPixel == 8 )
         pixFormat = k24RGBPixelFormat;
      else
         pixFormat = k48RGBPixelFormat;
   }
   NSDictionary *ctxOptions =
      [NSDictionary dictionaryWithObject:
         [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInt:_size.width], kCVPixelBufferWidthKey,
            [NSNumber numberWithInt:_size.height], kCVPixelBufferHeightKey,
            [NSNumber numberWithInt:pixFormat], kCVPixelBufferPixelFormatTypeKey,
            nil]
                                  forKey:
                           (NSString*)kQTVisualContextPixelBufferAttributesKey];
   OSStatus osErr = QTPixelBufferContextCreate( kCFAllocatorDefault,
                                                (CFDictionaryRef)ctxOptions,
                                                &_visualContext );
   if ( osErr != 0 )
   {
      NSLog( @"QTPixelBufferContextCreate error %d", osErr );
      [self release];
      self = nil;
      return( self );
   }
   osErr = SetMovieVisualContext( qt, _visualContext );
   if ( osErr != 0 )
   {
      NSLog( @"SetMovieVisualContext error %d", osErr );
      [self release];
      self = nil;
      return( self );
   }

   // Extract the time of each frame
   QTTime t = [_movie currentTime];
   TimeValue movieTime = t.timeValue;
   do
   {
      if ( _imageNumber >= arraySize )
      {
         arraySize += K_TIME_PAGE_SIZE;
         _times = (QTTime*)realloc( _times, 
                                    arraySize*sizeof(QTTime) );
      }

      t.timeValue = movieTime;
      _times[_imageNumber] = t;
      _imageNumber++;

      GetMovieNextInterestingTime( qt, nextTimeMediaSample, 1, &vue, movieTime,
                                   1, &movieTime, NULL );
   } while( movieTime >= 0 );

   if ( _imageNumber == 0 )
   {
      NSLog( @"No image found in movie %@", url );
      [self release];
      self = nil;
   }

   _currentImage = _imageNumber;

   return( self );
}

- (void) dealloc
{
   free( _times );
   [_qtLock release];
   [_movie release];
   QTVisualContextRelease(_visualContext );
   [_url release];

   [super dealloc];
}

- (void) imageWidth:(u_short*)w height:(u_short*)h
{
   *w = _size.width;
   *h = _size.height;
}

// We deal only with RGB images
- (u_short) numberOfPlanes
{
   return( _nPlanes );
}

- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax
{
   *vmin = 0.0;
   *vmax = 255.0;
}

- (u_long) numberOfFrames
{
   return( _imageNumber );
}

- (NSImage*) getNSImageAtIndex:(u_long)index
{
   // Quicktime operations are not thread safe
   [_qtLock lock];

   CVPixelBufferRef img = [self getPixelBufferAtIndex:index];

   // Make a NSImage with that data
   if ( CVPixelBufferIsPlanar(img) )
   {
      [_qtLock unlock];
      NSAssert( NO, @"The graphic context should not be planar" );
   }

   NSString *colorSpace = (_pixmapPlanes == 1 ? NSCalibratedWhiteColorSpace
                                              : NSCalibratedRGBColorSpace);
   NSBitmapImageRep *bmap =
      [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                               pixelsWide:_size.width
                                               pixelsHigh:_size.height
                                            bitsPerSample:_bitsPerPixel
                                          samplesPerPixel:_pixmapPlanes
                                                 hasAlpha:NO
                                                 isPlanar:NO
                                           colorSpaceName:colorSpace
                                    bytesPerRow:CVPixelBufferGetBytesPerRow(img)
                                       bitsPerPixel:_bitsPerPixel*_pixmapPlanes]
                                                                   autorelease];

   CVPixelBufferLockBaseAddress(img,0);
   memcpy( [bmap bitmapData], CVPixelBufferGetBaseAddress(img),
           CVPixelBufferGetBytesPerRow(img)*_size.height );
   CVPixelBufferUnlockBaseAddress(img,0);

   CVPixelBufferRelease(img);
   [_qtLock unlock];

   NSImage *image =
      [[[NSImage alloc] initWithSize:NSSizeFromIntegerSize(_size)] autorelease];
   [image addRepresentation:bmap];

   return( image );
}

- (void) getImageSample:(void * const * const)sample atIndex:(u_long)index
          withPrecision:(floating_precision_t)precision
             withPlanes:(u_short)nPlanes
                    atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
              lineWidth:(u_short)width
{
   // Quicktime operations are not thread safe
   [_qtLock lock];

   CVPixelBufferRef img = [self getPixelBufferAtIndex:index];
   u_short dx, dy, p, rowSize, pixelSize;
   float color[3];
   void *plane;

   rowSize = CVPixelBufferGetBytesPerRow(img)*8/_bitsPerPixel;
   pixelSize = _bitsPerPixel*_pixmapPlanes/_bitsPerPixel;

   CVPixelBufferLockBaseAddress(img,0);
   plane = CVPixelBufferGetBaseAddress(img);
   for ( dy = 0; dy < h; dy++ )
   {
      for ( dx = 0; dx < w; dx++ )
      {
         for( p = 0; p < _nPlanes; p++ )
         {
            // Read the data in the bitmap
            if ( _bitsPerPixel == 8 )
               color[p] = ((u_char*)plane)[(y+dy)*rowSize+(x+dx)*pixelSize+p];
            else
               color[p] =
                     ((u_short*)plane)[(y+dy)*rowSize+(x+dx)*pixelSize+p]/256.0;
         }

         // Convert to monochrome, if needed
         if ( nPlanes == 1 && _nPlanes != 1 )
         {
            float c = 0;
            for( p = 0; p < _nPlanes; p++ )
               c += color[p];
            color[0] = c / _nPlanes;
         }

         // Fill in the sample buffer
         for( p = 0; p < nPlanes; p++ )
         {
            if ( p < _nPlanes )
            {
               SET_SAMPLE(sample[p],precision,dx,dy,width,color[p]);
            }
            else
            {
               SET_SAMPLE(sample[p],precision,dx,dy,width,0.0);
            }
         }
      }
   }
   CVPixelBufferUnlockBaseAddress(img,0);

   CVPixelBufferRelease(img);
   [_qtLock unlock];
}

- (NSDictionary*) getMetaData
{
   return( nil );
}

- (id <LynkeosImageBuffer>) getCustomImageSampleAtIndex:(u_long)index
                                                atX:(u_short)x Y:(u_short)y 
                                                  W:(u_short)w H:(u_short)h
{
   NSAssert( NO, @"MyQuickTimeReader does not provides custom image class" );
   return( nil );
}

- (BOOL) canBeCalibratedBy:(id <LynkeosFileReader>)reader
{
   NSAssert( NO, @"MyQuickTimeReader does not provides custom image class" );
   return( NO );
}

@end
#endif
