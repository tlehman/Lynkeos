//
//  Lynkeos
//  $Id: MyImageListItem.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Tue Sep 30, 2003.
//  Copyright (c) 2003-2008. Jean-Etienne LAMIAUD
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

#import <AppKit/NSCell.h>

#include "LynkeosStandardImageBufferAdditions.h"
#include "MyPluginsController.h"
#include "ProcessStackManager.h"
#include "MyImageListItem.h"
#include "LynkeosFourierBuffer.h"

// V1 Compatibility includes
#ifndef NO_FILE_FORMAT_COMPATIBILITY_CODE
#include "LynkeosBasicAlignResult.h"
#include "MyImageAligner.h"
#include "MyImageAnalyzer.h"
#endif

#include "LynkeosColumnDescriptor.h"

static NSString * const K_URL_KEY	= @"url";
static NSString * const K_SELECTED_KEY	= @"selected";
static NSString * const K_TIME_KEY	= @"time";
static NSString * const K_INDEX_KEY	= @"index";
static NSString * const K_IMAGES_KEY	= @"images";
static NSString * const K_PARAMETERS_KEY = @"params";
static NSString * const K_MODBLACK_KEY  = @"black";
static NSString * const K_MODWHITE_KEY  = @"white";
static NSString * const K_GAMMA_CORRECTION_KEY = @"gamma";

NSString * const myImageListItemRef = @"MyImageListItem";
NSString * const myImageListItemDarkFrame = @"darkFrame";
NSString * const myImageListItemFlatField = @"flatField";

// V1 compatibility keys
static NSString * const  K_SEARCH_ORIGIN_KEY = @"search";
static NSString * const  K_ALIGN_OFFSET_KEY = @"align";
static NSString * const  K_QUALITY_KEY = @"quality";

// A bad hack for relative URL resolution (until I find a better solution)
extern NSString *basePath;

/*!
 * @category MyImageListItem(private)
 * @abstract Internal methods
 */
@interface MyImageListItem(private)
//! Common part of standard and decoder initializers
- (void) setURL:(NSURL*)url ;
//! Initializer for movie items
- (id) initWithParent:(MyImageListItem*)parent withIndex:(u_long)index ;
//! Set selection state with tri state option
- (void) setSelectionState :(int)state;
//! Update the container selection state according to the children
- (void) childrenSelectionChanged ;
//! Initialize the name of this item
- (void) setName :(NSString*)name ;
//! Perform inverse Fourier transform if needed
- (void) goIntoImageSpace ;
/*!
 * @method getCustomImageBufferInRect:
 * @abstract Read the custom image buffer if any, nil otherwise
 * @param rect The rectangle in which to extract the sample (it shall be 
 *   entirely inside the image)
 * @result The custom image buffer for this item
 */
- (id <LynkeosImageBuffer>) getCustomImageBufferInRect:(LynkeosIntegerRect)rect;

/*!
 * @method getDarkFrame
 * @abstract Shortcut to speed up calibration frames retrieval
 * @result The dark frame for this item
 */
- (id <LynkeosImageBuffer>) getDarkFrame ;

/*!
 * @method getFlatField
 * @abstract Shortcut to speed up calibration frames retrieval
 * @result The flat field for this item
 */
- (id <LynkeosImageBuffer>) getFlatField ;
@end


@implementation MyImageListItem(private)

- (void) setURL:(NSURL*)url
{
   if ( url != nil)
   {
      MyPluginsController *plugins =
                                  [MyPluginsController defaultPluginController];
      NSDictionary *myImageFileTypes = [plugins getImageReaders];
      NSDictionary *myMovieFileTypes = [plugins getMovieReaders];

      _itemURL = [url retain];

      _itemName = [[NSFileManager defaultManager] displayNameAtPath:
                                                               [_itemURL path]];
      [_itemName retain];

      // Find the reader class which declares this file type, 
      // and accepts to open this file
      NSMutableArray *readers = [NSMutableArray array];
      NSEnumerator *list;
      LynkeosReaderRegistry *item;
      NSString *ext = [[[url path] pathExtension] lowercaseString];

      [readers addObjectsFromArray:[myMovieFileTypes objectForKey:ext]];
#if !defined GNUSTEP
      [readers addObjectsFromArray:[myMovieFileTypes objectForKey:
                                                  NSHFSTypeOfFile([url path])]];
#endif
      [readers addObjectsFromArray:[myImageFileTypes objectForKey:ext]];
#if !defined GNUSTEP
      [readers addObjectsFromArray:[myImageFileTypes objectForKey:
         NSHFSTypeOfFile([url path])]];
#endif

      // Try the readers until one accepts
      list = [readers objectEnumerator];
      while( (item = [list nextObject]) != nil )
      {
         if ( (_reader = [[item->reader alloc] initWithURL:url]) != nil )
            // Found it
            break;
      }

      if ( _reader != nil )
      {
         // Cache some characteristics
         [_reader imageWidth:&_size.width height:&_size.height];
         _nPlanes = [_reader numberOfPlanes];
      }
      else
         // Bad luck
         NSLog( @"Unable to create item for %@", [url absoluteString] );
   }
}

