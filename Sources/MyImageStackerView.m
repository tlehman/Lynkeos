//
//  Lynkeos
//  $Id: MyImageStackerView.m 506 2011-03-26 18:40:46Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Wed Jun 21 2007.
//  Copyright (c) 2007-2011. Jean-Etienne LAMIAUD
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

#include "MyUserPrefsController.h"
#include "MyImageListItem.h"
#include "MyGeneralPrefs.h"
#include "MyImageStacker.h"
#include "MyImageStackerPrefs.h"
#include "MyImageStackerView.h"

static NSMutableDictionary *monitorDictionary = nil;

/*!
 * @abstract Lightweight object for validating
 * @discussion This object monitors the document for validating the process
 *    activation.
 * @ingroup Processing
 */
@interface MyImageStackerMonitor : NSObject
{
   NSObject <LynkeosViewDocument>      *_document; //!< Our document
   NSObject <LynkeosWindowController>  *_window;  //!< Our window controller
}

/*!
 * @abstract Process the notification of a new document creation
 * @discussion It will be used to create a monitor object for the document.
 * @param notif The notification
 */
+ (void) documentDidOpen:(NSNotification*)notif;
/*!
 * @abstract Process the notification of document closing
 * @param notif The notification
 */
+ (void) documentWillClose:(NSNotification*)notif;

/*!
 * @abstract Dedicated initializer
 * @param document The document to monitor
 * @param window The window controller to monitor
 * @result Initialized 
 */
- (id) initWithDocument:(NSObject <LynkeosViewDocument>*)document
       windowController:(NSObject <LynkeosWindowController> *)window;
/*!
 * @abstract The document current list was changed
 * @param notif The notification
 */
- (void) changeOfList:(NSNotification*)notif;
@end

@implementation MyImageStackerMonitor
+ (void) load
{
   // Register the class for document notifications
   NSNotificationCenter *notif = [NSNotificationCenter defaultCenter];

   monitorDictionary = [[NSMutableDictionary alloc] initWithCapacity:1];

   [notif addObserver:self selector:@selector(documentDidOpen:)
                 name:LynkeosDocumentDidOpenNotification
               object:nil];
   [notif addObserver:self selector:@selector(documentWillClose:)
                 name:LynkeosDocumentWillCloseNotification
               object:nil];
}

+ (void) documentDidOpen:(NSNotification*)notif
{
   id <LynkeosViewDocument> document = [notif object];
   id <LynkeosWindowController> windowCtrl =
                [[notif userInfo] objectForKey:LynkeosUserinfoWindowController];

   // Create a monitor object for this document
   [monitorDictionary setObject:
      [[[MyImageStackerMonitor alloc] initWithDocument:document
                                      windowController:windowCtrl] autorelease]
                         forKey:[NSData dataWithBytes:&document
                                               length:sizeof(id)]];
}

+ (void) documentWillClose:(NSNotification*)notif
{
   id <LynkeosViewDocument> document = [notif object];

   // Delete the monitor object
   [monitorDictionary removeObjectForKey:[NSData dataWithBytes:&document
                                                        length:sizeof(id)]];
}

- (id) initWithDocument:(NSObject <LynkeosViewDocument>*)document
       windowController:(NSObject <LynkeosWindowController> *)window
{
   if ( (self = [self init]) != nil )
   {
      _document = document;
      _window = window;

      NSNotificationCenter *notif = [NSNotificationCenter defaultCenter];

      // Register for list change notifications
      [notif addObserver:self
                selector:@selector(changeOfList:)
                    name: LynkeosItemAddedNotification
                  object:_document];
      [notif addObserver:self
                selector:@selector(changeOfList:)
                    name: LynkeosItemRemovedNotification
                  object:_document];
      [notif addObserver:self
                selector:@selector(changeOfList:)
                    name: LynkeosListChangeNotification
                  object:_document];

      // And set initial authorization
      [self changeOfList:nil];
   }

   return( self );
}

- (void) dealloc
{
   // Unregister for all notifications
   [[NSNotificationCenter defaultCenter] removeObserver:self];

   [super dealloc];
}

- (void) changeOfList:(NSNotification*)notif
{
   [_window setProcessing:[MyImageStackerView class] andIdent:nil
            authorization:([[[_document currentList] imageArray] count] != 0)];
}
@end

