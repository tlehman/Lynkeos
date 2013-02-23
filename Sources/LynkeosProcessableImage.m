//
//  Lynkeos
//  $Id: LynkeosProcessableImage.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sat Aug 11 2007.
//  Copyright (c) 2007-2008. Jean-Etienne LAMIAUD
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
#include <math.h>

#include "LynkeosProcessableImage.h"

static NSString * const K_BLACK_LEVEL_KEY =  @"blackLevel";
static NSString * const K_WHITE_LEVEL_KEY =  @"whiteLevel";
static NSString * const K_GAMMA_CORRECTION_KEY = @"gammaCorrect";
//! Key for saving the stacked image
static NSString * const K_IMAGE_KEY =        @"originalImage";
//! Key for saving the parameters
static NSString * const K_PARAMETERS_KEY =   @"params";
static NSString * const K_PLANELEVELS_SET_KEY = @"planeLevelsSet";

@interface LynkeosProcessableImage(Private)
- (void) resetRenderParameters ;
- (void) freeRenderParameters ;
//! @abstract Perform inverse Fourier transform if needed
- (void) goIntoImageSpace ;
@end

@implementation LynkeosProcessableImage(Private)
- (void) resetRenderParameters
{
   ushort c;

   for( c = 0; c <= _nPlanes; c++ )
   {
      _black[c] = 0.0;
      _white[c] = -1.0;
      _gamma[c] = 1.0;
   }
   _planeLevelsAreSet = NO;
}

- (void) freeRenderParameters
{
   if ( _black != NULL )
      free( _black );
   _black = NULL;
   if ( _white != NULL )
      free( _white );
   _white = NULL;
   if ( _gamma != NULL )
      free( _gamma );
   _gamma = NULL;
}

- (void) goIntoImageSpace
{
   double vmin, vmax;
   NSAssert( _processedImage == nil,
             @"Processed spectrum and modified image are set together" );
   [_processedSpectrum inverseTransform];
   _processedImage = _processedSpectrum;
   _processedSpectrum = nil;

   if ( _black == NULL || _white == NULL || _gamma == NULL )
   {
      _black = (double*)malloc( (_nPlanes+1)*sizeof(double) );
      _white = (double*)malloc( (_nPlanes+1)*sizeof(double) );
      _gamma = (double*)malloc( (_nPlanes+1)*sizeof(double) );

      [self resetRenderParameters];
   }

   [_processedImage getMinLevel:&vmin maxLevel:&vmax];
   if ( _white[_nPlanes] < _black[_nPlanes]
        || _white[_nPlanes] <= vmin || _black[_nPlanes] >= vmax )
   {
      _black[_nPlanes] = vmin;
      _white[_nPlanes] = vmax;
      _planeLevelsAreSet = NO;
   }

   if ( !_planeLevelsAreSet )
   {
      u_short c;
      for( c  = 0; c < _nPlanes; c++ )
      {
         _black[c] = vmin;
         _white[c] = vmax;
      }
   }
}
@end

@implementation LynkeosProcessableImage

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _parameters = [[LynkeosProcessingParameterMgr alloc] init];
      _originalImage = nil;
      _intermediateImage = nil;
      _processedImage = nil;
      _processedSpectrum = nil;
      _imageSequenceNumber = 0;
      _originalSequenceNumber = 0;
      _size = LynkeosMakeIntegerSize(0,0);
      _nPlanes = 0;
      _black = NULL;
      _white = NULL;
      _gamma = NULL;
      _planeLevelsAreSet = NO;
   }

   return( self );
}