- (id) initWithParent:(MyImageListItem*)parent withIndex:(u_long)index
{
   if ( (self = [self init]) != nil )
   {
      _parent = parent;
      _reader = [parent->_reader retain];
      _itemName = [parent->_itemName retain];
      _index = index;
      _size = parent->_size;
      _nPlanes = parent->_nPlanes;
      [self  setParametersParent:parent->_parameters];
   }

   return( self );
}

- (void) setSelectionState :(int)state 
{
   _selection_state = state;
}

- (void) childrenSelectionChanged
{
   NSEnumerator* list = [_childList objectEnumerator];
   id item;
   unsigned int selection_count;

   // Recount the selection
   selection_count = 0;
   while ( (item = [list nextObject]) != nil )
      if ( [item getSelectionState] > 0 )
         selection_count ++;

   // Update the state
   if ( selection_count == 0 )
      [self setSelectionState:NSOffState];
   else if ( selection_count == [_childList count] )
      [self setSelectionState:NSOnState];
   else
      [self setSelectionState:NSMixedState];
}

- (void) setName :(NSString*)name
{
   if ( _itemName != nil )
      [_itemName release];
   _itemName = name;
   [_itemName retain];
}

- (void) goIntoImageSpace
{
   if ( _processedSpectrum != nil )
   {
      NSAssert( _processedImage == nil,
                @"Processed spectrum and modified image are set together" );
      [_processedSpectrum inverseTransform];
      _processedImage = _processedSpectrum;
      _processedSpectrum = nil;
   }
}

- (id <LynkeosImageBuffer>) getCustomImageBufferInRect:(LynkeosIntegerRect)rect
{
   if ( [[_reader class] hasCustomImageBuffer] )
   {
      if ( _index == NON_SIGNIFICANT_INDEX )
         // Image file
         return( [_reader getCustomImageSampleAtX:rect.origin.x 
                                                Y:rect.origin.y
                                                W:rect.size.width 
                                                H:rect.size.height] );
      else
         // Movie image
         return( [_reader getCustomImageSampleAtIndex:_index 
                                                  atX:rect.origin.x 
                                                    Y:rect.origin.y
                                                    W:rect.size.width 
                                                    H:rect.size.height] );
   }
   else
      return( nil );
}

- (id <LynkeosImageBuffer>) getDarkFrame
{
   id <LynkeosImageBuffer> localDark = nil;

   if ( _dark != nil )
      return( _dark );

   // Search for a cached value in containers
   localDark = [_parent getDarkFrame];

   if ( localDark == nil )
      // Well, do it the expensive way
      localDark = (id <LynkeosImageBuffer>)[self getProcessingParameterWithRef:
                                                        myImageListItemDarkFrame
                                                             forProcessing:nil];

   return( localDark );
}

- (id <LynkeosImageBuffer>) getFlatField
{
   id <LynkeosImageBuffer>localFlat = nil;

   if ( _flat != nil )
      return( _flat );

   // Search for a cached value in containers
   localFlat = [_parent getFlatField];
   if ( localFlat == nil )
      // Well, do it the expensive way
      localFlat = (id <LynkeosImageBuffer>)[self
                          getProcessingParameterWithRef:myImageListItemFlatField
                                          forProcessing:nil];

   return( localFlat );
}
@end

@implementation MyImageListItem