/*!
 * @abstract Object used for displaying the result name
 */
@interface MyImageStackerPseudoItem : NSObject <LynkeosProcessingParameter>
{
@public
   NSString *_name; //!< The name to display in the outline view
}

/*!
 * @abstract Access to the stack item's selection state
 * @result Its selection state (always selected)
 */
- (NSNumber*) selectionState;

/*!
 * @abstract Access to the stack item's name
 * @result Its name
 */
- (NSString*) name;

/*!
 * @abstract Access to the stack item's index number
 * @result Its index number (nil)
 */
- (NSNumber*) index;
@end

static NSString * const K_STACK_NAME = @"name";

@implementation MyImageStackerPseudoItem
- (NSNumber*) selectionState { return( [NSNumber numberWithInt:NSOnState] ); }
- (NSString*)name { return( _name ); }
- (NSNumber*) index { return( nil ); }
- (id) init
{
   if ( (self = [super init]) != nil )
      _name = nil;

   return( self );
}
- (void) dealloc
{
   if ( _name != nil )
      [_name release];
   [super dealloc];
}
- (void)encodeWithCoder:(NSCoder *)encoder
{
   [encoder encodeObject:_name forKey:K_STACK_NAME];
}
- (id)initWithCoder:(NSCoder *)decoder
{
   if ( (self = [self init]) != nil )
      _name = [[decoder decodeObjectForKey:K_STACK_NAME] retain];
   return( self );
}
@end

@interface MyImageStackerView(Private)
- (void) highlightChange:(NSNotification*)notif ;
- (void) selectionRectChanged:(NSNotification*)notif ;
- (void) processStarted:(NSNotification*)notif ;
- (void) processEnded:(NSNotification*)notif ;
- (void) itemUsedInStack:(NSNotification*)notif ;
- (void) itemChanged:(NSNotification*)notif ;
- (void) listChanged:(NSNotification*)notif ;
- (void) dataModeChanged:(NSNotification*)notif ;
- (void) startSecondPass ;
@end

@implementation MyImageStackerView(Private)

- (void) highlightChange:(NSNotification*)notif
{
   if ( _isStacking && ! _imageUpdate )
      return;

   id <LynkeosProcessableItem> item = nil;
   DataMode_t dataMode = [_document dataMode];
   LynkeosIntegerRect selRect = LynkeosMakeIntegerRect(0,0,0,0);

   if ( dataMode == ListData )
   {
      item = [_window highlightedItem];

      if ( item != nil && [item getNSImage] != nil )
      {
         MyImageStackerParameters *params =
                 [item getProcessingParameterWithRef:myImageStackerParametersRef
                                       forProcessing:myImageStackerRef];
         if ( params != nil )
            selRect = params->_cropRectangle;
      }
   }
   else
      item = [_document currentList];

   // Display that new item
   [_imageView displayItem:item];

   // And update the selection rectangle
   if ( dataMode == ListData )
   {
      LynkeosIntegerRect curRect = [_imageView getSelection];
      ListMode_t mode = [_document listMode];

      if ( curRect.origin.x != selRect.origin.x ||
           curRect.origin.y != selRect.origin.y ||
           curRect.size.width != selRect.size.width ||
           curRect.size.height != selRect.size.height )
         [_imageView setSelection:selRect resizable:(mode == ImageMode)
                                            movable:(mode == ImageMode)];
   }
}

- (void) selectionRectChanged:(NSNotification*)notif
{
   NSAssert( [_document dataMode] == ListData,
             @"Crop rect changed in result display" );
   NSAssert( !_isStacking, @"Crop rect changed while stacking" );

   LynkeosIntegerRect r = [_imageView getSelection];
   id <LynkeosImageList> list = [_document currentList];
   MyImageStackerParameters *params =
      [list getProcessingParameterWithRef:myImageStackerParametersRef
                                 forProcessing:myImageStackerRef];
   NSAssert( params != nil, @"Update of non existent stacking parameters" );

   if ( [[NSUserDefaults standardUserDefaults] boolForKey:
                                                      K_PREF_ADJUST_FFT_SIZES] )
      // Adjust to the nearest size which is a factor of the primes
      // handled by FFTW3
      adjustFFTrect( &r );

   params->_cropRectangle = r;

   [list setProcessingParameter:params
                        withRef:myImageStackerParametersRef
                  forProcessing:myImageStackerRef];
}

