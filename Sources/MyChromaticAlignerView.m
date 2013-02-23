//
//  Lynkeos
//  $Id: MyChromaticAlignerView.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun Mar 30 2008.
//  Copyright (c) 2008. Jean-Etienne LAMIAUD
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
#include <stdlib.h>
#include <string.h>

#include "MyImageList.h"
#include "MyImageAligner.h"
#include "MyImageAlignerPrefs.h"
#include "MyImageStacker.h"

#include "MyChromaticAlignerView.h"

NSString * const myChromaticAlignerRef = @"MyChromaticAlignerView";
NSString * const myChromaticAlignerOffsetsRef = @"ChromaticDispersionOffsets";

NSString * const K_CHROMA_NUM_OFFSETS_KEY = @"number";
NSString * const K_CHROMA_OFFSETS_KEY = @"offsets";

static NSString *commonPlanesNames[3];

@implementation MyChromaticAlignParameter
- (id) initWithOffsetNumber:(u_short)size
{
   if ( (self = [self init]) != nil )
   {
      _numOffsets = size;
      _offsets = (NSPointArray)malloc( size*sizeof(NSPoint) );
   }

   return( self );
}

- (void) dealloc
{
   free( _offsets );

   [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [encoder encodeInt:_numOffsets forKey:K_CHROMA_NUM_OFFSETS_KEY];
   NSMutableData *buf =
          [NSMutableData dataWithLength:_numOffsets*2*sizeof(NSSwappedFloat)];
   u_short i;
   NSSwappedFloat *codedOffsets = [buf mutableBytes];
   for( i = 0; i < _numOffsets; i++ )
   {
      codedOffsets[2*i] = NSConvertHostFloatToSwapped(_offsets[i].x);
      codedOffsets[2*i+1] = NSConvertHostFloatToSwapped(_offsets[i].y);
   }
   [encoder encodeObject:buf forKey: K_CHROMA_OFFSETS_KEY];
}

- (id)initWithCoder:(NSCoder *)decoder
{
   self= [self initWithOffsetNumber:
                            [decoder decodeIntForKey:K_CHROMA_NUM_OFFSETS_KEY]];

   if ( self != nil )
   {
      if ( _numOffsets > 1 )
      {
         NSData *buf = [decoder decodeObjectForKey:K_CHROMA_OFFSETS_KEY];
         u_short i;
         const NSSwappedFloat *codedOffsets = [buf bytes];
         for( i = 0; i < _numOffsets; i++ )
         {
            _offsets[i].x = NSConvertSwappedFloatToHost(codedOffsets[2*i]);
            _offsets[i].y = NSConvertSwappedFloatToHost(codedOffsets[2*i+1]);
         }
      }
      else
      {
         [self release];
         self = nil;
      }
   }

   return( self );
}
@end

@interface MyChromaticAlignerView(Private)
- (void) setMatrix:(NSMatrix*)matrix rows:(int)rows ;
- (void) updateMatrices ;
- (void) updateSlider:(NSSlider*)slider minMaxWithValue:(double)v ;
- (void) itemChange:(NSNotification*)notif ;
- (void) processStarted:(NSNotification*)notif ;
- (void) processEnded:(NSNotification*)notif ;
- (void) displayNewOffsets ;
- (LynkeosStandardImageBuffer*) applyOffsetsTo:(LynkeosStandardImageBuffer*)image ;
@end

@implementation MyChromaticAlignerView(Private)
- (void) setMatrix:(NSMatrix*)matrix rows:(int)rows
{
   while ( [matrix numberOfRows] > rows )
      [matrix removeRow:0];
   while ( [matrix numberOfRows] < rows )
      [matrix addRow];

   [matrix sizeToCells];
}

- (void) updateSlider:(NSSlider*)slider minMaxWithValue:(double)v
{
   double newMin = 0.0, newMax = 0.0;

   if ( v > [slider maxValue] )
   {
      newMax = v;
      newMin = -v;
   }
   else if ( v < [slider minValue] )
   {
      newMin = v;
      newMax = -v;
   }
   if ( newMin != 0.0 && newMax != 0.0 )
   {
      int i, n = [_offsetSliders numberOfRows];
      for( i = 0; i < n; i++ )
      {
         [[_offsetSliders cellAtRow:i column:0] setMinValue:newMin];
         [[_offsetSliders cellAtRow:i column:0] setMaxValue:newMax];
      }
   }   
}

- (void) updateMatrices
{
   NSSlider *slider;
   NSTextField *text;
   NSSize formerSize, newSize, containerSize;
   u_short i;
   float x, y;
   int num = 2;

   if ( _params != nil )
      num = _params->_numOffsets*2;

   formerSize = [_offsetNames frame].size;

   // Set the new number of rows
   [self setMatrix:_offsetNames rows:num];
   [self setMatrix:_offsetTextFields rows:num];
   [self setMatrix:_offsetSliders rows:num];

   // Update the display
   if ( num > 2 )
   {
      for( i = 0; i < num/2; i++ )
      {
         // Set the plane's name
         NSString *name = nil;
         if ( i < 3 )
            name = commonPlanesNames[i];
         else
            name = [NSString stringWithFormat:@"Plane%d",i];

         [[_offsetNames cellAtRow:i*2 column:0] setStringValue:
                                          [name stringByAppendingString:@" x"]];
         [[_offsetNames cellAtRow:i*2+1 column:0] setStringValue:@" y"];

         // And set the controls values to the offsets
         x = _params->_offsets[i].x*(float)_stackingFactor;
         text = [_offsetTextFields cellAtRow:i*2 column:0];
         [text setFloatValue:x];
         slider = [_offsetSliders cellAtRow:i*2 column:0];
         [self updateSlider:slider minMaxWithValue:x];
         [slider setFloatValue:x];
         y = _params->_offsets[i].y*(float)_stackingFactor;
         text = [_offsetTextFields cellAtRow:i*2+1 column:0];
         [text setFloatValue:y];
         slider = [_offsetSliders cellAtRow:i*2+1 column:0];
         [self updateSlider:slider minMaxWithValue:y];
         [slider setFloatValue:y];
      }
      [_offsetTextFields setEnabled:YES];
      [_offsetSliders setEnabled:YES];
   }
   else
   {
      [[_offsetNames cellAtRow:0 column:0] setStringValue:@"x"];
      [[_offsetNames cellAtRow:1 column:0] setStringValue:@"y"];

      for( i = 0; i < 2; i++ )
      {
         text = [_offsetTextFields cellAtRow:i column:0];
         [text setStringValue:@""];
         slider = [_offsetSliders cellAtRow:i column:0];
         [slider setFloatValue:0.0];
      }
      [_offsetTextFields setEnabled:NO];
      [_offsetSliders setEnabled:NO];
   }

   // Adjust view size
   newSize = [_offsetNames frame].size;
   containerSize = [_panel frame].size;
   containerSize.height += newSize.height - formerSize.height;
   [_panel setFrameSize:containerSize];
   [_panel setNeedsDisplay:YES];
}

- (void) enableButtons
{
   BOOL isColored = (_item != nil && [_item numberOfPlanes] > 1);

   [_automaticOffsetsButton setEnabled:isColored];
   // Disable "re-stack" if the item is not a list
   [_reStackButton setEnabled:(isColored
                               &&[_item isKindOfClass:[MyImageList class]])];
   [_originalCheckBox setEnabled:isColored];
}

- (void) itemChange:(NSNotification*)notif
{
   // Release all data related to the previous item
   if ( _item != nil )
      [_item release];
   _item = nil;
   if ( _params != nil )
      [_params release];
   _params = nil;   
   if ( _originalImage != nil )
      [_originalImage release];
   _originalImage = nil;
   if ( _processedImage != nil )
      [_processedImage release];
   _processedImage = nil;
   if ( _originalOffsets != NULL )
      free(_originalOffsets);
   _originalOffsets = NULL;

   // Get the new item
   LynkeosImageProcessingParameter *fakeParam;
   [_window getItemToProcess:&_item andParameter:&fakeParam forView:self];
   if ( _item != nil )
      [_item retain];

   if ( _item != nil && [_item numberOfPlanes] > 1 )
   {
      u_short i;

      // Extract the parameter
      _params= [_item getProcessingParameterWithRef:myChromaticAlignerOffsetsRef
                                      forProcessing:myChromaticAlignerRef];

      // And create one if none yet
      if ( _params == nil )
      {
         u_short nPlanes = [_item numberOfPlanes];
         _params =
               [[MyChromaticAlignParameter alloc] initWithOffsetNumber:nPlanes];
         for( i = 0; i < nPlanes; i++ )
         {
            _params->_offsets[i].x = 0.0;
            _params->_offsets[i].y = 0.0;
         }
      }
      else
         [_params retain];

      // Save the offsets as "original" values
      NSAssert( _params != nil, @"No chromatic offset");
      NSAssert2( _params->_numOffsets == [_item numberOfPlanes],
              @"Number of chromatic offsets (%d) and planes (%d) are not equal",
               _params->_numOffsets, [_item numberOfPlanes] );
      _originalOffsets =
                   (NSPointArray)malloc( _params->_numOffsets*sizeof(NSPoint) );
      memcpy( _originalOffsets, _params->_offsets,
              _params->_numOffsets*sizeof(NSPoint) );

      // Get the original image and processed too, if any
      if ( ![_item isOriginal] )
         _processedImage = [_item getImage];
      _originalImage = [_item getOriginalImage];
      if ( _originalImage != nil )
         [_originalImage retain];
      if ( _processedImage != nil )
         [_processedImage  retain];

      // Retrieve the scaling factor used for this stack
      MyImageStackerParameters *stackParams =
                [_item getProcessingParameterWithRef:myImageStackerParametersRef
                                       forProcessing:myImageStackerRef];
      if ( stackParams != nil )
         _stackingFactor = stackParams->_factor;
      else
         _stackingFactor = 1;

      // And fill the offsets value
      [self updateMatrices];
      [self enableButtons];
   }
   else
   {
      // Disable everything for monochrome images
      [self updateMatrices];
      [self enableButtons];
   }

   [_originalCheckBox setState:NSOffState];

   // Display the item
   [_imageView displayItem:_item];
}

- (void) processStarted:(NSNotification*)notif
{
   // Disable every control
   [_offsetTextFields  setEnabled:NO];
   [_offsetSliders setEnabled:NO];
   [_automaticOffsetsButton setEnabled:NO];
   [_reStackButton setEnabled:NO];
   [_originalCheckBox setEnabled:NO];
}

- (void) processEnded:(NSNotification*)notif
{
   if( [[notif userInfo] objectForKey:LynkeosUserInfoProcess]
                                                     == [MyImageStacker class] )
   {
      // Stop waiting for process notifications
      [[NSNotificationCenter defaultCenter] removeObserver:self];
      // Get rid of the stacker
      [_stacker setActiveView:NO];
      [_stacker release];

      // And recover control (it will start again waiting for notifs)
      [self setActiveView:YES];
   }
   else
   {
      // Redisplay the image view
      [_imageView displayItem:_item];
      // And authorize the controls
      [self updateMatrices];
      [self enableButtons];
   }
}

- (void) displayNewOffsets
{
   // Apply the offset to the images
   LynkeosStandardImageBuffer *image;
   if ( _originalImage != nil )
   {
      image = [self applyOffsetsTo:_originalImage];
      [_item setOriginalImage:image];
   }
   if ( _processedImage != nil )
   {
      image = [self applyOffsetsTo:_processedImage];
      [_item setImage:image];
   }

   // And display the result
   if ( [_originalCheckBox state] == NSOffState )
      [_imageView displayItem:_item];
}

- (LynkeosStandardImageBuffer*) applyOffsetsTo:(LynkeosStandardImageBuffer*)image
{
   // Calculate the offset to apply
   NSPoint offsets[_params->_numOffsets];
   u_short i;

   for( i = 0; i < _params->_numOffsets; i++ )
   {
      offsets[i].x = (_params->_offsets[i].x
                      - _originalOffsets[i].x)*(float)_stackingFactor;
      offsets[i].y = (-_params->_offsets[i].y
                      + _originalOffsets[i].y)*(float)_stackingFactor;
   }

   // Create an empty image
   LynkeosStandardImageBuffer *result =
               [LynkeosStandardImageBuffer imageBufferWithNumberOfPlanes:_params->_numOffsets
                                                      width:[image width]
                                                     height:[image height]];

   // And add the source in it with the offsets
   [result add:image withOffsets:offsets withExpansion:1.0];

   return( result );
}
@end

@implementation MyChromaticAlignerView

+ (void) initialize
{
   commonPlanesNames[0] = NSLocalizedString(@"RedPlane", @"Red plane name");
   commonPlanesNames[1] = NSLocalizedString(@"GreenPlane", @"Green plane name");
   commonPlanesNames[2] = NSLocalizedString(@"BluePlane", @"Blue plane name");
}

+ (BOOL) isStandardProcessingViewController { return( YES ); }

+ (ProcessingViewKind_t) processingViewKindForConfig:(id <NSObject>)config
{ return( OtherProcessingKind ); }

+ (BOOL) isViewControllingProcess:(Class)processingClass
                       withConfig:(id <NSObject>*)config
{
   *config = nil;
   return( NO );
}

+ (void) getProcessingTitle:(NSString**)title
                  toolTitle:(NSString**)toolTitle
                        key:(NSString**)key
                       icon:(NSImage**)icon
                        tip:(NSString**)tip
                  forConfig:(id <NSObject>)config
{
   *title = NSLocalizedString(@"ChromaAlignMenu",
                              @"Chromatic align menu title");
   *toolTitle = NSLocalizedString(@"ChromaAlignTool",
                                 @"Chromatic align tool title");
   *key = @"c";
   *icon = [NSImage imageNamed:@"ChromaticAlign"];
   *tip = NSLocalizedString(@"ChromaAlignTip",@"Chromatic align tooltip");
}

+ (unsigned int) allowedDisplaysForConfig:(id <NSObject>)config
{
   return( BottomTab|BottomTab_NoList|SeparateView|SeparateView_NoList );
}

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _document = nil;
      _window = nil;
      _imageView = nil;

      _item = nil;
      _params = nil;
      _originalImage = nil;
      _processedImage = nil;
      _originalOffsets = NULL;
      _stackingFactor = 0;
      _stacker = nil;

      [NSBundle loadNibNamed:@"MyChromaticAlign" owner:self];
   }

   return( self );
}

