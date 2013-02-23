//
//  Lynkeos
//  $Id: FFmpegReader.m 497 2010-12-29 15:26:59Z j-etienne $
//
//  Based on ffmpeg_access.c by Christophe JALADY.
//  Created by Jean-Etienne LAMIAUD on Mon Jun 27 2005.
//
//  Copyright (c) 2004-2005. Christophe JALADY
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

#include <LynkeosCore/LynkeosProcessing.h>
#include "MyCachePrefs.h"

#include "FFmpegReader.h"

#define K_TIME_PAGE_SIZE 256

@interface MyAVFrameContainer : NSObject
{
@public
   AVFrame *_frame;
}
- (id) initWithAVFrame:(AVFrame*)frame ;
@end

@implementation MyAVFrameContainer
- (id) initWithAVFrame:(AVFrame*)frame
{
   if ( (self = [self init]) != nil )
      _frame = frame;
   return( self );
}

- (void) dealloc
{
   av_free(((AVPicture *)(_frame))->data[0]);
   av_free(_frame);
   [super dealloc];
}
@end

/*!
 * @category FFmpegReader(Private)
 * @abstract Internals of the FFmpeg reader
 * @discussion This code is supposed to seek to the nearest previous key frame
 *   if needed, then to step through the frames up to the required frame.
 *   Due to some unpredictable behaviour in the key frames reporting and their
 *   time tagging : when a problem is detected, the key frame control structure
 *   is filled with only the first sequence frame. It is much slower, but (knock
 *   on wood) works.
 * @ingroup FileAccess
 */
@interface FFmpegReader(Private)

/*!
 * @method nextFrame
 * @abstract Access the next frame in the movie.
 * @result Wether a frame was succesfully read
 */
- (BOOL) nextFrame ;

/*!
 * @method getFrame:
 * @abstract Get and convert the needed frame
 * @param index The index of the frame to get
 */
- (AVFrame*) getFrame :(u_long) index ;

@end

@implementation FFmpegReader(Private)

- (BOOL) nextFrame
{
   int ret;
   int bytesDecoded;
   int frameFinished;

   // Decode packets until we have decoded a complete frame
   while (YES)
   {
      // Work on the current packet until we have decoded all of it
      while ( _bytesRemaining > 0 )
      {
         // Decode the next chunk of data
         bytesDecoded = avcodec_decode_video( _pCodecCtx, _pCurrentFrame,
                                              &frameFinished,
                                              _rawData, _bytesRemaining);

         // Was there an error?
         if ( bytesDecoded < 0 )
         {
            NSLog( @"Error while decoding frame" );
               return( NO );
         }

         _bytesRemaining -= bytesDecoded;
         _rawData += bytesDecoded;

         // Did we finish the current frame? Then we can return
         if ( frameFinished )
         {
            _nextIndex ++;
            return( YES );
         }
      }

      // Read the next packet, skipping all packets that aren't for this
      // stream
      do
      {
         // Free old packet
         if ( _packet.data != NULL )
            av_free_packet( &_packet );

         // Read new packet
         ret = av_read_frame(_pFormatCtx, &_packet);

      } while( ret >= 0 &&
               ( _packet.stream_index != _videoStream ) );

      if ( ret < 0 )
         break;

      _bytesRemaining = _packet.size;
      _rawData = _packet.data;
   }

   // Decode the rest of the last frame
   bytesDecoded = avcodec_decode_video( _pCodecCtx, _pCurrentFrame, 
                                        &frameFinished, 
                                        _rawData, _bytesRemaining );

   // Free last packet
   if ( _packet.data != NULL )
      av_free_packet(&_packet);

   if ( frameFinished )
      _nextIndex++;

   return( frameFinished != 0 );
}