- (void) processStarted:(NSNotification*)notif
{
   // We are only concerned by stacking process
   if ( [[notif userInfo] objectForKey:LynkeosUserInfoProcess]
        == [MyImageStacker class] )
   {
      // Change the button title
      [_stackButton setTitle:NSLocalizedString(@"Stop",@"Stop button")];
      [_stackButton setEnabled:YES];
      _isStacking = YES;
   }
}

- (void) processEnded:(NSNotification*)notif
{
   // We are only concerned by stacking process
   if ( _isStacking )
   {
      id <LynkeosImageList> list = [_document currentList];
      MyImageStackerParameters *params =
         [list getProcessingParameterWithRef:myImageStackerParametersRef
                               forProcessing:myImageStackerRef];
      NSAssert( params != nil, @"Process end without stacking parameters" );
      
      if ( params->_stackMethod == Stacking_Sigma_Reject
           && params->_method.sigma.pass == 1 )
      {
         // Launch pass 2 (schedule it)
         [[NSRunLoop currentRunLoop] performSelector:@selector(startSecondPass)
                                              target:self
                                            argument:nil
                                               order:0
                                               modes:
                                [NSArray arrayWithObject:NSDefaultRunLoopMode]];
      }
      else
      {
         // Change the button title
         [_stackButton setTitle:NSLocalizedString(@"Stack",@"Stack tool")];
         [_stackButton setEnabled:YES];

         _isStacking = NO;

         // Revert to the standard notifications
         NSNotificationCenter *notifCenter
            = [NSNotificationCenter defaultCenter];
         [notifCenter removeObserver:self
                                name: LynkeosItemWasProcessedNotification
                              object:_document];

         // If something was stacked
         if ( _stackedImagesNb != 0 )
         {
            id <LynkeosImageList> list = [_document currentList];
            ListMode_t mode = [_document listMode];

            // Give a name to the new image
            MyImageStackerPseudoItem *stackIdent =
                                        [[MyImageStackerPseudoItem alloc] init];
            NSString *modeString = nil;
            switch( mode )
            {
               case ImageMode: modeString= @"Image"; break;
               case DarkFrameMode: modeString= @"Dark frame"; break;
               case FlatFieldMode:modeString= @"Flat field"; break;
            }
            stackIdent->_name = [[NSString stringWithFormat:@"%@ stack",
                                                         modeString] retain];
            [list setProcessingParameter:stackIdent
                                 withRef:myImageListItemRef
                           forProcessing:myImageListItemRef];

            // If it is a calibration frame, update the image list
            if ( mode == FlatFieldMode || mode == DarkFrameMode )
            {
               NSString *ref = nil;

               switch( mode )
               {
                  case DarkFrameMode: ref = myImageListItemDarkFrame; break;
                  case FlatFieldMode: ref = myImageListItemFlatField; break;
               }
               [[_document imageList] setProcessingParameter:[list getImage]
                                                     withRef:ref
                                               forProcessing:nil];
            }

            // switch to result display
            [_document setDataMode:ResultData];
         }

         [notifCenter addObserver:self
                         selector:@selector(selectionRectChanged:)
                             name:
                              LynkeosImageViewSelectionRectDidChangeNotification
                           object:_imageView];
      }
   }
}

- (void) itemUsedInStack:(NSNotification*)notif
{
   NSAssert( _isStacking, @"Stacking notification outside stacking" );
   MyImageListItem *item = [[notif userInfo] objectForKey:LynkeosUserInfoItem];

   if ( item != nil )
   {
      [_window highlightItem:item];
      _stackedImagesNb++;
   }
}

- (void) itemChanged:(NSNotification*)notif
{
   id <LynkeosProcessable> item =
                            [[notif userInfo] objectForKey:LynkeosUserInfoItem];

   if ( !_isStacking && [_document dataMode] == ListData &&
        item == [_document currentList] )
      [self listChanged:nil];
}