- (id) initWithWindowController: (id <LynkeosWindowController>)window
                       document: (id <LynkeosViewDocument>)document
                  configuration: (id <NSObject>)config
{
   NSAssert( config == nil, @"Chromatic align does not support configuration" );

   if ( (self = [self init]) != nil )
   {
      _document = document;
      _window = window;
      _imageView = [_window getImageView];
      _textView = [_window getTextView];
   }

   return( self );
}

- (void) dealloc
{
   if ( _item != nil )
      [_item release];
   if ( _params != nil )
      [_params release];
   if ( _originalImage != nil )
      [_originalImage release];
   if ( _processedImage != nil )
      [_processedImage release];
   if ( _originalOffsets != NULL )
      free(_originalOffsets);

   [super dealloc];
}

- (NSView*) getProcessingView { return( _panel ); }

- (LynkeosProcessingViewFrame_t) preferredDisplay { return( BottomTab ); }

- (Class) processingClass { return( nil ); }

- (void) setActiveView:(BOOL)active
{
   NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];

   if ( active )
   {
      // Authorize some selections
      [_window setListSelectionAuthorization:NO];
      [_window setDataModeSelectionAuthorization:YES];
      [_window setItemSelectionAuthorization:YES];
      [_window setItemEditionAuthorization:NO];
      [_imageView setSelection:LynkeosMakeIntegerRect(0,0,0,0)
                     resizable:NO movable:NO];

      // Register for notifications
      [notifCenter addObserver:self selector:@selector(itemChange:)
                          name: NSOutlineViewSelectionDidChangeNotification
                        object:_textView];
      [notifCenter addObserver:self selector:@selector(processStarted:)
                          name: LynkeosProcessStartedNotification
                        object:_document];
      [notifCenter addObserver:self selector:@selector(processEnded:)
                          name: LynkeosProcessEndedNotification
                        object:_document];

      // Synchronize the display
      [self itemChange:nil];
   }
   else
   {
      // Release the item data
      if ( _item != nil )
         [_item release];
      _item = nil;
      if ( _params != nil )
         [_params release];
      _params = nil;

      // And any images
      if ( _originalImage != nil )
         [_originalImage release];
      _originalImage = nil;
      if ( _processedImage != nil )
         [_processedImage release];
      _processedImage = nil;
      if ( _originalOffsets != NULL )
         free(_originalOffsets);
      _originalOffsets = NULL;

      // Stop receiving notifications
      [notifCenter removeObserver:self];
   }
}

