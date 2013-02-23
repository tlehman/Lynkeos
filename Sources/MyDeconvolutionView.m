//
//  Lynkeos
//  $Id: MyDeconvolutionView.m 454 2008-09-21 22:15:07Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Mon Oct 1 2007.
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

#include "MyDeconvolutionView.h"

@interface MyDeconvolutionView(Private)
- (void) itemChange:(NSNotification*)notif ;
- (void) processStarted:(NSNotification*)notif ;
- (void) processEnded:(NSNotification*)notif ;
- (void) updateProgressBar ;
@end

@implementation MyDeconvolutionView(Private)
- (void) itemChange:(NSNotification*)notif
{
   // Update item and parameters
   if ( _params != nil )
      [_params release];
   [_window getItemToProcess:&_item andParameter:&_params forView:self];

   if ( _item != nil )
   {
      if ( _params == nil )
      {
         // Create some new parameters
         _params = [[MyDeconvolutionParameters alloc] init];
         _params->_radius = 2.5;
         _params->_threshold = 1.0;
      }
      else
         [_params retain];

      [_logRadius setDoubleValue:_params->_radius];
      [_thresholdSlider setDoubleValue:_params->_threshold];
      [_thresholdText setDoubleValue:_params->_threshold];
   }
   else
   {
      [_radiusText setStringValue:@""];
      [_thresholdText setStringValue:@""];
   }

   [_radiusSlider setEnabled:(!_isProcessing && _item != nil)];
   [_radiusText setEnabled:(!_isProcessing && _item != nil)];
   [_thresholdSlider setEnabled:(!_isProcessing && _item != nil)];
   [_thresholdText setEnabled:(!_isProcessing && _item != nil)];

   // Display the image
   [_imageView displayItem:_item];
}

- (void) processStarted:(NSNotification*)notif
{
   _isProcessing = YES;

   // Disable the controls
   [_radiusSlider setEnabled:NO];
   [_radiusText setEnabled:NO];
   [_thresholdSlider setEnabled:NO];
   [_thresholdText setEnabled:NO];

   if ( [[[notif userInfo] objectForKey:LynkeosUserInfoProcess] isEqual:
                                                      [MyDeconvolution class]] )
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

   // Disable the controls
   [_radiusSlider setEnabled:YES];
   [_radiusText setEnabled:YES];
   [_thresholdSlider setEnabled:YES];
   [_thresholdText setEnabled:YES];

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

@implementation MyDeconvolutionView
+ (BOOL) isStandardProcessingViewController { return(YES); }

+ (ProcessingViewKind_t) processingViewKindForConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"Deconvolution does not support configuration" );
   return(ImageProcessingKind);
}

+ (BOOL) isViewControllingProcess:(Class)processingClass
                       withConfig:(id <NSObject>*)config
{
   *config = nil;
   return( processingClass == [MyDeconvolution class] );
}

+ (void) getProcessingTitle:(NSString**)title
                  toolTitle:(NSString**)toolTitle
                        key:(NSString**)key
                       icon:(NSImage**)icon
                        tip:(NSString**)tip
                  forConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"Deconvolution does not support configuration" );
   *title = NSLocalizedString(@"Deconvolution",@"Deconvolution tool");
   *toolTitle = NSLocalizedString(@"Deconvolution",@"Deconvolution tool");
   *key = @"d";
   *icon = [NSImage imageNamed:@"Deconvolution"];
   *tip = NSLocalizedString(@"DeconvolutionTip",@"Deconvolution tooltip");;
}

+ (unsigned int) allowedDisplaysForConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"Deconvolution does not support configuration" );
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
      _progressTimer = nil;

      [NSBundle loadNibNamed:@"MyDeconvolution" owner:self];
   }

   return( self );
}

- (void) dealloc
{
   if ( _params != nil )
      [_params release];
   if ( _progressTimer != nil )
      [_progressTimer invalidate];
   [_logRadius release];
   [super dealloc];
}

- (id) initWithWindowController: (id <LynkeosWindowController>)window
                       document: (id <LynkeosViewDocument>)document
                  configuration: (id <NSObject>)config
{
   NSAssert( config == nil, @"Deconvolution does not support configuration" );

   if ( (self = [self init]) != nil )
   {
      _document = document;
      _window = window;
      _imageView = [_window getImageView];
      _textView = [_window getTextView];
      _logRadius = [[LynkeosLogFields alloc] initWithSlider:_radiusSlider
                                          andTextField:_radiusText];
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

- (Class) processingClass
{
   return( [MyDeconvolution class] );
}

+ (BOOL) hasProgressIndicator { return(YES); }

- (IBAction) radiusChange: (id)sender
{
   _params->_radius = [_logRadius valueFrom:sender];
   _params->_nextY = 0;

   [_document startProcess:[MyDeconvolution class]
                   forItem:_item parameters:_params];
}

- (IBAction) thresholdChange: (id)sender
{
   _params->_threshold = [sender doubleValue];
   if ( sender == _thresholdSlider )
      [_thresholdText setDoubleValue:_params->_threshold];
   else
      [_thresholdSlider setDoubleValue:_params->_threshold];
   _params->_nextY = 0;

   [_document startProcess:[MyDeconvolution class]
                   forItem:_item parameters:_params];
}
@end