- (AVFrame*) getFrame :(u_long) index
{
   NSString *key =
             [NSString stringWithFormat:@"%s&%06d",_pFormatCtx->filename,index];
   LynkeosObjectCache *movieCache = [LynkeosObjectCache movieCache];
   MyAVFrameContainer *pix;

   if ( movieCache != nil &&
       (pix=(MyAVFrameContainer*)[movieCache getObjectForKey:key]) != nil )
      return( pix->_frame );

   int ret;
   BOOL success;

   // Do not move if the frame already read is asked
   if ( index == (_nextIndex - 1) )
      return( _pConvertedFrame );

   for( ;; )
   {
      // Go to the previous key frame if needed
      if ( index < _nextIndex
          || _times[index].keyFrame != _times[_nextIndex].keyFrame )
      {
         // Reset the decoder
         av_free_packet( &_packet );
         _bytesRemaining = 0;
         avcodec_flush_buffers(_pCodecCtx);

         ret = av_seek_frame( _pFormatCtx, _videoStream,
                             _times[index].timestamp,
                             AVSEEK_FLAG_BACKWARD );

         if ( ret == 0 )
            _nextIndex = _times[index].keyFrame;
         else
            _nextIndex = _numberOfFrames + 1;
      }
      else
         ret = 0;

      if ( ret == 0 )
      {
         success = YES;
         while ( _nextIndex <= index && success )
         {
            success = [self nextFrame];

            if ( !success )
               NSLog( @"Failed to advance to the next frame" );

            // Keep the lasts frames in cache for list processing
            if ( success
                 && ( _nextIndex == index+1
                      || (movieCache != nil 
                          && _nextIndex+numberOfCpus > index) ) )
            {
               if ( movieCache != nil || _pConvertedFrame == nil )
               {
                  uint8_t *buffer;
                  // Cache will take care of freeing the previous frame
                  _pConvertedFrame = avcodec_alloc_frame();

                  buffer = (uint8_t*) malloc( sizeof(uint8_t)*_pixbufSize );

                  // Assign appropriate parts of buffer to image planes
                  // in pFrameRGB
                  avpicture_fill( (AVPicture *)_pConvertedFrame, buffer,
                         PIX_FMT_RGB24, _pCodecCtx->width, _pCodecCtx->height );
               }

               // Convert the picture in a RGB buffer
               ret = sws_scale(_convert_ctx,
                           _pCurrentFrame->data, _pCurrentFrame->linesize,
                           0, _pCodecCtx->height, 
                           _pConvertedFrame->data, _pConvertedFrame->linesize);
/*
               ret = img_convert( (AVPicture *)_pConvertedFrame, PIX_FMT_RGB24,
                              (AVPicture*)_pCurrentFrame, _pCodecCtx->pix_fmt, 
                              _pCodecCtx->width, _pCodecCtx->height );
*/
               if ( ret > 0 )
               {
                  if ( movieCache != nil )
                     [movieCache setObject:
                        [[[MyAVFrameContainer alloc] initWithAVFrame:
                                                  _pConvertedFrame] autorelease]
                                    forKey:
                                       [NSString stringWithFormat:@"%s&%06d",
                                           _pFormatCtx->filename,_nextIndex-1]];
               }
               else
                  NSLog( @"Image conversion failed" );
            }
         }
      }
      else
         NSLog( @"Seek to frame failed" );

      if ( (! success || ret <= 0)
          && (_times[index].keyFrame != 0 || _times[index].timestamp != 0) )
      { // Hack to try to read buggy sequences (or which makes FFmpeg bug ;o)
         unsigned int i;
         NSLog( @"Trying to revert to sequential read" );
         for( i = 1; i < _numberOfFrames; i++ )
         {
            _times[i].keyFrame = 0;
            _times[i].timestamp = 0;
         }
         _nextIndex = _numberOfFrames;
      }
      else
         // Succeeded or hopeless
         break;
   }

   if( !success || ret <= 0 )
   {
      av_freep( &_pConvertedFrame );
      _pConvertedFrame = NULL;
   }

   return( _pConvertedFrame );
}

@end

@implementation FFmpegReader

+ (void) load  // It has the added benefit to force the runtime to load the class
{
   // Register all formats and codecs
   av_register_all();
}   

+ (void) lynkeosFileTypes:(NSArray**)fileTypes
{
   *fileTypes = [NSArray arrayWithObjects: @"avi",@"mpeg",@"mpg",@"mp4",@"wmv",nil];
}

+ (BOOL) hasCustomImageBuffer { return( NO ); }

- (id) init
{
   self = [super init];
   if ( self != nil )
   {
      _pFormatCtx = NULL;
      _pCodecCtx = NULL;
      _pCurrentFrame = NULL;
      _pConvertedFrame = NULL;
      _convert_ctx = NULL;
      _videoStream = -1;
      _packet.data = NULL;
      _bytesRemaining = 0;
      _numberOfFrames = 0;
      _nextIndex = 0;
      _mutex = [[NSLock alloc] init];
      _times = NULL;
   }
   return( self );
}

