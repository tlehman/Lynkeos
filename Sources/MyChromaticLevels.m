//
//  Lynkeos
//  $Id: MyChromaticLevels.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Wed Apr 23 2008.
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

#include <math.h>

#include "SMDoubleSlider.h"

#include "MyChromaticLevels.h"

static NSString *commonPlanesNames[3];

static const double DefaultLogGammaMax = 1.0-M_LN2/M_LN10;

// To allow a double slider in a NSMatrix
@interface NSMatrix(DoubleSlider)
- (void)updateBoundControllerHiValue:(double)val;
- (void)updateBoundControllerLoValue:(double)val;
@end

@implementation NSMatrix(DoubleSlider)
- (void)updateBoundControllerHiValue:(double)val
{
}
- (void)updateBoundControllerLoValue:(double)val
{
}
@end

@interface MyChromaticLevelsView(Private)
- (void) setMatrix:(NSMatrix*)matrix rows:(int)rows ;
- (void) updateMatrices ;
- (void) updateLevels ;
- (void) itemChanged:(NSNotification*)notif ;
- (void) itemModified:(NSNotification*)notif ;
@end

@implementation MyChromaticLevelsView(Private)
- (void) setMatrix:(NSMatrix*)matrix rows:(int)rows
{
   while ( [matrix numberOfRows] > 0 )
      [matrix removeRow:0];

   u_short i;
   for( i = 0; i < rows; i++ )
   {
      // Add the cells, contrary to the double slider prototype, every other
      // slider is a single slider for gamma
      if ( (i%2) != 0 && matrix == _levelsSliders )
      {
         NSSliderCell *proto = [matrix prototype];
         NSSliderCell *slider = [[NSSliderCell alloc] initTextCell:@""];
         [slider setControlSize:[proto controlSize]];
         [slider setNumberOfTickMarks:7];
         [slider setTickMarkPosition:NSTickMarkBelow];
         [slider setMaxValue:DefaultLogGammaMax];
         [slider setMinValue:-DefaultLogGammaMax];
         [matrix addRowWithCells:[NSArray arrayWithObject:slider]];
      }
      else if ( (i%2) != 0
                && (matrix == _whiteTextFields || matrix == _whiteSteppers) )
      {
         [matrix addRowWithCells:
                   [NSArray arrayWithObject:[[NSCell alloc] initTextCell:@""]]];
      }
      else
         [matrix addRow];
   }

   [matrix sizeToCells];
}

- (void) updateMatrices
{
   NSSize formerSize, newSize, containerSize;
   u_short i;
   int num = 1;

   if ( _item != nil )
   {
      num = [_item numberOfPlanes];
      // Small hack: there is no need for plane levels on monochrome images
      if (num == 1 )
         num = 0;
   }
   num = (num+1)*2;

   formerSize = [_levelsNames frame].size;

   // Set the new number of rows
   [self setMatrix:_planeNames rows:num/2];
   [self setMatrix:_levelsNames rows:num];
   [self setMatrix:_blackGammaSteppers rows:num];
   [self setMatrix:_blackGammaTextFields rows:num];
   [self setMatrix:_whiteTextFields rows:num];
   [self setMatrix:_whiteSteppers rows:num];
   [self setMatrix:_levelsSliders rows:num];

   // Set the planes names and cells characteristics
   double levelsStep = [_levelStep doubleValue],
          gammaStep = [_gammaStep doubleValue];
   for( i = 0; i < num/2; i++ )
   {
      NSString *name = nil;
      if ( i == 0 )
         name = @"Global";
      else if ( i < 4 )
         name = commonPlanesNames[i-1];
      else
         name = [NSString stringWithFormat:@"Plane%d",i-1];

      [[_planeNames cellAtRow:i column:0] setStringValue:name];
      [[_levelsNames cellAtRow:i*2 column:0] setStringValue:
                  NSLocalizedString(@"LevelsNames",@"Name of \"levels\" line")];
      [[_levelsNames cellAtRow:i*2+1 column:0] setStringValue:@"Gamma"];

      [[_blackGammaSteppers cellAtRow:2*i column:0] setIncrement:levelsStep];
      [[_whiteSteppers cellAtRow:2*i column:0] setIncrement:levelsStep];
      [[_blackGammaSteppers cellAtRow:2*i+1 column:0] setIncrement:gammaStep];
   }

   // Update the controls values
   [self updateLevels];

   // Adjust view size
   newSize = [_levelsNames frame].size;
   containerSize = [_panel frame].size;
   containerSize.height += newSize.height - formerSize.height;
   [_panel setFrameSize:containerSize];
   [_panel setNeedsDisplay:YES];
}