- (id <LynkeosProcessingParameter>) getCurrentParameters { return( _params ); }

- (IBAction) changeOffset:(id)sender
{
   NSCell *cell = [sender selectedCell];
   double v = [cell doubleValue];
   int row, col;

   [sender getRow:&row column:&col ofCell:cell];

   // reconcile slider and text
   if ( sender == _offsetTextFields )
   {
      NSSlider *slider = [_offsetSliders cellAtRow:row column:0];
      [self updateSlider:slider minMaxWithValue:v];
      [slider setDoubleValue:v];
   }
   else
      [[_offsetTextFields cellAtRow:row column:0] setDoubleValue:v];

   // Get the offsets
   u_short i;
   for( i = 0; i < _params->_numOffsets; i++ )
   {
      _params->_offsets[i].x =
                         [[_offsetTextFields cellAtRow:2*i column:0] floatValue]
                         / (float)_stackingFactor;
      _params->_offsets[i].y =
                       [[_offsetTextFields cellAtRow:2*i+1 column:0] floatValue]
                       / (float)_stackingFactor;
   }

   // And save them in the item
   [_item setProcessingParameter:_params
                         withRef:myChromaticAlignerOffsetsRef
                   forProcessing:myChromaticAlignerRef];

   // Apply the offset to the images
   [self displayNewOffsets];
}

