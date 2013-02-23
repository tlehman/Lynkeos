//
//  Lynkeos
//  $Id: MyWaveletView.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Dec 7 2007.
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

#include "processing_core.h"
#include "LynkeosProcessableImage.h"
#include "MyWaveletView.h"

const double K_DEFAULT_MIN_WEIGHT = -1.0,
             K_DEFAULT_MAX_WEIGHT = 5.0;

typedef enum
{
   ArithmeticProgression = 0,
   GeometricProgression
} progression_t;

static int compareWavelet( const void *w1, const void *w2 )
{
   double order = ((wavelet_t *)w1)->_frequency - ((wavelet_t *)w2)->_frequency;
   if ( order > 0.0 )
      return( 1 );
   else if ( order < 0.0 )
      return( -1 );
   else
      return( 0 );
}

@interface MyWaveletView(Private)
- (void) setMatrix:(NSMatrix*)matrix rows:(int)rows ;
- (void) sortFrequencies ;
- (void) updateMatrices ;
- (void) updateSlider:(NSSlider*)slider minMaxWithValue:(double)v ;
- (void) generateWavelets ;
- (void) itemChange:(NSNotification*)notif ;
- (void) processStarted:(NSNotification*)notif ;
- (void) processEnded:(NSNotification*)notif ;
- (void) updateProgressBar ;
@end

@implementation MyWaveletView(Private)
- (void) setMatrix:(NSMatrix*)matrix rows:(int)rows
{
   while ( [matrix numberOfRows] > rows )
      [matrix removeRow:0];
   while ( [matrix numberOfRows] < rows )
      [matrix addRow];

   [matrix sizeToCells];
}

- (void) sortFrequencies
{
   const LynkeosIntegerSize s = [_item imageSize];
   const double minFreq = fmin( 1.0/s.width, 1.0/s.height );
   int i;

   qsort( _params->_wavelet, _params->_numberOfWavelets, sizeof(wavelet_t), 
          compareWavelet );

   for ( i = 0; i < _params->_numberOfWavelets; i++ )
   {
      NSTextField *text = [_freqMatrix cellAtRow:i column:0];
      double v = _params->_wavelet[i]._frequency;

      if ( _displayFrequency )
      {
         [[text formatter] setMinimumFractionDigits:4];
         [text setDoubleValue:v];
      }
      else
      {
         [[text formatter] setMinimumFractionDigits:1];
         if ( v != 0.0 )
            [text setDoubleValue:1.0/v];
         else
            [text setStringValue:@"---- "];
      }

      NSColor *color;
      if ( i != 0
           && (_params->_wavelet[i]._frequency < minFreq
               || _params->_wavelet[i]._frequency  > M_SQRT1_2) )
         color = [NSColor redColor];
      else
         color = [NSColor blackColor];
      [text setTextColor:color];

      NSSlider *slider = [_levelSliderMatrix cellAtRow:i column:0];
      [self updateSlider:slider minMaxWithValue:_params->_wavelet[i]._weight];
      [slider setDoubleValue: _params->_wavelet[i]._weight];
      [[_levelTextMatrix cellAtRow:i column:0] setDoubleValue:
                                                  _params->_wavelet[i]._weight];
   }
   [[_freqMatrix cellAtRow:0 column:0] setEnabled:NO];
   [[_deleteFreqButton cellAtRow:0 column:0] setEnabled:NO];
}

- (void) updateSlider:(NSSlider*)slider minMaxWithValue:(double)v
{
   double newMin = 0.0, newMax = 0.0;

   if ( v > [slider maxValue] )
   {
      newMax = v;
      newMin = [slider minValue]*newMax/[slider maxValue];
   }
   else if ( v < [slider minValue] )
   {
      newMin = v;
      newMax = [slider maxValue]*newMin/[slider minValue];
   }
   if ( newMin != 0.0 && newMax != 0.0 )
   {
      int i, n = [_levelSliderMatrix numberOfRows];
      for( i = 0; i < n; i++ )
      {
         [[_levelSliderMatrix cellAtRow:i column:0] setMinValue:newMin];
         [[_levelSliderMatrix cellAtRow:i column:0] setMaxValue:newMax];
      }
   }   
}