- (void) updateLevels
{
   double b, w, g, vmin, vmax, gmax = DefaultLogGammaMax;
   BOOL enabled = (_item != nil && [_item getMinLevel:&vmin maxLevel:&vmax]);
   u_short nPlanes;
   SMDoubleSlider *slider;
   u_short i;

   if ( enabled )
   {
      nPlanes = [_item numberOfPlanes];
      BOOL isLevel;

      // Small hack: there is no need for plane levels on monochrome images
      if ( nPlanes == 1 )
         nPlanes = 0;

      // First, get the min and max values
      for( i = 0; i <= nPlanes; i++ )
      {
         // And set the controls values to the levels
         if ( i == 0 )
            isLevel = [_item getBlackLevel:&b whiteLevel:&w gamma:&g];
         else
            isLevel=[_item getBlackLevel:&b whiteLevel:&w gamma:&g forPlane:i-1];

         if ( isLevel )
         {
            if ( b < vmin )
               vmin = b;
            if ( w > vmax )
               vmax = w;
            g = -log(g)/M_LN10;
            if ( g > gmax )
               gmax = g;
            else if ( g < -gmax )
               gmax = -g;
         }
      }

      for( i = 0; i <= nPlanes; i++ )
      {
        // And set the controls values to the levels
         if ( i == 0 )
            isLevel = [_item getBlackLevel:&b whiteLevel:&w gamma:&g];
         else
            isLevel=[_item getBlackLevel:&b whiteLevel:&w gamma:&g forPlane:i-1];

         // Update all sliders bounds
         [[_blackGammaSteppers cellAtRow:2*i column:0] setMaxValue:vmax];
         [[_blackGammaSteppers cellAtRow:2*i column:0] setMinValue:vmin];
         [[_levelsSliders cellAtRow:2*i column:0] setMaxValue:vmax];
         [[_levelsSliders cellAtRow:2*i column:0] setMinValue:vmin];
         [[_whiteSteppers cellAtRow:2*i column:0] setMaxValue:vmax];
         [[_whiteSteppers cellAtRow:2*i column:0] setMinValue:vmin];
         [[_levelsSliders cellAtRow:2*i+1 column:0] setMaxValue:gmax];
         [[_levelsSliders cellAtRow:2*i+1 column:0] setMinValue:-gmax];
         [[_blackGammaSteppers cellAtRow:2*i+1 column:0] setMaxValue:
                                                              exp(M_LN10*gmax)];
         [[_blackGammaSteppers cellAtRow:2*i+1 column:0] setMinValue:
                                                             exp(-M_LN10*gmax)];

         if ( isLevel )
         {
            // Levels line
            [[_blackGammaTextFields cellAtRow:i*2 column:0] setDoubleValue:b];
            [[_blackGammaSteppers cellAtRow:i*2 column:0] setDoubleValue:b];
            slider = [_levelsSliders cellAtRow:i*2 column:0];
            [slider setDoubleLoValue:b];
            [slider setDoubleHiValue:w];
            if ( b < vmin )
               vmin = b;
            if ( w > vmax )
               vmax = b;
            [[_whiteTextFields cellAtRow:i*2 column:0] setDoubleValue:w];
            [[_whiteSteppers cellAtRow:i*2 column:0] setDoubleValue:w];
            // Gamma line
            [[_blackGammaTextFields cellAtRow:i*2+1 column:0] setDoubleValue:g];
            [[_blackGammaSteppers cellAtRow:i*2+1 column:0] setDoubleValue:g];
            g = -log(g)/M_LN10;
            [[_levelsSliders cellAtRow:i*2+1 column:0] setDoubleValue:g];
         }
         else
         {
            [[_blackGammaTextFields cellAtRow:i*2 column:0] setStringValue:@""];
            [[_whiteTextFields cellAtRow:i*2 column:0] setStringValue:@""];
            [[_blackGammaTextFields cellAtRow:i*2+1 column:0] setStringValue:@""];
         }

         [[_blackGammaTextFields cellAtRow:i*2 column:0] setEnabled:isLevel];
         [[_blackGammaSteppers cellAtRow:i*2 column:0] setEnabled:isLevel];
         [[_levelsSliders cellAtRow:i*2 column:0] setEnabled:isLevel];
         [[_whiteTextFields cellAtRow:i*2 column:0] setEnabled:isLevel];
         [[_whiteSteppers cellAtRow:i*2 column:0] setEnabled:isLevel];
         [[_blackGammaTextFields cellAtRow:i*2+1 column:0] setEnabled:isLevel];
         [[_blackGammaSteppers cellAtRow:i*2+1 column:0] setEnabled:isLevel];
         [[_levelsSliders cellAtRow:i*2+1 column:0] setEnabled:isLevel];
      }
   }
   else
   {
      nPlanes = (_item == nil ? 0 : [_item numberOfPlanes]);
      if ( nPlanes == 1 )
         nPlanes = 0;
      for( i = 0; i <= nPlanes; i++ )
      {
         [[_blackGammaTextFields cellAtRow:i*2 column:0] setStringValue:@""];
         [[_whiteTextFields cellAtRow:i*2 column:0] setStringValue:@""];
         [[_blackGammaTextFields cellAtRow:i*2+1 column:0] setStringValue:@""];
      }
   }

   [_blackGammaTextFields setEnabled:enabled];
   [_blackGammaSteppers setEnabled:enabled];
   [_whiteTextFields setEnabled:enabled];
   [_whiteSteppers setEnabled:enabled];
   [_levelsSliders setEnabled:enabled];
}