+ (void) initialize
{
   // Register some of our properties as displayable in a column
   [[LynkeosColumnDescriptor defaultColumnDescriptor] registerColumn:@"select"
                                                     forProcess:myImageListItemRef
                                                      parameter:myImageListItemRef
                                                          field:@"selectionState"
                                                         format:nil];
   [[LynkeosColumnDescriptor defaultColumnDescriptor] registerColumn:@"name"
                                                     forProcess:myImageListItemRef
                                                      parameter:myImageListItemRef
                                                          field:@"name"
                                                         format:nil];
   [[LynkeosColumnDescriptor defaultColumnDescriptor] registerColumn:@"index"
                                                     forProcess:myImageListItemRef
                                                      parameter:myImageListItemRef
                                                          field:@"index"
                                                         format:nil];
}

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _reader = nil;
      _itemURL = nil;
      _itemName = nil;
      _childList = nil;

      _index = NON_SIGNIFICANT_INDEX;
      _parent = nil;
      _selection_state = 1;

      _flat = nil;
      _dark = nil;
   }

   return( self );
}

- (id) initWithURL :(NSURL*)url
{
   if ( (self = [self init]) != nil )
   {
      [self setURL:url];

      // Abort if there is no reader found
      if ( _reader == nil )
      {
         [self release];
         self = nil;
         return( self );
      }

      if ( [_reader conformsToProtocol:@protocol(LynkeosImageFileReader)] )
      {
         // Nothing more to do
      }

      else if ( [_reader conformsToProtocol:@protocol(LynkeosMovieFileReader)] )
      {
         // Create children for the movie images
         const u_long childrenNb = [_reader numberOfFrames];
         u_long i;

         _childList = [[NSMutableArray arrayWithCapacity:childrenNb] retain];
         for( i = 0; i < childrenNb; i++ )
            [_childList addObject:[[MyImageListItem alloc] initWithParent:self
                                                                withIndex:i]];
      }
      else
         NSAssert( NO, @"Invalid file reader selected" );
   }

   return( self );
}

- (void) dealloc
{
   [_reader release];
   [_itemURL release];
   [_itemName release];
   [_childList release];
   if ( _dark != nil )
      [_dark release];
   if ( _flat != nil )
      [_flat release];

   [super dealloc];
}

// Coding
- (void)encodeWithCoder:(NSCoder *)encoder
{
   if ( _itemURL != nil )
   {
      // Try to resolve item path against document path
      NSURL *itemRelativeURL;

      if ( basePath != nil )
      {
         NSArray *itemPath = [[_itemURL path] pathComponents];
         NSArray *docPath = [basePath pathComponents];
         NSMutableString *relativePath = [NSMutableString string];
         NSString *itemComp, *docComp;
         int i, j, nItems = [itemPath count], nDoc = [docPath count];

         // Scan the common part
         for ( i = 0; i < nDoc && i < nItems; i++ )
         {
            docComp = [docPath objectAtIndex:i];
            itemComp = [itemPath objectAtIndex:i];
            if ( ![itemComp isEqualToString:docComp] )
               break;
         }

         NSAssert2( i > 0, @"Doc or item URL to encode is not absolute\n%@\n%@",
                    _itemURL, basePath );

         if ( i > 1 )
         {
            // Go back from the doc to the divergence point
            for ( j = i; j < nDoc; j++ )
               [relativePath appendString:@"../"];

            // Append the item's remaining components (including file name)
            for ( ; i < nItems; i++ )
            {
               [relativePath appendString:[itemPath objectAtIndex:i]];
               if ( i < (nItems-1) )
                  [relativePath appendString:@"/"];
            }

            NSURL *baseURL = [NSURL fileURLWithPath:basePath];
            NSString *relURL =
               [relativePath stringByAddingPercentEscapesUsingEncoding:
                                                          NSUTF8StringEncoding];
            itemRelativeURL = [NSURL URLWithString:relURL
                                      relativeToURL:baseURL];
         }
         else
            // The paths diverge immediately after "/", better be absolute
            itemRelativeURL = _itemURL;
      }
      else
         itemRelativeURL = _itemURL;

      [encoder encodeObject:itemRelativeURL forKey:K_URL_KEY];
   }
   if ( _childList != nil )
      [encoder encodeObject:_childList forKey:K_IMAGES_KEY];
   else
   {
      [encoder encodeInt32:_index forKey:K_INDEX_KEY];
      [encoder encodeBool:(_selection_state == NSOnState) 
                   forKey:K_SELECTED_KEY];
   }

   [super encodeWithCoder:encoder];
}