- (void) updateMatrices
{
   NSSize formerSize, newSize, containerSize;
   int num = 1;

   if ( _params != nil )
      num = _params->_numberOfWavelets;

   formerSize = [_freqMatrix frame].size;

   // Set the new number of rows
   [self setMatrix:_deleteFreqButton rows:num];
   [self setMatrix:_freqMatrix rows:num];
   [self setMatrix:_selectMatrix rows:num];
   [self setMatrix:_levelSliderMatrix rows:num];
   [self setMatrix:_levelTextMatrix rows:num];

   if ( _params != nil )
   {
      [_numberOfFreqStep setIntValue:num];
      [_numberOfFreqText setIntValue:num];
      [self sortFrequencies];
   }
   else
   {
      [_numberOfFreqText setStringValue:@""];
      [[_freqMatrix cellAtRow:0 column:0] setStringValue:@""];
      [[_levelTextMatrix cellAtRow:0 column:0] setStringValue:@""];
   }

   newSize = [_freqMatrix frame].size;
   containerSize = [_panel frame].size;
   containerSize.height += newSize.height - formerSize.height;
   [_panel setFrameSize:containerSize];
   [_panel setNeedsDisplay:YES];
}

- (void) generateWavelets
{
   BOOL geometric =
              ([_progressionPopup indexOfSelectedItem] == GeometricProgression);
   int numberOfFreq = [_numberOfFreqStep intValue];
   double progressionStep = [_progrStepText doubleValue];
   double increment, cumul;
   int i;

   if ( geometric )
      increment = 0.5/pow( progressionStep, (double)numberOfFreq-2.0 );
   else
      increment = 0.5/((double)numberOfFreq - 1.0);

   _params->_numberOfWavelets = numberOfFreq;
   if ( _params->_wavelet != NULL )
      free( _params->_wavelet );
   _params->_wavelet = (wavelet_t*)malloc( numberOfFreq*sizeof(wavelet_t) );
   for ( i = 0, cumul = 0; i < numberOfFreq; i++ )
   {
      _params->_wavelet[i]._frequency = cumul;
      if ( geometric )
      {
         if ( i == 0 )
            cumul = increment;
         else
            cumul *= progressionStep;
      }
      else
         cumul += increment;

      if ( cumul > M_SQRT1_2 )
         cumul = M_SQRT1_2;

      _params->_wavelet[i]._weight = 1.0;
   }
}

- (void) itemChange:(NSNotification*)notif
{
   // Update item and parameters
   if ( _params != nil )
      [_params release];
   [_window getItemToProcess:&_item andParameter:&_params forView:self];

   [_progressionPopup setEnabled:(_item!=nil)];
   int progression = [_progressionPopup indexOfSelectedItem];
   [_progrStepText setEnabled:(_item!=nil
                               && progression == GeometricProgression)];
   [_numberOfFreqText setEnabled:(_item!=nil && progression >= 0)];
   [_numberOfFreqStep setEnabled:(_item!=nil && progression >= 0)];
   [_algorithmPopup setEnabled:(_item!=nil)];
   [_addFreqButton setEnabled:(_item!=nil)];
   [_deleteFreqButton setEnabled:(_item!=nil)];
   [_freqMatrix setEnabled:(_item!=nil)];
   [_selectMatrix setEnabled:(_item!=nil)];
   [_levelSliderMatrix setEnabled:(_item!=nil)];
   [_levelTextMatrix setEnabled:(_item!=nil)];

   // Reset sliders ranges
   NSEnumerator *cells = [[_levelSliderMatrix cells] objectEnumerator];
   NSSliderCell *cell;
   while ( (cell = [cells nextObject]) != nil )
   {
      [cell setMinValue:K_DEFAULT_MIN_WEIGHT];
      [cell setMaxValue:K_DEFAULT_MAX_WEIGHT];
   }

   if ( _item == nil )
      [self updateMatrices];

   else
   {
      if ( _params == nil )
      {
         [_numberOfFreqText setIntValue:[_numberOfFreqStep intValue]];
         if ( [_progressionPopup indexOfSelectedItem] < 0 )
         {
            [_progressionPopup selectItemAtIndex:GeometricProgression];
            [_progrStepText setEnabled:YES];
            [_numberOfFreqStep setEnabled:YES];
            [_numberOfFreqText setEnabled:YES];
         }
         // Create some new parameters
         _params = [[MyWaveletParameters alloc] init];
         [self generateWavelets];
      }
      else
      {
         [_params retain];
         [_progressionPopup selectItemAtIndex:-1];
         [_progrStepText setEnabled:NO];
         [_numberOfFreqStep setEnabled:NO];
         [_numberOfFreqText setEnabled:NO];
         [_algorithmPopup selectItemWithTag:_params->_waveletKind];
      }

      // Update the view
      [self updateMatrices];
   }

   // Display the image
   [_imageView displayItem:_item];
}