- (void) listChanged:(NSNotification*)notif
{
   NSAssert( !_isStacking, @"List changed while stacking" );

   id <LynkeosImageList> list = [_document currentList];
   ListMode_t mode = [_document listMode];
   DataMode_t data = [_document dataMode];

   // Display parameters from the list
   MyImageStackerParameters *params =
                 [list getProcessingParameterWithRef:myImageStackerParametersRef
                                       forProcessing:myImageStackerRef];

   // Create the stacking parameters if needed
   if ( params == nil )
   {
      params = [[[MyImageStackerParameters alloc] init] autorelease];

      params->_cropRectangle = LynkeosMakeIntegerRect(0,0,0,0);
      if ( mode != ImageMode && [[list imageArray] count] != 0 )
         params->_cropRectangle.size =
              [(MyImageListItem*)[[list imageArray] objectAtIndex:0] imageSize];
      params->_factor = 1.0;
      params->_monochromeStack = NO;
      params->_stackMethod = Stacking_Standard;
      params->_stackLock = [[NSLock alloc] init];

      if ( mode == ImageMode || [[list imageArray] count] != 0 )
         [list setProcessingParameter:params
                              withRef:myImageStackerParametersRef
                        forProcessing:myImageStackerRef];
   }

   [_cropX setIntValue:params->_cropRectangle.origin.x];
   [_cropY setIntValue:params->_cropRectangle.origin.y];
   [_cropW setIntValue:params->_cropRectangle.size.width];
   [_cropH setIntValue:params->_cropRectangle.size.height];
   [_cropX setEnabled:(data == ListData && mode == ImageMode)];
   [_cropY setEnabled:(data == ListData && mode == ImageMode)];
   [_cropW setEnabled:(data == ListData && mode == ImageMode)];
   [_cropH setEnabled:(data == ListData && mode == ImageMode)];

   int state = (params->_factor == 1.0 ? NSOffState : NSOnState );
   if ( [_doubleSizeCheckBox state] != state )
      [_doubleSizeCheckBox setState:state];
   state = (params->_monochromeStack ? NSOnState : NSOffState );
   if ( [_monochromeCheckBox state] != state )
      [_monochromeCheckBox setState:state];
   [_doubleSizeCheckBox setEnabled:(data == ListData && mode == ImageMode)];
   [_monochromeCheckBox setEnabled:(data == ListData && mode == FlatFieldMode)];

   [_methodPopup selectItemWithTag:params->_stackMethod];
   [_methodPopup setEnabled:(data == ListData && mode == ImageMode)];
   [_methodPane selectTabViewItemAtIndex:params->_stackMethod];
   switch ( params->_stackMethod )
   {
      case Stacking_Standard:
         break;
      case Stacking_Sigma_Reject:
         [_sigmaRejectText setFloatValue:params->_method.sigma.threshold];
         [_sigmaRejectSlider setFloatValue:params->_method.sigma.threshold];
         break;
      case Stacking_Extremum:
         [_minMaxMatrix selectCellAtRow:
                                    (params->_method.extremum.maxValue ? 0 : 1)
                                 column:0];
         break;
      default:
         NSAssert( NO, @"Invalid stacking method" );
   }

   [_stackButton setEnabled:(data == ListData
                             && params->_cropRectangle.size.width != 0
                             && params->_cropRectangle.size.height != 0)];

   [self highlightChange:nil];
}

- (void) dataModeChanged:(NSNotification*)notif
{
   if ( [_document dataMode] == ListData )
      [self listChanged:notif];

   else
   {
      [_imageView setSelection:LynkeosMakeIntegerRect(0,0,0,0)
                     resizable:NO movable:NO];

      [_cropX setEnabled:NO];
      [_cropY setEnabled:NO];
      [_cropW setEnabled:NO];
      [_cropH setEnabled:NO];
      [_doubleSizeCheckBox setEnabled:NO];
      [_monochromeCheckBox setEnabled:NO];
      [_methodPopup setEnabled:NO];
      [_methodPane selectTabViewItemAtIndex:0];
      [_stackButton setEnabled:NO];
   }
}