- (id)initWithCoder:(NSCoder *)decoder	// This is also an initialization
{
   if ( (self = [super initWithCoder:decoder]) != nil )
   {
      // Try absolute and doc relative URL resolution
      NSFileManager *fManager = [NSFileManager defaultManager];
      NSURL *itemURL = [decoder decodeObjectForKey:K_URL_KEY];
      if ( itemURL != nil && basePath != nil
           && ![fManager fileExistsAtPath:[itemURL path]] )
      {
         NSURL *relURL = [NSURL URLWithString:[itemURL relativeString]
                                relativeToURL:[NSURL fileURLWithPath:basePath]];
         if ( [fManager fileExistsAtPath:[relURL path]] )
            itemURL = relURL;
      }

      [self setURL:itemURL];

      _childList = [[decoder decodeObjectForKey:K_IMAGES_KEY] retain];
      if ( [decoder containsValueForKey:K_INDEX_KEY] )
         _index = [decoder decodeInt32ForKey:K_INDEX_KEY];
      if ( _childList == nil )
         [self setSelected: [decoder decodeBoolForKey:K_SELECTED_KEY]];

      // V1 compatibility code
#ifndef NO_FILE_FORMAT_COMPATIBILITY_CODE
      if ( [decoder containsValueForKey:K_SEARCH_ORIGIN_KEY] )
      {
         MyImageAlignerParameters *align =
                          [[[MyImageAlignerParameters alloc] init] autorelease];
         align->_alignOrigin = LynkeosIntegerPointFromNSPoint(
                               [decoder decodePointForKey:K_SEARCH_ORIGIN_KEY]);
         [self setProcessingParameter:align
                              withRef:myImageAlignerParametersRef
                        forProcessing:myImageAlignerRef];
      }
      if ( [decoder containsValueForKey:K_ALIGN_OFFSET_KEY] )
      {
         LynkeosBasicAlignResult *offset =
                           [[[LynkeosBasicAlignResult alloc] init] autorelease];
         offset->_alignOffset = [decoder decodePointForKey:K_ALIGN_OFFSET_KEY];
         [self setProcessingParameter:offset
                              withRef:LynkeosAlignResultRef
                        forProcessing:LynkeosAlignRef];
      }
      double q;
      if ( [decoder containsValueForKey:K_QUALITY_KEY]
           && (q = [decoder decodeDoubleForKey:K_QUALITY_KEY]) >= 0.0 )
      {
         MyImageAnalyzerResult *quality =
                             [[[MyImageAnalyzerResult alloc] init] autorelease];
         quality->_quality = q;
         [self setProcessingParameter:quality
                              withRef:myImageAnalyzerResultRef
                        forProcessing:myImageAnalyzerRef];
      }

      // Compatibility code for version < V2.2

      // Try to get the black and white levels, only if the item is processed
      if ( [self getProcessingParameterWithRef:K_PROCESS_STACK_REF
                                 forProcessing:nil] != nil
           && [decoder containsValueForKey:K_MODBLACK_KEY]
           && [decoder containsValueForKey:K_MODWHITE_KEY] )
      {
         double vmin, vmax;
         u_short c;
         _black = (double*)malloc( sizeof(double)*(_nPlanes+1) );
         _white = (double*)malloc( sizeof(double)*(_nPlanes+1) );
         _gamma = (double*)malloc( sizeof(double)*(_nPlanes+1) );
         _black[_nPlanes] = [decoder decodeDoubleForKey:K_MODBLACK_KEY];
         _white[_nPlanes] = [decoder decodeDoubleForKey:K_MODWHITE_KEY];
         _gamma[_nPlanes] = [decoder decodeDoubleForKey:K_GAMMA_CORRECTION_KEY];
         if ( _gamma[_nPlanes] == 0.0 )
            _gamma[_nPlanes] = 1.0;

         [(LynkeosStandardImageBuffer*)[self getImage] getMinLevel:&vmin
                                                          maxLevel:&vmax];
         for( c = 0; c < _nPlanes; c++ )
         {
            _black[c] = vmin;
            _white[c] = vmax;
            _gamma[c] = 1.0;
         }
      }
      // End of compatibility code
#endif

      // Fill the missing data in the children
      if ( _childList != nil )
      {
         NSEnumerator *children = [_childList objectEnumerator];
         MyImageListItem *item;

         while ( (item = [children nextObject]) != nil )
         {
            item->_parent = self;
            [item setParametersParent:_parameters];
            // When the reader is not found, we go on, and the document will
            // alert the user and delete bad items
            if ( _reader != nil )
               item->_reader = [_reader retain];
            item->_itemName = [_itemName retain];
            item->_size = _size;
            item->_nPlanes = _nPlanes;
         }

         // Refresh the parent (myself) selection state
         [self childrenSelectionChanged];
      }
   }

   return( self );
}