- (IBAction) showOriginal:(id)sender
{
   if ( [sender state] == NSOnState )
   {
      // Create a fake item from the processed image
      LynkeosProcessableImage *item= [[[LynkeosProcessableImage alloc] init] autorelease];      
      [item setOriginalImage:(_processedImage != nil ?
                                             _processedImage : _originalImage)];
      double b, w, g;
      [_item getBlackLevel:&b whiteLevel:&w gamma:&g];
      [item setBlackLevel:b whiteLevel:w gamma:g];

      [_imageView displayItem:item];
   }
   else
      [_imageView displayItem:_item];
}

- (IBAction) automaticOffsets:(id)sender
{
   LynkeosProcessableImage *refImage, *offsetImage;
   LynkeosIntegerSize s = [_item imageSize];
   u_short w = s.width, h = s.height;

   // Assumption is made that the result needs to be displayed
   [_originalCheckBox setState:NSOffState];

   // Create a monochrome image from the second plane (should be green)
   refImage = [[[LynkeosProcessableImage  alloc] init] autorelease];
   [refImage setImage:[LynkeosStandardImageBuffer imageBufferWithData:
                                                 [_originalImage colorPlanes][1]
                                                    copy:NO
                                            freeWhenDone:NO
                                          numberOfPlanes:1
                                                   width:w paddedWidth:w
                                                  height:h]];

   // Create an aligner with this image as a reference
   MyImageAlignerListParameters *alignParam =
                      [[[MyImageAlignerListParameters alloc] init] autorelease];
   NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
   alignParam->_alignOrigin = LynkeosMakeIntegerPoint(0,0);
   alignParam->_alignSize = LynkeosMakeIntegerSize(w, h);
   alignParam->_referenceItem = refImage;
   alignParam->_cutoff = [defaults floatForKey:K_PREF_ALIGN_FREQUENCY_CUTOFF];
   alignParam->_precisionThreshold = [defaults floatForKey:
                                      K_PREF_ALIGN_PRECISION_THRESHOLD];
   alignParam->_checkAlignResult = NO;
   alignParam->_refSpectrumLock = [[NSLock alloc] init];
   alignParam->_referenceSpectrum = nil;
   [refImage setProcessingParameter:alignParam
                               withRef:myImageAlignerParametersRef
                         forProcessing:myImageAlignerRef];

   MyImageAligner *aligner = [[[MyImageAligner alloc] initWithDocument:nil
                                                           parameters:alignParam
                                   precision:PROCESSING_PRECISION] autorelease];

   // Perform alignment for all other planes
   u_short p;
   for( p = 0; p < _params->_numOffsets; p++ )
   {
      if ( p != 1 )
      {
         offsetImage = [[[LynkeosProcessableImage  alloc] init] autorelease];
         [offsetImage setImage:[LynkeosStandardImageBuffer imageBufferWithData:
                                [_originalImage colorPlanes][p]
                                                             copy:NO
                                                     freeWhenDone:NO
                                                   numberOfPlanes:1
                                                           width:w paddedWidth:w
                                                           height:h]];
         [offsetImage setProcessingParameter:alignParam
                                     withRef:myImageAlignerParametersRef
                               forProcessing:myImageAlignerRef];

         [aligner processItem:offsetImage];

         id <LynkeosAlignResult> res =
            (id <LynkeosAlignResult>)[offsetImage getProcessingParameterWithRef:
                                                           LynkeosAlignResultRef
                                                 forProcessing:LynkeosAlignRef];
         if ( res != nil )
         {
            NSPoint alignOffset = [res offset];
            _params->_offsets[p].x = alignOffset.x/(float)_stackingFactor;
            _params->_offsets[p].y = alignOffset.y/(float)_stackingFactor;
         }
         else
         {
            _params->_offsets[p].x = 0.0;
            _params->_offsets[p].y = 0.0;
         }
      }
      else
      {
         _params->_offsets[p].x = 0.0;
         _params->_offsets[p].y = 0.0;
      }
      _params->_offsets[p].x += _originalOffsets[p].x;
      _params->_offsets[p].y += _originalOffsets[p].y;
   }

   // Refresh the display
   [self updateMatrices];

   // Save the offsets in the item
   [_item setProcessingParameter:_params
                         withRef:myChromaticAlignerOffsetsRef
                   forProcessing:myChromaticAlignerRef];

   // And display the result
   [self displayNewOffsets];
}

- (IBAction) reStack:(id)sender
{
   // Resign control
   [self setActiveView:NO];

   // Switch to list mode
   [(MyDocument*)_document setDataMode:ListData];

   // Create and activate an image stacker view
   _stacker = [[MyImageStackerView alloc] initWithWindowController:_window
                                                          document:_document
                                                     configuration:nil];
   [_stacker setActiveView:YES];

   // Re-register for process start and end
   NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
   [center addObserver:self selector:@selector(processStarted:)
                  name: LynkeosProcessStartedNotification object:_document];
   [center addObserver:self selector:@selector(processEnded:)
                  name: LynkeosProcessEndedNotification object:_document];

   // Launch stacking
   [_stacker stackAction:nil];
}

@end