- (void) startSecondPass
{
   id <LynkeosImageList> list = [_document currentList];
   MyImageStackerParameters *params =
      [list getProcessingParameterWithRef:myImageStackerParametersRef
                            forProcessing:myImageStackerRef];
   NSAssert( params != nil, @"Pass2 start without stacking parameters" );

   params->_imagesStacked = 0;
   params->_livingThreads = 0;
   params->_method.sigma.pass = 2;

   MyImageStackerList *docParam = [[[MyImageStackerList alloc] init]
                                   autorelease];
   docParam->_list = list;

   NSEnumerator *strider = [list imageEnumeratorStartAt:nil
                                            directSense:YES
                                         skipUnselected:YES];

   [_document startProcess:[MyImageStacker class] withEnumerator:strider
                parameters:docParam];
}
@end

@implementation MyImageStackerView

+ (BOOL) isStandardProcessingViewController { return(YES); }

+ (ProcessingViewKind_t) processingViewKindForConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"Image stacker does not support configuration" );
   return(ListProcessingKind);
}

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
   NSAssert( config == nil, @"Image stacker does not support configuration" );
   *title = NSLocalizedString(@"StackMenu",@"Stack menu");
   *toolTitle = NSLocalizedString(@"StackTool",@"Stack tool");
   *key = @"s";
   *icon = [NSImage imageNamed:@"Photolist"];
   *tip = NSLocalizedString(@"StackTip",@"Stack tooltip");;
}

+ (unsigned int) authorizedModesForConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"Image stacker does not support configuration" );
   return(ImageMode|DarkFrameMode|FlatFieldMode|ListData|ResultData);
}

+ (unsigned int) allowedDisplaysForConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"Image stacker does not support configuration" );
   return( BottomTab|BottomTab_NoList|SeparateView|SeparateView_NoList );
}

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _document = nil;
      _textView = nil;
      _imageView = nil;
      _isStacking = NO;

      [NSBundle loadNibNamed:@"MyImageStacker" owner:self];
   }

   return( self );
}

- (id) initWithWindowController: (id <LynkeosWindowController>)window
                       document: (id <LynkeosViewDocument>)document
                  configuration: (id <NSObject>)config
{
   NSAssert( config == nil, @"Image stacker does not support configuration" );

   if ( (self = [self init]) != nil )
   {
      _window = window;
      _textView = [_window getTextView];
      _imageView = [_window getImageView];

      NSAssert( [document isKindOfClass:[MyDocument class]],
                @"Wrong document class for stacker view");
      _document = (MyDocument*)document;
   }

   return( self );
}

- (NSView*) getProcessingView
{
   return( _panel );
}

- (Class) processingClass
{
   return( nil );
}

- (void) setActiveView:(BOOL)active
{
   NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];

   if ( active )
   {
      // Authorize some selections
      [_window setListSelectionAuthorization:YES];
      [_window setDataModeSelectionAuthorization:YES];
      [_window setItemSelectionAuthorization:YES];
      [_window setItemEditionAuthorization:YES];

      // Register for notifications
      [notifCenter addObserver:self
                     selector:@selector(highlightChange:)
                         name: NSOutlineViewSelectionDidChangeNotification
                       object:_textView];
      [notifCenter addObserver:self
                      selector:@selector(selectionRectChanged:)
                          name:LynkeosImageViewSelectionRectDidChangeNotification
                        object:_imageView];
      [notifCenter addObserver:self
                      selector:@selector(processStarted:)
                          name: LynkeosProcessStartedNotification
                        object:_document];
      [notifCenter addObserver:self
                      selector:@selector(processEnded:)
                          name: LynkeosProcessEndedNotification
                        object:_document];
      [notifCenter addObserver:self
                      selector:@selector(highlightChange:)
                          name: LynkeosProcessStackEndedNotification
                        object:_document];
      [notifCenter addObserver:self
                      selector:@selector(itemChanged:)
                          name: LynkeosItemChangedNotification
                        object:_document];
      [notifCenter addObserver:self
                      selector:@selector(listChanged:)
                          name: LynkeosListChangeNotification
                        object:_document];
      [notifCenter addObserver:self
                      selector:@selector(dataModeChanged:)
                          name: LynkeosDataModeChangeNotification
                        object:_document];

      // Synchronize the display
      [self dataModeChanged:nil];
      if ( [_document dataMode] == ListData )
         [self listChanged:nil];
      [self highlightChange:nil];

      _isStacking = NO;
   }
   else
   {
      [_window setListSelectionAuthorization:YES];

      // Stop receiving notifications
      [notifCenter removeObserver:self];
   }
}