- (void) processStarted:(NSNotification*)notif
{
   _isProcessing = YES;

   // Deactivate all checkboxes, just in case
   int i;
   for( i = 0; i < _params->_numberOfWavelets; i++ )
      [[_selectMatrix cellAtRow:i column:0] setState:NSOffState];

   // Disable the controls
   [_progressionPopup setEnabled:NO];
   [_progrStepText setEnabled:NO];
   [_numberOfFreqText setEnabled:NO];
   [_numberOfFreqStep setEnabled:NO];
   [_algorithmPopup setEnabled:NO];
   [_addFreqButton setEnabled:NO];
   [_deleteFreqButton setEnabled:NO];
   [_freqMatrix setEnabled:NO];
   [_selectMatrix setEnabled:NO];
   [_levelSliderMatrix setEnabled:NO];
   [_levelTextMatrix setEnabled:NO];

   if ( [[[notif userInfo] objectForKey:LynkeosUserInfoProcess] isEqual:
                                                            [MyWavelet class]] )
   {
      [_progress setMaxValue:[_item imageSize].height - 1];
      [_progress setIndeterminate:YES];
      [_progress startAnimation:self];
      _progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                        target:self
                                           selector:@selector(updateProgressBar)
                                                      userInfo:nil
                                                       repeats:YES];
   }
}

- (void) processEnded:(NSNotification*)notif
{
   _isProcessing = NO;

   // Reenable the controls
   [_progressionPopup setEnabled:YES];
   int progression = [_progressionPopup indexOfSelectedItem];
   [_progrStepText setEnabled:(progression == GeometricProgression)];
   [_numberOfFreqText setEnabled:(progression >= 0)];
   [_numberOfFreqStep setEnabled:(progression >= 0)];
   [_algorithmPopup setEnabled:YES];
   [_addFreqButton setEnabled:YES];
   [_deleteFreqButton setEnabled:YES];
   [_freqMatrix setEnabled:YES];
   [_selectMatrix setEnabled:YES];
   [_levelSliderMatrix setEnabled:YES];
   [_levelTextMatrix setEnabled:YES];
   [[_freqMatrix cellAtRow:0 column:0] setEnabled:NO];
   [[_deleteFreqButton cellAtRow:0 column:0] setEnabled:NO];

   [_progressTimer invalidate];
   _progressTimer = nil;
   // Here we cheat a bit.
   // As the image refresh can be long, we start by forcing the display to
   // show the progress bar as full before final refresh
   [_progress setIndeterminate:NO];
   [_progress stopAnimation:self];
   [_progress setDoubleValue:[_item imageSize].height - 1];
   [_panel display];
   [_progress setDoubleValue:0.0];

   // Redisplay the image
   [_imageView displayItem:_item];
}

- (void) updateProgressBar
{
   if ( _params->_nextY != 0 )
   {
      if ( [_progress isIndeterminate] )
      {
         [_progress setIndeterminate:NO];
         [_progress stopAnimation:self];
      }

      [_progress setDoubleValue:_params->_nextY];
   }
}
@end

@implementation MyWaveletView
+ (BOOL) isStandardProcessingViewController { return(YES); }

+ (ProcessingViewKind_t) processingViewKindForConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"Wavelet does not support configuration" );
   return(ImageProcessingKind);
}

+ (BOOL) isViewControllingProcess:(Class)processingClass
                       withConfig:(id <NSObject>*)config
{
   *config = nil;
   return( processingClass == [MyWavelet class] );
}

+ (void) getProcessingTitle:(NSString**)title
                  toolTitle:(NSString**)toolTitle
                        key:(NSString**)key
                       icon:(NSImage**)icon
                        tip:(NSString**)tip
                  forConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"Wavelet does not support configuration" );
   *title = NSLocalizedString(@"WaveletMenu",@"Wavelet transform menu");
   *toolTitle = NSLocalizedString(@"WaveletTool",@"Wavelet transform tool");
   *key = @"w";
   *icon = [NSImage imageNamed:@"Wavelet"];
   *tip = NSLocalizedString(@"WaveletTip",@"Wavelet transform tooltip");;
}

+ (unsigned int) allowedDisplaysForConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"Wavelet does not support configuration" );
   return( BottomTab|BottomTab_NoList|SeparateView|SeparateView_NoList );
}

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _document = nil;
      _window = nil;
      _imageView = nil;
      _textView = nil;

      _item = nil;
      _params = nil;
      _isProcessing = NO;
      _displayFrequency = YES;
      _progressTimer = nil;

      [NSBundle loadNibNamed:@"MyWavelet" owner:self];
   }

   return( self );
}