- (id) initWithURL:(NSURL*)url
{
   unsigned int i;
   int      ret;
   AVCodec *pCodec;
   u_long   arraySize;
   BOOL     validFrame;
   int64_t  /*startTime, timestamp,*/ keyTimestamp;
   u_long   keyIndex;

   self = [self init];

   if ( self != nil )
   {
      // Open video file
      ret = av_open_input_file( &_pFormatCtx, 
                                [[url path] fileSystemRepresentation], 
                                NULL, 0, NULL );
      if ( ret != 0 )
      {
         NSLog( @"Could not open file %@", [url absoluteString] );
         [self release];
         return( nil );
      }

      // Retrieve stream information
      ret = av_find_stream_info(_pFormatCtx);
      if ( ret < 0 )
      {
         NSLog( @"Could not find any stream info");
         [self release];
         return( nil );
      }

      // Find the first video stream
      _videoStream = -1;
      for ( i = 0; i < _pFormatCtx->nb_streams; i++ )
      {
         if( _pFormatCtx->streams[i]->codec->codec_type == CODEC_TYPE_VIDEO )
         {
            _videoStream = i;
            break;
         }
      }

      if( _videoStream == -1 )
      {
         NSLog( @"Could not find a video stream");
         [self release];
         return( nil );
      }

      // Get a pointer to the codec context for the video stream
      _pCodecCtx = _pFormatCtx->streams[_videoStream]->codec;

      // Find the decoder for the video stream
      pCodec = avcodec_find_decoder(_pCodecCtx->codec_id);
      if ( pCodec == NULL )
      {
         NSLog( @"Codec not found");
         [self release];
         return( nil );
      }

      // Inform the codec that we can handle truncated bitstreams -- i.e.,
      // bitstreams where frame boundaries can fall in the middle of packets
      if ( pCodec->capabilities & CODEC_CAP_TRUNCATED )
         _pCodecCtx->flags |= CODEC_FLAG_TRUNCATED;

      // Open codec
      if ( avcodec_open(_pCodecCtx, pCodec) < 0 )
      {
         NSLog( @"Can't open the codec" );
         [self release];
         return( nil );
      }

      // Allocate video frame
      _pCurrentFrame = avcodec_alloc_frame();

      // Determine required buffer size and allocate buffer
      _pixbufSize = avpicture_get_size( PIX_FMT_RGB24, 
                                     _pCodecCtx->width, _pCodecCtx->height );

      // Allocate a RGB converter
      _convert_ctx = sws_getCachedContext(_convert_ctx,
                                    _pCodecCtx->width, _pCodecCtx->height, 
                                    _pCodecCtx->pix_fmt, 
                                    _pCodecCtx->width, _pCodecCtx->height,
                                    PIX_FMT_RGB24, SWS_BICUBIC, 
                                    NULL, NULL, NULL);
      if(_convert_ctx == NULL)
      {
         NSLog(@"Cannot initialize the conversion context!");
         [self release];
         return( nil );
      }

      // Get the frames times
      arraySize = 0;
//      startTime = _pFormatCtx->streams[_videoStream]->start_time;
      //frameDuration = (int64_t)
      //          ((double)_pFormatCtx->streams[_videoStream]->r_frame_rate.den
      //	  / (double)_pFormatCtx->streams[_videoStream]->r_frame_rate.num
      //	  * (double)_pFormatCtx->streams[_videoStream]->time_base.den
      //	  / (double)_pFormatCtx->streams[_videoStream]->time_base.num
      //	  + 0.5 );
//      timestamp = startTime;
      keyIndex = 0;
      keyTimestamp = 0/*startTime*/;
      for( validFrame = YES; validFrame; )
      {
         validFrame = [self nextFrame];

         if ( validFrame )
         {
            if ( _numberOfFrames >= arraySize )
            {
               arraySize += K_TIME_PAGE_SIZE;
               _times = (KeyFrames_t*)realloc( _times, 
                                               arraySize*sizeof(KeyFrames_t) );
            }
/*
            if ( _pCurrentFrame->key_frame )
            {
               keyTimestamp = timestamp;
               keyIndex = _numberOfFrames;
            }
 */
            _times[_numberOfFrames].timestamp = keyTimestamp;
            _times[_numberOfFrames].keyFrame = keyIndex;

            _numberOfFrames ++;
//            timestamp = _pFormatCtx->streams[_videoStream]->cur_dts;
         }
      }
      // We are now pointing beyond sequence end
      _nextIndex = _numberOfFrames + 1;
   }

   return( self );
}