- (LynkeosProcessingViewFrame_t) preferredDisplay { return( BottomTab ); }

- (id <LynkeosProcessingParameter>) getCurrentParameters
{
   // This is a list processing, the parameters are spread on the list
   return( nil );
}

- (IBAction) cropRectangleChange :(id)sender
{
   id <LynkeosImageList> list = [_document currentList];
   MyImageStackerParameters *params =
                 [list getProcessingParameterWithRef:myImageStackerParametersRef
                                       forProcessing:myImageStackerRef];

   params->_cropRectangle.origin.x = [_cropX doubleValue];
   params->_cropRectangle.origin.y = [_cropY doubleValue];
   params->_cropRectangle.size.width = [_cropW doubleValue];
   params->_cropRectangle.size.height = [_cropH doubleValue];

   if ( [[NSUserDefaults standardUserDefaults] boolForKey:
                                                      K_PREF_ADJUST_FFT_SIZES] )
      // Adjust to the nearest size which is a factor of the primes
      // handled by FFTW3
      adjustFFTrect( &params->_cropRectangle );   

   [list setProcessingParameter:params
                        withRef:myImageStackerParametersRef
                  forProcessing:myImageStackerRef];
}

- (IBAction) doubleSizeAction :(id)sender
{
   NSAssert1( [_document listMode] == ImageMode,
              @"Double size selected in mode %d", [_document listMode] );

   id <LynkeosImageList> list = [_document currentList];
   MyImageStackerParameters *params =
      [list getProcessingParameterWithRef:myImageStackerParametersRef
                            forProcessing:myImageStackerRef];

   params->_factor = ([_doubleSizeCheckBox state] == NSOnState ? 2.0 : 1.0 );

   [list setProcessingParameter:params
                        withRef:myImageStackerParametersRef
                  forProcessing:myImageStackerRef];
}

- (IBAction) monochromeAction :(id)sender
{
   NSAssert1( [_document listMode] == FlatFieldMode,
              @"Monochrome stack selected in mode %d", [_document listMode] );
   id <LynkeosImageList> list = [_document currentList];
   MyImageStackerParameters *params =
      [list getProcessingParameterWithRef:myImageStackerParametersRef
                            forProcessing:myImageStackerRef];

   params->_monochromeStack = ([_monochromeCheckBox state] == NSOnState);

   [list setProcessingParameter:params
                        withRef:myImageStackerParametersRef
                  forProcessing:myImageStackerRef];
}

- (IBAction) methodChange:(id)sender
{
   id <LynkeosImageList> list = [_document currentList];
   MyImageStackerParameters *params =
      [list getProcessingParameterWithRef:myImageStackerParametersRef
                            forProcessing:myImageStackerRef];

   params->_stackMethod = [sender selectedTag];

   switch ( params->_stackMethod )
   {
      case Stacking_Standard :
         break;
      case Stacking_Sigma_Reject:
         params->_method.sigma.threshold = 0.0;
         break;
      case Stacking_Extremum:
         params->_method.extremum.maxValue = YES;
         break;
      default:
         NSAssert( NO, @"Invalid stacking method" );
   }

   [list setProcessingParameter:params
                        withRef:myImageStackerParametersRef
                  forProcessing:myImageStackerRef];
}

- (IBAction) sigmaChange:(id)sender
{
   // Reconcile slider and text
   double v = [sender doubleValue];

   if ( sender != _sigmaRejectSlider )
      [_sigmaRejectSlider setDoubleValue:v];
   if ( sender != _sigmaRejectText )
      [_sigmaRejectText setDoubleValue:v];

   id <LynkeosImageList> list = [_document currentList];
   MyImageStackerParameters *params =
      [list getProcessingParameterWithRef:myImageStackerParametersRef
                            forProcessing:myImageStackerRef];
   params->_method.sigma.threshold = v;
   [list setProcessingParameter:params
                        withRef:myImageStackerParametersRef
                  forProcessing:myImageStackerRef];
}