- (void) itemChanged:(NSNotification*)notif
{
   // Forget about the previous item
   if ( _item != nil )
      [_item release];
   _item = nil;

   // Get the new item
   LynkeosImageProcessingParameter *fakeParam;
   [_window getItemToProcess:&_item andParameter:&fakeParam forView:self];
   if ( _item != nil )
      [_item retain];

   // And display the new levels and the item
   [self updateMatrices];
   [_imageView displayItem:_item];
}

- (void) itemModified:(NSNotification*)notif
{
   id item = [[notif userInfo] objectForKey:LynkeosUserInfoItem];
   if ( item == _item )
      [self updateLevels];
}
@end

@implementation MyChromaticLevelsView

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
   *title = NSLocalizedString(@"ChromaLevelsMenu",
                              @"Chromatic Levels menu title");
   *toolTitle = NSLocalizedString(@"ChromaLevelsTool",
                                  @"Chromatic Levels tool title");
   *key = @"";
   *icon = [NSImage imageNamed:@"ChromaticLevels"];
   *tip = NSLocalizedString(@"ChromaLevelsTip",@"Chromatic Levels tooltip");
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

      [NSBundle loadNibNamed:@"MyChromaticLevels" owner:self];
      [_gammaStep addItemWithObjectValue:[NSNumber numberWithDouble:1.0]];
      [_gammaStep addItemWithObjectValue:[NSNumber numberWithDouble:0.1]];
      [_gammaStep addItemWithObjectValue:[NSNumber numberWithDouble:0.01]];
      [_gammaStep setDoubleValue:0.1];
   }

   return( self );
}

- (id) initWithWindowController: (id <LynkeosWindowController>)window
                       document: (id <LynkeosViewDocument>)document
                  configuration: (id <NSObject>)config
{
   NSAssert( config == nil, @"Chromatic levels does not support configuration" );

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
      [notifCenter addObserver:self selector:@selector(itemChanged:)
                          name: NSOutlineViewSelectionDidChangeNotification
                        object:_textView];
      [notifCenter addObserver:self selector:@selector(itemModified:)
                          name: LynkeosItemChangedNotification
                        object:_document];

      // Synchronize the display
      [self itemChanged:nil];
   }
   else
   {
      // Release the item data
      if ( _item != nil )
         [_item release];
      _item = nil;

      // Stop receiving notifications
      [notifCenter removeObserver:self];
   }
}

- (id <LynkeosProcessingParameter>) getCurrentParameters { return( nil ); }

- (IBAction) changeLevel:(id)sender
{
   NSCell *cell = [sender selectedCell];
   double b, w, g, v;
   int row, col, plane;

   [sender getRow:&row column:&col ofCell:cell];
   plane = row/2;

   // Get the text fields values
   b = [[_blackGammaTextFields cellAtRow:plane*2 column:0] doubleValue];
   w = [[_whiteTextFields cellAtRow:plane*2 column:0] doubleValue];
   g = [[_blackGammaTextFields cellAtRow:plane*2+1 column:0] doubleValue];

   // And modify needed ones if the sender was not a text field
   v = [[sender cellAtRow:row column:0] doubleValue];
   if ( sender == _levelsSliders )
   {
      if ( (row%2) == 0 )
      {
         b = [[sender cellAtRow:row column:0] doubleLoValue];
         w = [[sender cellAtRow:row column:0] doubleHiValue];
      }
      else
         // Gamma
         g = exp(-M_LN10*v);
   }
   else if ( sender == _blackGammaSteppers )
   {
      if ( (row%2) == 0 )
         b = v;
      else
         g  = v;
   }
   else if ( sender == _whiteSteppers )
      w = v;

   if ( b > w )
      b = w;

   // Update the item, the notification will reconcile all control
   if ( plane  == 0 )
      [_item setBlackLevel:b whiteLevel:w gamma:g];
   else
      [_item setBlackLevel:b whiteLevel:w gamma:g forPlane:plane-1];
   // And redisplay it
   [_imageView updateImage];
}

- (IBAction) changeLevelStep:(id)sender
{
   const double levelsStep = [_levelStep doubleValue];
   const u_short nPlanes = [_item numberOfPlanes];
   u_short i;

   for( i = 0; i <= nPlanes; i++ )
   {
      [[_blackGammaSteppers cellAtRow:2*i column:0] setIncrement:levelsStep];
      [[_whiteSteppers cellAtRow:2*i column:0] setIncrement:levelsStep];
   }
}

- (IBAction) changeGammaStep:(id)sender
{
   const double gammaStep = [_gammaStep doubleValue];
   const u_short nPlanes = [_item numberOfPlanes];
   u_short i;

   for( i = 0; i <= nPlanes; i++ )
   {
      [[_blackGammaSteppers cellAtRow:2*i+1 column:0] setIncrement:gammaStep];
   }
}
@end