- (void) dealloc
{
   if ( _params != nil )
      [_params release];
   if ( _progressTimer != nil )
      [_progressTimer invalidate];
   [super dealloc];
}

- (id) initWithWindowController: (id <LynkeosWindowController>)window
                       document: (id <LynkeosViewDocument>)document
                  configuration: (id <NSObject>)config
{
   NSAssert( config == nil, @"Wavelet does not support configuration" );

   if ( (self = [self init]) != nil )
   {
      _document = document;
      _window = window;
      _imageView = [_window getImageView];
      _realImageView = [_window getRealImageView];
      _textView = [_window getTextView];
      [_freqDisplaySwitch setStringValue:NSLocalizedString(@"WaveletFreq",
                                                 @"Wavelet frequency display")];
      [_progress setDoubleValue:0.0];
   }

   return( self );
}

- (NSView*) getProcessingView { return( _panel ); }

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
      [notifCenter addObserver:self
                      selector:@selector(itemChange:)
                          name: NSOutlineViewSelectionDidChangeNotification
                        object:_textView];
      [notifCenter addObserver:self
                      selector:@selector(processStarted:)
                          name: LynkeosProcessStartedNotification
                        object:_document];
      [notifCenter addObserver:self
                      selector:@selector(processEnded:)
                          name: LynkeosProcessStackEndedNotification
                        object:_document];
      [notifCenter addObserver:self
                      selector:@selector(itemChange:)
                          name: LynkeosDataModeChangeNotification
                        object:_document];

      // Synchronize the display
      [self itemChange:nil];
   }
   else
   {
      // Release the parameters
      [_params release];
      _params = nil;

      // Stop receiving notifications
      [notifCenter removeObserver:self];
   }
}

- (LynkeosProcessingViewFrame_t) preferredDisplay { return( BottomTab ); }

- (id <LynkeosProcessingParameter>) getCurrentParameters
{
   return( _params );
}

- (Class) processingClass { return( [MyWavelet class] ); }

+ (BOOL) hasProgressIndicator { return(YES); }

- (IBAction) progressionChange: (id)sender
{
   [_numberOfFreqText setEnabled:YES];
   [_numberOfFreqStep setEnabled:YES];
   [_progrStepText setEnabled:
                       ([sender indexOfSelectedItem] == GeometricProgression )];
   [self generateWavelets];
   [self updateMatrices];

   // And start the process
   _params->_nextY = 0;
   [_document startProcess:[MyWavelet class]
                   forItem:_item parameters:_params];
}

- (IBAction) progressionStepChange: (id)sender
{
   [self generateWavelets];
   [self updateMatrices];

   // And start the process
   _params->_nextY = 0;
   [_document startProcess:[MyWavelet class]
                   forItem:_item parameters:_params];
}

- (IBAction) numberOfFreqChange: (id)sender
{
   int num = [sender intValue];
   if ( sender == _numberOfFreqText )
      [_numberOfFreqStep setIntValue:num];
   else if ( sender == _numberOfFreqStep )
      [_numberOfFreqText setIntValue:num];
   [self generateWavelets];
   [self updateMatrices];

   // And start the process
   _params->_nextY = 0;
   [_document startProcess:[MyWavelet class]
                   forItem:_item parameters:_params];
}

- (IBAction) algorithmChange: (id)sender
{
   _params->_waveletKind = [sender selectedTag];

   _params->_nextY = 0;
   [_document startProcess:[MyWavelet class]
                   forItem:_item parameters:_params];
}

- (IBAction) freqDisplayChange: (id)sender
{
   _displayFrequency = !_displayFrequency;
   if( _displayFrequency )
      [_freqDisplaySwitch setTitle:NSLocalizedString(@"WaveletFreq",
                                                 @"Wavelet frequency display")];
   else
      [_freqDisplaySwitch setTitle:NSLocalizedString(@"WaveletPeriod",
                                                    @"Wavelet period display")];

   [self sortFrequencies];
}

- (IBAction) addOneFrequency: (id)sender
{
   _params->_numberOfWavelets++;
   _params->_wavelet = (wavelet_t*)realloc( _params->_wavelet,
                                 _params->_numberOfWavelets*sizeof(wavelet_t) );
   _params->_wavelet[_params->_numberOfWavelets-1]._frequency = M_SQRT1_2;
   _params->_wavelet[_params->_numberOfWavelets-1]._weight = 0.0;

   [self updateMatrices];
   [_progressionPopup selectItemAtIndex:-1];

   // And start the process
   _params->_nextY = 0;
   [_document startProcess:[MyWavelet class]
                   forItem:_item parameters:_params];
}

