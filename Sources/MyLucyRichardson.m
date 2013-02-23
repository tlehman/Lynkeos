//
//  Lynkeos
//  $Id: MyLucyRichardson.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Nov 2 2007.
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

#include "processing_core.h"
#include "MyLucyRichardson.h"
#include "LynkeosStandardImageBufferAdditions.h"
#include "MyGeneralPrefs.h"

static NSString * const K_PSF_IMAGE_KEY = @"psf";
static NSString * const K_NBITERATIONS_KEY = @"iterations";

static void constrainPositive( LynkeosStandardImageBuffer *buf )
{
   const double MinPositive = 1.0/65535.0;
   short x, y, c;
   double minimum;

   minimum = 1.0;

   for ( c = 0; c < buf->_nPlanes; c++ )
   {
      for ( y = 0; y < buf->_h; y++ )
      {
         for ( x = 0; x < buf->_w; x++ )
         {
            double v = colorValue(buf,x,y,c);

            if ( v < minimum )
               minimum = v;
         }
      }
   }

   if ( minimum < MinPositive )
   {
      minimum = MinPositive - minimum;

      for ( c = 0; c < buf->_nPlanes; c++ )
         for ( y = 0; y < buf->_h; y++ )
            for ( x = 0; x < buf->_w; x++ )
               colorValue(buf,x,y,c) += minimum;
   }
}

@implementation MyLucyRichardsonParameters
- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _psf = nil;
      _numberOfIteration = 0;
   }

   return( self );
}

- (id) initWithPSF:(LynkeosStandardImageBuffer*)psf andIterations:(unsigned int)nb
{
   if ( (self = [self init]) != nil )
   {
      _psf = [psf retain];
      _numberOfIteration = nb;
   }

   return( self );
}

- (void) dealloc
{
   if ( _psf != nil )
      [_psf release];
   [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [super encodeWithCoder:encoder];
   [encoder encodeObject:_psf forKey:K_PSF_IMAGE_KEY];
   [encoder encodeInt:_numberOfIteration forKey:K_NBITERATIONS_KEY];
}

- (id) initWithCoder:(NSCoder *)decoder
{
   if ( (self = [super initWithCoder:decoder]) != nil )
   {
      _psf = [[decoder decodeObjectForKey:K_PSF_IMAGE_KEY] retain];
      _numberOfIteration = [decoder decodeIntForKey:K_NBITERATIONS_KEY];
   }

   return( self );
}
@end

@implementation MyLucyRichardson

+ (ParallelOptimization_t) supportParallelization
{
   return( [[NSUserDefaults standardUserDefaults] integerForKey:
                                                 K_PREF_IMAGEPROC_MULTIPROC]
            & FFTW3ThreadsOptimization);
}

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _psfSpectrum = nil;
      _numberOfIteration = 0;
      _delegate = nil;
   }

   return( self );
}

- (id <LynkeosProcessing>) initWithDocument:(id <LynkeosDocument>)document
                                 parameters:(id <NSObject>)params
                                  precision:(floating_precision_t)precision
{
   MyLucyRichardsonParameters *p = (MyLucyRichardsonParameters*)params;

   if ( (self = [self init]) != nil )
   {
      LynkeosStandardImageBuffer *psf = p->_psf;

      // Retrieve the point spread function
      _psfSpectrum =
         [[LynkeosFourierBuffer alloc] initWithNumberOfPlanes:psf->_nPlanes
                                                   width:psf->_w
                                                  height:psf->_h
                                                withGoal:FOR_DIRECT];
      [psf extractSample:[_psfSpectrum colorPlanes]
                     atX:0 Y:0 withWidth:psf->_w height:psf->_h
              withPlanes:psf->_nPlanes lineWidth:_psfSpectrum->_padw];
      // And make it a normalized spectrum
      [_psfSpectrum directTransform];
      [_psfSpectrum normalize];

      _numberOfIteration = p->_numberOfIteration;
      _delegate = p->_delegate ;
   }

   return( self );
}

- (void) dealloc
{
   if ( _psfSpectrum != nil )
      [_psfSpectrum release];
   [super dealloc];
}

- (void) processItem:(id <LynkeosProcessableItem>)item
{
   // Follow the same threads policy as selected for FFTW
   ParallelOptimization_t optim = FFTW3ThreadsOptimization &
                     [[NSUserDefaults standardUserDefaults] integerForKey:
                                                    K_PREF_IMAGEPROC_MULTIPROC];
   LynkeosFourierBuffer *image, *iterImage, *buffer;
   LynkeosIntegerRect r = {{0,0},{0,0}};
   unsigned int i;

   // Get the image to process
   r.size = [item imageSize];
   if( _psfSpectrum->_w != r.size.width || _psfSpectrum->_h != r.size.height )
   {
      NSLog(@"Lucy Richardson PSF is not the same size as the image" );
      return;
   }
   image = 
      [[LynkeosFourierBuffer alloc] initWithNumberOfPlanes:[item numberOfPlanes]
                                                width:r.size.width
                                               height:r.size.height
                                             withGoal:0];   
   [item getImageSample:&image inRect:r];
   constrainPositive( image );

   // Prepare intermediate results
   iterImage =
      [[LynkeosFourierBuffer alloc] initWithNumberOfPlanes:image->_nPlanes
                                                width:image->_w
                                               height:image->_h
                                             withGoal:FOR_DIRECT|FOR_INVERSE];
   if ( optim != 0 )
      [iterImage setOperatorsStrategy:ParallelizedStrategy];
   buffer =
      [[LynkeosFourierBuffer alloc] initWithNumberOfPlanes:image->_nPlanes
                                                width:image->_w
                                               height:image->_h
                                             withGoal:FOR_DIRECT|FOR_INVERSE];
   if ( optim != 0 )
      [buffer setOperatorsStrategy:ParallelizedStrategy];

   // Start the iteration with the image in the temorary result
   [image extractSample:[iterImage colorPlanes]
                    atX:0 Y:0 withWidth:r.size.width height:r.size.height
             withPlanes:iterImage->_nPlanes lineWidth:iterImage->_padw];

   // Iterate
   for( i = 0; i < _numberOfIteration; i++ )
   {
      // Compute P(x)*O(x)
      [iterImage extractSample:[buffer colorPlanes]
                              atX:0 Y:0
                        withWidth:r.size.width height:r.size.height
                       withPlanes:buffer->_nPlanes
                        lineWidth:buffer->_padw];
      [buffer directTransform];
      [buffer multiplyWith:_psfSpectrum result:buffer];
      [buffer inverseTransform];
      constrainPositive(buffer);

      // Compute I(x)/[P(x)*O(x)]
      [image divideBy:buffer result:buffer];

      // Compute ~P(-x)*[I(x)/[P(x)*O(x)]]
      [buffer directTransform];
      [buffer multiplyWithConjugateOf:_psfSpectrum result:buffer];
      [buffer inverseTransform];

      // Compute O(x) i
      [iterImage multiplyWith:buffer result:iterImage];

      // Copy the current result and inform the view if asked for
      if ( _delegate != nil )
      {
         [item setImage:[[iterImage copy] autorelease]];
         [_delegate performSelectorOnMainThread:@selector(iterationEnded)
                                     withObject:nil
                                  waitUntilDone:NO];
      }
   }

   // Save the result
   [item setImage:iterImage];

   // Clean up
   [image release];
   [iterImage release];
   [buffer release];
}

// Nothing to do
- (void) finishProcessing {}
@end