// Accessors
- (NSURL*) getURL { return( _itemURL ); }

- (u_long) numberOfChildren
{
   return( _childList == nil ? 0 : [_childList count] );
}

- (int) getSelectionState { return( _selection_state ); }
- (NSNumber*) selectionState
{
   return( [NSNumber numberWithInt:_selection_state] );
}

- (NSString*)name { return( _itemName ); }

- (NSNumber*) index
{
   if ( _index == NON_SIGNIFICANT_INDEX )
      return( nil );
   else
      return( [NSNumber numberWithInt:_index] );
}

- (MyImageListItem*) getParent { return( _parent ); }

- (id <LynkeosFileReader>) getReader { return(_reader ); }

- (MyImageListItem*) getChildAtIndex:(u_long)index
{
   NSAssert( _childList != nil, @"getChildAtIndex called on a leaf item" );
   return( [_childList objectAtIndex:index] );
}

- (unsigned) indexOfItem:(MyImageListItem*)item
{
   NSAssert( _childList != nil, @"indexOfItem called on a leaf item" );
   return( [_childList indexOfObject:item] );
}

- (void) addChild:(MyImageListItem*)item
{
   NSEnumerator *iter = [_childList objectEnumerator];
   MyImageListItem *child;
   u_long itemIndex = item->_index;
   int arrayIndex = 0;

   // Look for the first image whose index is after this one
   while ( (child = [iter nextObject]) != nil && child->_index < itemIndex )
      arrayIndex++;

   // There shall not be two images for the same movie frame
   NSAssert( child->_index != itemIndex, 
            @"Add a preexisting frame in MyImageListItem" );

   // And insert this one before it
   [_childList insertObject:item atIndex:arrayIndex];

   // Connect the parameters chain
   [item setParametersParent:_parameters];

   [self childrenSelectionChanged];
}

- (void) deleteChild:(MyImageListItem*)item
{
   NSAssert( [_childList containsObject:item], 
            @"Cannot delete a nonexistent child!" );
   [_childList removeObject:item];
   [self childrenSelectionChanged];
}

- (void) setSelected :(BOOL)value
{
   _selection_state = value ? NSOnState : NSOffState;

   if ( _childList != nil )
   {
      NSEnumerator* list = [_childList objectEnumerator];
      id item;

      // Propagate that state on all the images
      while ( (item = [list nextObject]) != nil )
         [item setSelected:value];
   }
   else
   {
      MyImageListItem *parent = [self getParent];

      if ( parent != nil )
         [parent childrenSelectionChanged];
   }

   // Notify for some change
   [_parameters notifyItemModification:self];
}

- (void) setParametersParent :(LynkeosProcessingParameterMgr*)parent;
{
   if ( _parameters->_parent != nil )
      [_parameters->_parent release];
   _parameters->_parent = [parent retain];
}

#pragma mark = LynkeosProcessableItem protocol
- (u_short) numberOfPlanes
{
   return( _nPlanes );
}

- (LynkeosIntegerSize) imageSize
{
   return( _size );
}

- (id <LynkeosImageBuffer>) getImage
{
   id <LynkeosImageBuffer> image = [super getImage];

   if ( image == nil )
   {
      LynkeosIntegerRect r = { {0.0,0.0}, _size };
      [self getImageSample:&image inRect:r];
   }

   return( image );
}