- (IBAction) deleteOneFrequency: (id)sender
{
   NSCell *cell = [sender selectedCell];
   int row, col, i;

   [sender getRow:&row column:&col ofCell:cell];
   for( i = row+1; i < _params->_numberOfWavelets; i++ )
      _params->_wavelet[i-1] = _params->_wavelet[i];

   _params->_numberOfWavelets--;
   _params->_wavelet = (wavelet_t*)realloc( _params->_wavelet,
                                 _params->_numberOfWavelets*sizeof(wavelet_t) );

   [self updateMatrices];
   [_progressionPopup selectItemAtIndex:-1];

   // And start the process
   _params->_nextY = 0;
   [_document startProcess:[MyWavelet class]
                   forItem:_item parameters:_params];
}

- (IBAction) freqChange: (id)sender
{
   NSCell *cell = [sender selectedCell];
   double v = [cell doubleValue];
   int row, col;

   if ( !_displayFrequency )
      v = 1.0/v;

   [_progressionPopup selectItemAtIndex:-1];

   // Update the parameters
   [sender getRow:&row column:&col ofCell:cell];
   _params->_wavelet[row]._frequency = v;
   [self sortFrequencies];

   // And start the process
   _params->_nextY = 0;
   [_document startProcess:[MyWavelet class]
                   forItem:_item parameters:_params];
}

- (IBAction) selectChange: (id)sender
{
   NSCell *cell = [sender selectedCell];
   int row, col, i;
   [sender getRow:&row column:&col ofCell:cell];

   if ( [cell state] == NSOnState )
   {
      // Deactivate all other checkboxes (NSRadioModeMatrix does not works right)
      for( i = 0; i < _params->_numberOfWavelets; i++ )
      {
         if ( i != row )
            [[sender cellAtRow:i column:0] setState:NSOffState];
      }

      // Do a preview of the image processed by that wavelet
      // Create a copy of the current item
      const LynkeosIntegerRect r = {{0,0},[_item imageSize]};
      LynkeosProcessableImage *item = [[[LynkeosProcessableImage alloc] init] autorelease];
      LynkeosStandardImageBuffer *buf = nil;

      [_item getImageSample:&buf inRect:r];
      [item setOriginalImage:buf];

      // Create a single wavelet by keeping only the requested frequency
      MyWaveletParameters *p = [[[MyWaveletParameters alloc] init] autorelease];
      p->_numberOfWavelets = _params->_numberOfWavelets;
      p->_waveletKind = _params->_waveletKind;
      p->_wavelet = (wavelet_t*)malloc( p->_numberOfWavelets*sizeof(wavelet_t) );
      memcpy( p->_wavelet, _params->_wavelet,
              p->_numberOfWavelets*sizeof(wavelet_t) );
      for( i = 0; i < p->_numberOfWavelets; i++ )
      {
         if ( i == row )
            p->_wavelet[i]._weight = 1.0;
         else
            p->_wavelet[i]._weight = 0.0;
      }

      // Process in this thread
      MyWavelet *process =
         [[[MyWavelet alloc] initWithDocument:nil
                                   parameters:p
                                    precision:PROCESSING_PRECISION] autorelease];
      [process processItem:item];
      [process finishProcessing];

      double vmin, vmax;
      [item getMinLevel:&vmin maxLevel:&vmax];
      if ( vmin >= vmax )
         vmax = vmin + 1.0;
      [item setBlackLevel:vmin whiteLevel:vmax gamma:1.0];

      // Display the result
      [_realImageView displayItem:item];
   }
   else
      [_realImageView displayItem:_item];
}

- (IBAction) levelChange: (id)sender
{
   NSCell *cell = [sender selectedCell];
   double v = [cell doubleValue];
   int row, col;

   // Reconcile the controls
   [sender getRow:&row column:&col ofCell:cell];

   if ( sender == _levelSliderMatrix )
      [[_levelTextMatrix cellAtRow:row column:0] setDoubleValue:v];
   else if ( sender == _levelTextMatrix )
   {
      NSSlider*slider = [_levelSliderMatrix cellAtRow:row column:0];
      [self updateSlider:slider minMaxWithValue:v];
      [slider setDoubleValue:v];
   }
   else
      NSAssert( NO, @"Unknown control for wavelet level" );

   // Update the parameters
   _params->_wavelet[row]._weight = v;

   // And start the process
   _params->_nextY = 0;
   [_document startProcess:[MyWavelet class]
                   forItem:_item parameters:_params];
}
@end