- (void) dealloc
{
   if ( _processedImage != nil && _processedImage != _originalImage )
      [_processedImage release];
   if ( _originalImage != nil )
      [_originalImage release];
   if ( _processedSpectrum != nil )
      [_processedSpectrum release];
   if ( _parameters != nil )
      [_parameters release];
   [self freeRenderParameters];

   [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
   // Save the processed image
   if ( _originalImage != nil )
      [encoder encodeObject:_originalImage forKey:K_IMAGE_KEY];

   // Then the parameters
   [encoder encodeObject:[_parameters getDictionary] forKey:K_PARAMETERS_KEY];

   // Build a NSArray of NSNumbers to encode the levels
   if ( _black != NULL && _white != NULL && _gamma != NULL )
   {
      NSMutableArray *b = [NSMutableArray arrayWithCapacity:_nPlanes+1],
      *w = [NSMutableArray arrayWithCapacity:_nPlanes+1],
      *g = [NSMutableArray arrayWithCapacity:_nPlanes+1];
      u_short c;
      for( c = 0; c <= _nPlanes; c++ )
      {
         [b addObject:[NSNumber numberWithDouble:_black[c]]];
         [w addObject:[NSNumber numberWithDouble:_white[c]]];
         [g addObject:[NSNumber numberWithDouble:_gamma[c]]];
      }

      [encoder encodeObject:b forKey:K_BLACK_LEVEL_KEY];
      [encoder encodeObject:w forKey:K_WHITE_LEVEL_KEY];
      [encoder encodeObject:g forKey:K_GAMMA_CORRECTION_KEY];
   }
   [encoder encodeBool:_planeLevelsAreSet forKey:K_PLANELEVELS_SET_KEY];
}

- (id)initWithCoder:(NSCoder*)decoder	// This is also an initialization
{
   if ( (self = [self init]) != nil )
   {
      // Get the image, if any
      _originalImage = [decoder decodeObjectForKey:K_IMAGE_KEY];

      if ( _originalImage != nil )
      {
         [_originalImage retain];
         _processedImage = _originalImage;
         _size.width = [_originalImage width];
         _size.height = [_originalImage height];
         _nPlanes = [_originalImage numberOfPlanes];
      }

      // Get the parameters
      if ( [decoder containsValueForKey:K_PARAMETERS_KEY] )
         [_parameters setDictionary:
                                 [decoder decodeObjectForKey:K_PARAMETERS_KEY]];

      // Try to get the black and white levels
      NSArray *b, *w, *g;
      u_short c;
      b = [decoder decodeObjectForKey:K_BLACK_LEVEL_KEY];
      w = [decoder decodeObjectForKey:K_WHITE_LEVEL_KEY];
      g = [decoder decodeObjectForKey:K_GAMMA_CORRECTION_KEY];

      if ( b != nil && w != nil && g != nil )
      {
         if( (u_short)[b count] != (_nPlanes+1)
             || (u_short)[w count] != (_nPlanes+1)
             || (u_short)[g count] != (_nPlanes+1) )
            NSLog(@"Render parameters number is inconsistent with number"
                  " of planes" );
         else
         {
            _black = (double*)malloc( sizeof(double)*(_nPlanes+1) );
            _white = (double*)malloc( sizeof(double)*(_nPlanes+1) );
            _gamma = (double*)malloc( sizeof(double)*(_nPlanes+1) );

            for( c = 0; c <= _nPlanes; c++ )
            {
               _black[c] = [[b objectAtIndex:c] doubleValue];
               _white[c] = [[w objectAtIndex:c] doubleValue];
               _gamma[c] = [[g objectAtIndex:c] doubleValue];
            }
         }

         _planeLevelsAreSet = [decoder decodeBoolForKey:K_PLANELEVELS_SET_KEY];
      }
   }

   return( self );
}

- (u_short) numberOfPlanes { return( _nPlanes ); }
- (LynkeosIntegerSize) imageSize { return( _size ); }

- (id <LynkeosImageBuffer>) getImage
{
   if ( _processedSpectrum != nil )
      [self goIntoImageSpace];
   return( _processedImage );
}

- (id <LynkeosImageBuffer>) getOriginalImage { return( _originalImage ); }

- (u_long) getSequenceNumber
{
   return( _imageSequenceNumber );
}

- (NSImage*) getNSImage
{   
   NSImage *image = nil;

   // Perform inverse transform now if needed
   if ( _processedSpectrum != nil )
      [self goIntoImageSpace];

   if ( _processedImage != nil && _white[_nPlanes] > _black[_nPlanes] )
   {
      image = [[[NSImage alloc] initWithSize:
                                       NSMakeSize([_processedImage width],
                                                  [_processedImage height])]
                                                                   autorelease];
      [image addRepresentation:[_processedImage getNSImageWithBlack:_black
                                                            white:_white
                                                            gamma:_gamma]];
   }

   return( image );
}

- (void) getImageSample:(LynkeosStandardImageBuffer**)buffer 
                 inRect:(LynkeosIntegerRect)rect
{
   if ( _processedSpectrum != nil )
      [self goIntoImageSpace];

   if ( _processedImage == nil )
   {
      if ( *buffer != nil )
         [*buffer release];
      *buffer = nil;
      return;
   }

   if ( *buffer == nil )
      *buffer = [LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:_nPlanes
                                                        width:rect.size.width
                                                       height:rect.size.height];

   [_processedImage extractSample:[*buffer colorPlanes]
                                 atX:rect.origin.x Y:rect.origin.y
                           withWidth:rect.size.width height:rect.size.height
                     withPlanes:(*buffer)->_nPlanes lineWidth:(*buffer)->_padw];
}

- (void) getFourierTransform:(LynkeosFourierBuffer**)buffer 
                     forRect:(LynkeosIntegerRect)rect
              prepareInverse:(BOOL)prepareInverse
{
   if ( _processedSpectrum != nil && rect.origin.x == 0 && rect.origin.y == 0
        && rect.size.width == _size.width && rect.size.height == _size.height
        && *buffer == nil )
      *buffer = [[_processedSpectrum copy] autorelease];

   else
   {
      // Allocate a buffer if needed
      if ( *buffer == nil )
         *buffer = [[[LynkeosFourierBuffer alloc]
                     initWithNumberOfPlanes:_nPlanes
                                      width:rect.size.width
                                     height:rect.size.height
                                   withGoal:FOR_DIRECT|
                                          (prepareInverse ? FOR_INVERSE : 0)]
                                                                   autorelease];

      [self getImageSample:buffer inRect:rect];
      // And transform it
      if ( *buffer != nil )
         [*buffer directTransform];
   }
}

- (void) setFourierTransform:(LynkeosFourierBuffer*)buffer
{
   NSAssert( buffer != nil, @"Invalid nil Fourier buffer" );

   if ( _processedImage != nil && _processedImage != _originalImage )
      [_processedImage release];
   _processedImage = nil;
   [buffer retain];
   if ( _processedSpectrum != nil )
      [_processedSpectrum release];
   _processedSpectrum = buffer;
   _imageSequenceNumber++;
   _size.width = _processedSpectrum->_w;
   _size.height = _processedSpectrum->_h;
   if ( _nPlanes != _processedSpectrum->_nPlanes )
   {
      [self freeRenderParameters];

      _nPlanes = _processedSpectrum->_nPlanes;

      _black = (double*)malloc( (_nPlanes+1)*sizeof(double) );
      _white = (double*)malloc( (_nPlanes+1)*sizeof(double) );
      _gamma = (double*)malloc( (_nPlanes+1)*sizeof(double) );

      [self resetRenderParameters];
   }

   // Notify for some change
   [_parameters notifyItemModification:self];
}

- (void) setImage:(LynkeosStandardImageBuffer*)buffer
{
   // Save the new processed image (and maybe original too)
   if ( buffer != nil && buffer != _originalImage )
      [buffer retain];
   if ( _processedImage != nil && _processedImage != _originalImage )
      [_processedImage release];
   if ( _processedSpectrum != nil )
   {
      [_processedSpectrum release];
      _processedSpectrum = nil;
   }
   _processedImage = buffer;
   _imageSequenceNumber++;

   if ( _processedImage != nil )
   {
      _size.width = [_processedImage width];
      _size.height = [_processedImage height];

      // Renew the rendering parameters if the number of planes has changed
      if ( _nPlanes != _processedImage->_nPlanes )
      {
         [self freeRenderParameters];

         _nPlanes = _processedImage->_nPlanes;
      }

      if ( _black == NULL || _white == NULL || _gamma == NULL )
      {
         _black = (double*)malloc( (_nPlanes+1)*sizeof(double) );
         _white = (double*)malloc( (_nPlanes+1)*sizeof(double) );
         _gamma = (double*)malloc( (_nPlanes+1)*sizeof(double) );

         [self resetRenderParameters];
      }

      double vmin, vmax;
      [_processedImage getMinLevel:&vmin maxLevel:&vmax];
      if ( _white[_nPlanes] < _black[_nPlanes]
          || _white[_nPlanes] <= vmin || _black[_nPlanes] >= vmax )
      {
         _black[_nPlanes] = vmin;
         _white[_nPlanes] = vmax;
         _planeLevelsAreSet = NO;
      }

      if ( !_planeLevelsAreSet )
      {
         u_short c;
         for( c = 0; c < _nPlanes; c++ )
         {
            _black[c] = vmin;
            _white[c] = vmax;
         }
      }
   }
   else
   {
      _size.width = 0;
      _size.height = 0;
      _nPlanes = 0;
      [self freeRenderParameters];
   }   

   // Notify for some change
   [_parameters notifyItemModification:self];
}

- (u_long) originalImageSequence
{
   return( _originalSequenceNumber );
}

- (id <LynkeosImageBuffer>) getResult
{
   if ( _processedImage != nil )
      return( _processedImage );
   else if ( _processedSpectrum != nil )
      return( _processedSpectrum );
   else
      return( nil );
}

- (void) setResult:(id <LynkeosImageBuffer> )result
{
   if ( [result isKindOfClass:[LynkeosFourierBuffer class]]
        && [(LynkeosFourierBuffer*)result isSpectrum] )
      [self setFourierTransform:result];
   else
      [self setImage:result];
}

- (void) setOriginalImage:(LynkeosStandardImageBuffer*)buffer
{
   [_originalImage release];
   if ( _processedImage == _originalImage )
      _processedImage = nil;
   _originalImage = buffer;
   if ( _originalImage != nil )
      [_originalImage retain];

   [self revertToOriginal];
   _originalSequenceNumber++;
}

- (void) revertToOriginal
{
   [self setImage:_originalImage];
}

- (BOOL) isOriginal
{
   return( _processedImage == _originalImage );
}

- (BOOL) isProcessed
{
   return( YES );
}

- (void) setBlackLevel :(double)black whiteLevel:(double)white
                  gamma:(double)gamma
{
   NSAssert( white > black, @"Inconsistent black and white levels" );
   NSAssert( _black != NULL && _white != NULL && _gamma != NULL,
             @"Setting levels on void image item" );

   _black[_nPlanes] = black;
   _white[_nPlanes] = white;
   _gamma[_nPlanes] = gamma;

   // Notify for some change
   [_parameters notifyItemModification:self];
}

- (void) setBlackLevel:(double)black whiteLevel:(double)white
                 gamma:(double)gamma forPlane:(u_short)plane
{
   NSAssert( white > black, @"Inconsistent black and white levels" );
   NSAssert( _black != NULL && _white != NULL && _gamma != NULL,
             @"Setting levels on void image item" );

   _planeLevelsAreSet = YES;
   _black[plane] = black;
   _white[plane] = white;
   _gamma[plane] = gamma;

   // Notify for some change
   [_parameters notifyItemModification:self];
}

- (BOOL) getBlackLevel:(double*)black whiteLevel:(double*)white
                 gamma:(double*)gamma
{
   if ( _white != NULL && _black != NULL && _gamma != NULL
        && _white[_nPlanes] > _black[_nPlanes] )
   {
      *black = _black[_nPlanes];         
      *white = _white[_nPlanes];
      *gamma = _gamma[_nPlanes];
      return( YES );
   }
   else
   {
      *black = NAN;
      *white = NAN;
      *gamma = NAN;
      return( NO );
   }
}

- (BOOL) getBlackLevel:(double*)black whiteLevel:(double*)white
                 gamma:(double*)gamma forPlane:(u_short)plane
{
   if ( _white != NULL && _black != NULL && _gamma != NULL
        && _white[plane] > _black[plane] )
   {
      *black = _black[plane];         
      *white = _white[plane];
      *gamma = _gamma[plane];
      return( YES );
   }
   else
   {
      *black = NAN;
      *white = NAN;
      *gamma = NAN;
      return( NO );
   }
}

- (BOOL) getMinLevel:(double*)vmin maxLevel:(double*)vmax
{
   // Perform inverse transform if needed
   if ( _processedSpectrum != nil )
      [self goIntoImageSpace];

   if ( _processedImage != nil )
   {
      [_processedImage getMinLevel:vmin maxLevel:vmax];
      return( YES );
   }
   else
   {
      *vmin = NAN;
      *vmax = NAN;
      return( NO );
   }
}

- (BOOL) getMinLevel:(double*)vmin maxLevel:(double*)vmax
            forPlane:(u_short)plane
{
   // Perform inverse transform if needed
   if ( _processedSpectrum != nil )
      [self goIntoImageSpace];

   if ( _processedImage != nil )
   {
      [_processedImage getMinLevel:vmin maxLevel:vmax forPlane:plane];
      return( YES );
   }
   else
   {
      *vmin = NAN;
      *vmax = NAN;
      return( NO );
   }
}

- (id <LynkeosProcessingParameter>) getProcessingParameterWithRef:(NSString*)ref 
                                             forProcessing:(NSString*)processing
{
   return( [_parameters getProcessingParameterWithRef:ref
                                        forProcessing:processing goUp:YES] );
}

- (id <LynkeosProcessingParameter>) getProcessingParameterWithRef:(NSString*)ref 
                                             forProcessing:(NSString*)processing
                                                             goUp:(BOOL)goUp
{
   return( [_parameters getProcessingParameterWithRef:ref
                                        forProcessing:processing goUp:goUp] );
}

- (void) setProcessingParameter:(id <LynkeosProcessingParameter>)parameter
                        withRef:(NSString*)ref 
                  forProcessing:(NSString*)processing
{
   [_parameters setProcessingParameter:parameter withRef:ref 
                         forProcessing:processing];

   // Notify of the change
   [_parameters notifyItemModification:self];
}
@end