- (NSImage*) getNSImage
{
   NSImage *image = nil;

   if ( _processedImage != nil || _processedSpectrum != nil )
      image = [super getNSImage];

   else if ( _childList != nil )
      // No image at movie level
      ;
   else if ( _index == NON_SIGNIFICANT_INDEX )
      // Image file
      image = [_reader getNSImage];
   else
      // Movie image
      image = [_reader getNSImageAtIndex:_index];

   return( image );
}

- (void) getImageSample:(LynkeosStandardImageBuffer**)buffer 
                 inRect:(LynkeosIntegerRect)rect
{
   id <LynkeosImageBuffer> data = nil;
   LynkeosIntegerRect wRect;
   void * const * planes;
   u_short x, y, c;
   id <LynkeosImageBuffer> flat = [self getFlatField];
   id <LynkeosImageBuffer> dark = [self getDarkFrame];

   // No image sample should be retrieved at movie level
   NSAssert( _childList == nil, @"getImageSample called at movie level" );

   // Create an image buffer if needed
   if ( *buffer == nil )
      *buffer = [LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:
                                                        [_reader numberOfPlanes]
                                                       width:rect.size.width
                                                      height:rect.size.height];

   NSAssert( (*buffer)->_w == rect.size.width
             && (*buffer)->_h == rect.size.height,
             @"Sample size inconsistency" );

   // Intersect the rectangle with the image
   wRect = IntersectIntegerRect( rect, LynkeosMakeIntegerRect(0,0,
                                                   _size.width,_size.height) );

   // Fill with black outside the image
   if ( wRect.size.width != rect.size.width
        || wRect.size.height < rect.size.height )
   {
      for( c = 0; c < (*buffer)->_nPlanes; c++ )
      {
         // Upper margin
         for( y = 0;
              y < wRect.origin.y-rect.origin.y && y < (*buffer)->_h;
              y++ )
            for( x = 0; x < (*buffer)->_w; x++ )
               colorValue(*buffer,x,y,c) = 0.0;
         if ( wRect.size.width != rect.size.width )
         {
            for( ; y < wRect.origin.y+wRect.size.height-rect.origin.y
                   && y < (*buffer)->_h; y++ )
            {
               // Left margin
               for( x = 0;
                    x < wRect.origin.x-rect.origin.x && x < (*buffer)->_w;
                    x++ )
                  colorValue(*buffer,x,y,c) = 0.0;
               // Right margin
               for( x = wRect.origin.x+wRect.size.width-rect.origin.x;
                    x < (*buffer)->_w; 
                    x++ )
                  colorValue(*buffer,x,y,c) = 0.0;
            }
         }
         // Bottom margin
         for( ; y < (*buffer)->_h; y++ )
            for( x = 0; x < (*buffer)->_w; x++ )
               colorValue(*buffer,x,y,c) = 0.0;
      }
   }

   // If, for some reason, the rectangle is outside the image, it's over now
   if ( wRect.size.width == 0 || wRect.size.height == 0 )
      return;

   // Fake the planes origin for the reader or the conversion to fill the
   // intersection (the fake image is said to have rect.size.height to keep the
   // planes aligned, but we fill only wRect.size.height)
   LynkeosStandardImageBuffer *transBuf = [LynkeosStandardImageBuffer imageBufferWithData:
                                       &colorValue(*buffer,
                                                   wRect.origin.x-rect.origin.x,
                                                   wRect.origin.y-rect.origin.y,
                                                   0)
                                       copy:NO freeWhenDone:NO
                                       numberOfPlanes:(*buffer)->_nPlanes
                                       width:wRect.size.width
                                       paddedWidth:(*buffer)->_padw
                                       height:(*buffer)->_h];
   planes = [transBuf colorPlanes];

   // First, get data from the stored image if any
   [self goIntoImageSpace];      // Perform inverse transform now if needed
   if ( _processedImage != nil )
   {
      // No calibration on processed image !
      flat = nil;
      dark = nil;

      data = transBuf;
      [_processedImage extractSample:planes
                                atX:wRect.origin.x Y:wRect.origin.y
                          withWidth:wRect.size.width height:wRect.size.height
                         withPlanes:transBuf->_nPlanes
                          lineWidth:transBuf->_padw];
   }

   // Then try to get the data from a custom image if we can calibrate in it
   else if ( dark != nil || flat != nil )
      data = [self getCustomImageBufferInRect:wRect];

   // And read as a last (but common ;o) resort
   if ( data == nil )
   {
      void * const *readPlanes;
      short readPlanesNb = [_reader numberOfPlanes];

      if ( ( (dark == nil && flat == nil) ||
             (wRect.size.width == rect.size.width 
              && wRect.size.height == rect.size.height) )
           && readPlanesNb == transBuf->_nPlanes )
      {
         // Optimisation : as the planearity is the same as the reader (and 
         // calibration frames), we can read directly in the buffer and spare
         // the conversion.
         // But to calibrate, we also need the sample to be fully inside the
         // image.
         data = transBuf;
         readPlanes = planes;
      }

      else
      {
         // We need a temporary buffer to read in
         data = [LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:readPlanesNb 
                                                       width:wRect.size.width 
                                                      height:wRect.size.height];
         readPlanes = [(LynkeosStandardImageBuffer*)data colorPlanes];
      }

      if ( _index == NON_SIGNIFICANT_INDEX )
         // Image file
         [_reader getImageSample:(void*const*const)readPlanes 
                   withPrecision:PROCESSING_PRECISION
                      withPlanes:((LynkeosStandardImageBuffer*)data)->_nPlanes
                             atX:wRect.origin.x Y:wRect.origin.y
                               W:wRect.size.width H:wRect.size.height
                       lineWidth:((LynkeosStandardImageBuffer*)data)->_padw];
      else
         // Movie image
         [_reader getImageSample:(void*const*const)readPlanes 
                         atIndex:_index
                   withPrecision:PROCESSING_PRECISION
                      withPlanes:((LynkeosStandardImageBuffer*)data)->_nPlanes
                             atX:wRect.origin.x Y:wRect.origin.y
                               W:wRect.size.width H:wRect.size.height
                       lineWidth:((LynkeosStandardImageBuffer*)data)->_padw];
   }

   NSAssert( data != nil, @"Failed to read a sample" );

   if ( dark != nil || flat != nil )
      [data calibrateWithDarkFrame:dark flatField:flat 
                               atX:wRect.origin.x Y:wRect.origin.y];

   if ( data != transBuf )
        [data convertToPlanar:(void*const*const)planes
                withPrecision:PROCESSING_PRECISION
                   withPlanes:transBuf->_nPlanes
                    lineWidth:transBuf->_padw];
}