- (IBAction) minMaxChange:(id)sender
{
   id <LynkeosImageList> list = [_document currentList];
   MyImageStackerParameters *params =
      [list getProcessingParameterWithRef:myImageStackerParametersRef
                            forProcessing:myImageStackerRef];
   params->_method.extremum.maxValue = ([sender selectedRow] == 1);
   [list setProcessingParameter:params
                        withRef:myImageStackerParametersRef
                  forProcessing:myImageStackerRef];
}

- (IBAction) stackAction :(id)sender
{
   NSAssert( [_document dataMode] == ListData,
             @"Stacking started in result mode" );
   id <LynkeosImageList> list = [_document currentList];
   MyImageStackerParameters *params=
                 [list getProcessingParameterWithRef:myImageStackerParametersRef
                                       forProcessing:myImageStackerRef];
   ListMode_t mode = [_document listMode];

   [sender setEnabled:NO];

   if ( _isStacking )
      [_document stopProcess];

   else
   {
      // Check for possibly missing calibration frame
      id <LynkeosImageList> dark = [_document darkFrameList],
                            flat = [_document flatFieldList];
      if ( mode == ImageMode &&
           ( ( [[dark imageArray] count] != 0 
               && [list getProcessingParameterWithRef:myImageListItemDarkFrame
                                        forProcessing:nil] == nil )
             ||
             ( [[flat imageArray] count] != 0 
               && [list getProcessingParameterWithRef:myImageListItemFlatField
                                        forProcessing:nil] == nil ) ) )
      {
         if ( NSAlertDefaultReturn !=
              NSRunAlertPanel(NSLocalizedString(@"CalibrationNotReadyTitle",
                                                @"Stack alert title"),
                              NSLocalizedString(@"CalibrationNotReadyText",
                                                @"Stack alert text"),
                              NSLocalizedString(@"Continue",
                                                @"Continue button"),
                              NSLocalizedString(@"Stop",
                                                @"Stop button"),
                              nil ) )
         {
            // User canceled the stacking
            [sender setEnabled:YES];
            return;
         }
      }

      // Disable all controls
      [_cropX setEnabled:NO];
      [_cropY setEnabled:NO];
      [_cropW setEnabled:NO];
      [_cropH setEnabled:NO];
      [_doubleSizeCheckBox setEnabled:NO];
      [_monochromeCheckBox setEnabled:NO];

      // Freeze the selection rectangle
      LynkeosIntegerRect r = [_imageView getSelection];
      [_imageView setSelection:r resizable:NO movable:NO];

      // Stop receiving some notifications
      NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
      [notifCenter removeObserver:self
                              name:LynkeosImageViewSelectionRectDidChangeNotification
                                                    object:_imageView];
      // And register for some others
      [notifCenter addObserver:self
                      selector:@selector(itemUsedInStack:)
                          name: LynkeosItemWasProcessedNotification
                        object:_document];

      // Initialize the stacking parameters
      switch( mode )
      {
         case ImageMode:
         case DarkFrameMode:
            switch(params->_stackMethod)
            {
               case Stacking_Standard:
                  params->_postStack = MeanStack;
                  break;
               case Stacking_Sigma_Reject:
                  params->_postStack = NoPostStack;
                  params->_method.sigma.pass = 1;
                  break;
               case Stacking_Extremum:
                  params->_postStack = NoPostStack;
                  break;
               default:
                  NSAssert( NO, @"Invalid stacking method" );
            }
            break;
         case FlatFieldMode:
            params->_postStack = NormalizeStack;
            break;
         default:
            NSAssert1( NO, @"Invalid list mode %d", [_document listMode] );
      }
      params->_imagesStacked = 0;
      params->_livingThreads = 0;

      _imageUpdate = [[NSUserDefaults standardUserDefaults] boolForKey:
                                                   K_PREF_STACK_IMAGE_UPDATING];

      // Temporary parameter to signal the list
      MyImageStackerList *docParam = [[[MyImageStackerList alloc] init]
                                                                   autorelease];
      docParam->_list = list;

      // Get an enumerator on the images
      NSEnumerator *strider = [list imageEnumeratorStartAt:nil
                                                directSense:YES
                                             skipUnselected:YES];

      // Ask the doc to stack
      [_document startProcess:[MyImageStacker class] withEnumerator:strider
                   parameters:docParam];
   }
}
@end
