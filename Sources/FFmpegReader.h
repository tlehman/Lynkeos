//
//  Lynkeos
//  $Id: FFmpegReader.h 497 2010-12-29 15:26:59Z j-etienne $
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

/*!
 * @header
 * @abstract Reader for image formats supported by the FFmpeg library.
 */
#ifndef __FFMPEGREADER_H
#define __FFMPEGREADER_H

#include "LynkeosFileReader.h"

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>

/**
 * \page libraries Libraries needed to compile Lynkeos
 * The FFmpeg reader class needs the FFmpeg library.
 * It can be found at http://ffmpeg.mplayerhq.hu/
 */

/*!
 * @struct KeyFrames_t
 * @abstract Structure used to retain the key frames position.
 * @discussion It is used to speed the seeking in the sequence.
 */
typedef struct
{
   u_long  keyFrame;       //!< Frame number of the key frame
   int64_t timestamp;      //!< Timestamp of the key frame
} KeyFrames_t;

/*!
 * @class FFmpegReader
 * @abstract Class for reading movie file formats non supported by Cocoa.
 * @ingroup FileAccess
 */
@interface FFmpegReader : NSObject <LynkeosMovieFileReader>
{
@private
   AVFormatContext  *_pFormatCtx;
   AVCodecContext   *_pCodecCtx;
   AVFrame          *_pCurrentFrame;      //!< Decoded frame
   struct SwsContext *_convert_ctx;       //!< Context for RGB conversion
   AVFrame          *_pConvertedFrame;    //!< Frame converted to RGB format
   int               _pixbufSize;         //!< RGB buf size in converted frame
   int               _videoStream;
   AVPacket          _packet;             //!< Last packet read
   int               _bytesRemaining;     //!< Remaining length to be decoded
   uint8_t          *_rawData;            //!< Remaining data to be decoded
   u_long            _numberOfFrames;
   KeyFrames_t      *_times;
   NSLock           *_mutex;
   u_long	     _nextIndex;
}

@end

#endif