- (void) setImage:(LynkeosStandardImageBuffer*)buffer
{
   [super setImage:buffer];

   if ( _processedImage == nil )
   {
      [_reader imageWidth:&_size.width height:&_size.height];
      _nPlanes = [_reader numberOfPlanes];
   }
}

- (void) setOriginalImage:(LynkeosStandardImageBuffer*)buffer
{
   NSLog( @"Impossible to set the original image on MyImageListItem" );
}

- (void) revertToOriginal
{
   // Easy ! The original image always comes from the reader
   [self setImage:nil];
}

- (BOOL) isProcessed
{
   return( ![self isOriginal] );
}

- (BOOL) getBlackLevel:(double*)black whiteLevel:(double*)white
                 gamma:(double*)gamma
{
   if ( _processedImage != nil || _processedSpectrum != nil )
      return( [super getBlackLevel:black whiteLevel:white gamma:gamma] );

   else
   {
      [_reader getMinLevel:black maxLevel:white];
      *gamma = 1.0;
   }

   return( YES );
}

- (BOOL) getBlackLevel:(double*)black whiteLevel:(double*)white
                 gamma:(double*)gamma  forPlane:(u_short)plane
{
   if ( _processedImage != nil || _processedSpectrum != nil )
      return( [super getBlackLevel:black whiteLevel:white gamma:gamma
                          forPlane:plane] );

   else
   {
      [_reader getMinLevel:black maxLevel:white];
      *gamma = 1.0;
   }

   return( YES );
}

- (void) setBlackLevel:(double)black whiteLevel:(double)white
                  gamma:(double)gamma
{
   // Forget the reader and start a processed image
   if ( _processedImage == nil && _processedSpectrum == nil )
      [self setImage:[self getImage]];
   [super setBlackLevel:black whiteLevel:white gamma:gamma];
}