- (void) dealloc
{
   [_mutex release];
   if ( _pCodecCtx != NULL )
      avcodec_close(_pCodecCtx);
   if ( [LynkeosObjectCache movieCache] != nil && _pConvertedFrame != NULL )
   {
      av_free(((AVPicture *)(_pConvertedFrame))->data[0]);
      av_free(_pConvertedFrame);
   }
   if ( _pCurrentFrame != NULL )
      av_free(_pCurrentFrame);
   if ( _convert_ctx != NULL )
      sws_freeContext( _convert_ctx );
   if ( _packet.data != NULL )
      av_free_packet( &_packet );
   if ( _pFormatCtx != NULL )
      av_close_input_file( _pFormatCtx );
   if ( _times != NULL )
      free( _times );

   [super dealloc];
}

- (void) imageWidth:(u_short*)w height:(u_short*)h
{   
   *w = _pCodecCtx->width;
   *h = _pCodecCtx->height;
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

- (u_long) numberOfFrames
{
   return( _numberOfFrames );
}

- (NSImage*) getNSImageAtIndex:(u_long)index
{
   NSImage *image = nil;
   NSBitmapImageRep* bitmap;

   NSAssert( index < _numberOfFrames, @"Access beyond sequence end" );

   // Create a RGB bitmap
   bitmap = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                   pixelsWide:_pCodecCtx->width
                                                   pixelsHigh:_pCodecCtx->height
                                                  bitsPerSample:8
                                                samplesPerPixel:3
                                                       hasAlpha:NO
                                                       isPlanar:NO
                                       colorSpaceName:NSCalibratedRGBColorSpace
                                                    bytesPerRow:0
                                                   bitsPerPixel:24]
                                                                   autorelease];

   if ( bitmap != nil )
   {
      u_long lineLength = _pCodecCtx->width*3;
      u_char *pixels = (u_char*)[bitmap bitmapData];
      int bpr = [bitmap bytesPerRow];
      AVFrame *frame;
      u_short y;

      [_mutex lock];

      frame = [self getFrame:index];

      if ( frame != NULL )
      {
         for( y = 0; y < _pCodecCtx->height; y++ )
            memcpy( &pixels[y*bpr],
                    frame->data[0]+y*frame->linesize[0],
                    lineLength );
      }

      [_mutex unlock];

      image = [[[NSImage alloc] initWithSize:NSMakeSize(_pCodecCtx->width,
                                                       _pCodecCtx->height)]
                                                                   autorelease];

      if ( image != nil )
         [image addRepresentation:bitmap];
   }

   return( image );
}

- (void) getImageSample:(void * const * const)sample atIndex:(u_long)index
          withPrecision:(floating_precision_t)precision
             withPlanes:(u_short)nPlanes
                    atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
              lineWidth:(u_short)lineW
{
   u_short xs, ys, cs;

   NSAssert( index < _numberOfFrames, @"Access beyond sequence end" );
   NSAssert( x+w <= _pCodecCtx->width && y+h <= _pCodecCtx->height, 
             @"Sample at least partly outside the image" );

   [_mutex lock];

   AVFrame *frame;
   frame = [self getFrame:index];

   if ( frame == NULL )
   {
      [_mutex unlock];
      NSAssert( NO, @"Could not access FFMpeg frame" );
   }

   for ( ys = 0; ys < h; ys++ )
   {
      for( xs = 0; xs < w; xs++ )
      {
         u_char *v = frame->data[0]
                     + (y+ys)*frame->linesize[0] + (x+xs)*3;

         if ( nPlanes == 1 )
         {
            // Convert to monochrome
            SET_SAMPLE( sample[0],precision,xs,ys,lineW, 
                        (v[0]+v[1]+v[2])/3.0 );
         }
         else
         {
            for( cs = 0; cs < nPlanes; cs++ )
               SET_SAMPLE( sample[cs],precision,xs,ys,lineW, v[cs] );
         }
      }
   }

   [_mutex unlock];
}

- (NSDictionary*) getMetaData 
{
   return( nil );
}

- (id <LynkeosImageBuffer>) getCustomImageSampleAtIndex:(u_long)index
                                                    atX:(u_short)x Y:(u_short)y 
                                                      W:(u_short)w H:(u_short)h ;
{
   NSAssert( NO, @"FFmpegReader does not provides custom image class" );
   return( nil );
}

- (BOOL) canBeCalibratedBy:(id <LynkeosFileReader>)reader
{
   NSAssert( NO, @"FFmpegReader does not provides custom image class" );
   return( NO );
}

@end
