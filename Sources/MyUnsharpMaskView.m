//
//  Lynkeos
//  $Id: MyUnsharpMaskView.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun Dec 2 2007.
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

#include "MyUnsharpMaskView.h"

@interface MyUnsharpMaskView(Private)
- (void) itemChange:(NSNotification*)notif ;
- (void) processStarted:(NSNotification*)notif ;
- (void) processEnded:(NSNotification*)notif ;
- (void) updateProgressBar ;
@end

@implementation MyUnsharpMaskView(Private)
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
         _params = [[MyUnsharpMaskParameters alloc] init];
         _params->_radius = 2.5;
         _params->_gain = 0.0;
         _params->_gradientOnly = NO;
      }
      else
         [_params retain];

      [_logRadius setDoubleValue:_params->_radius];
      [_gainSlider setDoubleValue:_params->_gain];
      [_gainText setDoubleValue:_params->_gain];
      [_gradientButton setState:
                            (_params->_gradientOnly ? NSOnState : NSOffState )];
   }
   else
   {
      [_radiusText setStringValue:@""];
      [_gainText setStringValue:@""];
   }

   [_radiusSlider setEnabled:(!_isProcessing && _params != nil)];
   [_radiusText setEnabled:(!_isProcessing && _params != nil)];
   [_gainSlider setEnabled:(!_isProcessing && _params != nil)];
   [_gainText setEnabled:(!_isProcessing && _params != nil)];   
   [_gradientButton setEnabled:(!_isProcessing && _params != nil)];   

   // Display the image
   [_imageView displayItem:_item];
}

- (void) processStarted:(NSNotification*)notif
{
   _isProcessing = YES;

   // Disable the controls
   [_radiusSlider setEnabled:NO];
   [_radiusText setEnabled:NO];
   [_gainSlider setEnabled:NO];
   [_gainText setEnabled:NO];
   [_gradientButton setEnabled:NO];

   if ( [[[notif userInfo] objectForKey:LynkeosUserInfoProcess] isEqual:
                                                        [MyUnsharpMask class]] )
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

   // Re-enable the controls
   [_radiusSlider setEnabled:YES];
   [_radiusText setEnabled:YES];
   [_gainSlider setEnabled:YES];
   [_gainText setEnabled:YES];
   [_gradientButton setEnabled:YES];

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

@implementation MyUnsharpMaskView
+ (BOOL) isStandardProcessingViewController { return(YES); }

+ (ProcessingViewKind_t) processingViewKindForConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"UnsharpMask does not support configuration" );
   return(ImageProcessingKind);
}

+ (BOOL) isViewControllingProcess:(Class)processingClass
                       withConfig:(id <NSObject>*)config
{
   *config = nil;
   return( processingClass == [MyUnsharpMask class] );
}

+ (void) getProcessingTitle:(NSString**)title
                  toolTitle:(NSString**)toolTitle
                        key:(NSString**)key
                       icon:(NSImage**)icon
                        tip:(NSString**)tip
                  forConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"UnsharpMask does not support configuration" );
   *title = NSLocalizedString(@"UnsharpMask",@"Unsharp mask tool");
   *toolTitle = NSLocalizedString(@"UnsharpMask",@"Unsharp mask tool");
   *key = @"u";
   *icon = [NSImage imageNamed:@"UnsharpMask"];
   *tip = NSLocalizedString(@"UnsharpMaskTip",@"Unsharp mask tooltip");;
}

+ (unsigned int) allowedDisplaysForConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"UnsharpMask does not support configuration" );
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

      [NSBundle loadNibNamed:@"MyUnsharpMask" owner:self];
   }

   return( self );
}

- (void) dealloc
{
   if ( _params != nil )
      [_params release];
   [_logRadius release];
   if ( _progressTimer != nil )
      [_progressTimer invalidate];
   [super dealloc];
}

- (id) initWithWindowController: (id <LynkeosWindowController>)window
                       document: (id <LynkeosViewDocument>)document
                  configuration: (id <NSObject>)config
{
   NSAssert( config == nil, @"UnsharpMask does not support configuration" );

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
   return( [MyUnsharpMask class] );
}

- (IBAction) radiusChange: (id)sender
{
   _params->_radius = [_logRadius valueFrom:sender];
   _params->_nextY = 0;

   [_document startProcess:[MyUnsharpMask class]
                   forItem:_item parameters:_params];
}

+ (BOOL) hasProgressIndicator { return(YES); }

- (IBAction) gainChange: (id)sender
{
   _params->_gain = [sender doubleValue];
   if ( sender == _gainSlider )
      [_gainText setDoubleValue:_params->_gain];
   else
   {
      if ( _params->_gain > [_gainSlider maxValue] )
         [_gainSlider setMaxValue:_params->_gain];
      [_gainSlider setDoubleValue:_params->_gain];
   }
   _params->_nextY = 0;

   [_document startProcess:[MyUnsharpMask class]
                   forItem:_item parameters:_params];
}

- (IBAction) gradientChange: (id)sender
{
   _params->_gradientOnly = [sender state];
   _params->_nextY = 0;

   [_document startProcess:[MyUnsharpMask class]
                   forItem:_item parameters:_params];
}
@end