- (void) setBlackLevel:(double)black whiteLevel:(double)white
                 gamma:(double)gamma forPlane:(u_short)plane
{
   // Forget the reader and start a processed image
   [self setImage:[self getImage]];
   [super setBlackLevel:black whiteLevel:white gamma:gamma forPlane:plane];
}

- (BOOL) getMinLevel:(double*)vmin maxLevel:(double*)vmax
{
   if ( _processedImage != nil || _processedSpectrum != nil )
      return( [super getMinLevel:vmin maxLevel:vmax] );

   else
      [_reader getMinLevel:vmin maxLevel:vmax];

   return( YES );
}

- (BOOL) getMinLevel:(double*)vmin maxLevel:(double*)vmax
            forPlane:(u_short)plane
{
   if ( _processedImage != nil || _processedSpectrum != nil )
      return( [super getMinLevel:vmin maxLevel:vmax forPlane:plane] );

   else
      [_reader getMinLevel:vmin maxLevel:vmax];

   return( YES );
}

- (id <LynkeosProcessingParameter>) getProcessingParameterWithRef:(NSString*)ref 
                                             forProcessing:(NSString*)processing
{
   return( [self getProcessingParameterWithRef:ref forProcessing:processing
                                          goUp:YES] );
}

- (id <LynkeosProcessingParameter>) getProcessingParameterWithRef:(NSString*)ref 
                                             forProcessing:(NSString*)processing
                                                             goUp:(BOOL)goUp
{
   // Present ourselves as a parameter for displaying some fields in the GUI
   if ( [processing isEqual:myImageListItemRef] )
      return( self );
   else
      return( [_parameters getProcessingParameterWithRef:ref
                                           forProcessing:processing goUp:goUp] );
}

- (void) setProcessingParameter:(id <LynkeosProcessingParameter>)parameter
                        withRef:(NSString*)ref 
                  forProcessing:(NSString*)processing
{
   [_parameters setProcessingParameter:parameter withRef:ref 
                         forProcessing:processing];

   // Handle the shortcut for calibration frames
   if ( processing == nil )
   {
      if ( [ref isEqual:myImageListItemDarkFrame] )
      {
         if ( _dark != nil )
            [_dark release];
         _dark = [parameter retain];
      }
      else if ( [ref isEqual:myImageListItemFlatField] )
      {
         if ( _flat != nil )
            [_flat release];
         _flat = [parameter retain];
      }
   }


   // Notify of the change
   [_parameters notifyItemModification:self];
}

+ (id) imageListItemWithURL :(NSURL*)url
{
   return( [[[self alloc] initWithURL:url] autorelease] );
}

+ (NSArray*) imageListItemFileTypes
{
   MyPluginsController *plugins = [MyPluginsController defaultPluginController];
   return( [[[plugins getImageReaders] allKeys] arrayByAddingObjectsFromArray:
                                          [[plugins getMovieReaders] allKeys]]);
}

@end

/*!
 * @abstract Compatibility class for reading documents created by
 *   Lynkeos V1.2 or earlier
 * @discussion The unarchiver needs it to be declared, but we create a
 *    MyImageListItem instead, to avois re-saving it later.
 */
@interface MyImage : MyImageListItem
@end

@implementation MyImage
- (id) init
{
   [self release];
   self = [[MyImageListItem alloc] init];
   return( self );
}
@end

/*!
 * @abstract Compatibility class for reading documents created by
 *   Lynkeos V1.2 or earlier.
 * @discussion The unarchiver needs it to be declared, but we create a
 *    MyImageListItem instead, to avois re-saving it later.
 */
@interface MyMovie : MyImageListItem
@end

@implementation MyMovie
- (id) init
{
   [self release];
   self = [[MyImageListItem alloc] init];
   return( self );
}
@end

/*!
 * @abstract Compatibility class for reading documents created by
 *   Lynkeos V1.2 or earlier
 * @discussion The unarchiver needs it to be declared, but we create a
 *    MyImageListItem instead, to avois re-saving it later.
 */
@interface MyMovieImage : MyImageListItem
@end

@implementation MyMovieImage
- (id) init
{
   [self release];
   self = [[MyImageListItem alloc] init];
   return( self );
}
@end

