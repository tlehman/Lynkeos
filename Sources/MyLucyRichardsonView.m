//
//  Lynkeos
//  $Id: MyLucyRichardsonView.m 506 2011-03-26 18:40:46Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sat Nov 3 2007.
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

#include "MyDocument.h"
#include "LynkeosStandardImageBufferAdditions.h"
#include "MyLucyRichardsonView.h"

NSString * const K_PSF_KIND_KEY = @"psf kind";
NSString * const K_RADIUS_KEY = @"radius";
NSString * const K_SEL_RECTANGLE_KEY = @"selection";
NSString * const K_PSF_URL_KEY = @"psf url";

/*!
 * @abstract Update the PSF to any change
 * @discussion In image mode, the _psf field in params contains the read image
 *    (unswapped).
 * @param params The Lucy Richardson parameters
 * @param item The item which will be processed
 */
static void updatePSF( MyLucyRichardsonViewParameters *params,
                       id <LynkeosProcessableItem> item )
{
   if( item == nil || params == nil )
   {
      NSLog(@"Unexpected PSF update without item to process" );
      return;
   }

   LynkeosStandardImageBuffer *buf = nil;
   LynkeosIntegerSize s = [item imageSize];
   LynkeosIntegerRect sel;

   if ( params->_psfKind == ImageFilePSF )
      buf = params->_psf;

   else
   {
      // Get rid of the previous PSF
      if ( params->_psf != nil )
         [params->_psf release];
   }
   params->_psf = [[LynkeosFourierBuffer alloc] initWithNumberOfPlanes:1
                                                            width:s.width
                                                           height:s.height
                                                         withGoal:FOR_DIRECT];

   switch( params->_psfKind )
   {
      case GaussianPSF:
         MakeGaussian([params->_psf colorPlanes], s.width, s.height,
                      1, params->_psf->_padw,
                      params->_gaussianRadius );
         break;
      case SelectionPSF:
         // Retrieve the PSF sample, if any
         sel = params->_selection;
         if ( sel.size.width > 0 && sel.size.height > 0 )
         {
            sel.origin.y = s.height - sel.origin.y - sel.size.height;
            [item getImageSample:&buf inRect:sel];
         }
         break;
      case ImageFilePSF:
         break;
      default:
         NSLog( @"Invalid kind of PSF" );
         break;
   }

   if ( buf != nil )
   {
      // Calculate the barycenter of the sample
      // and the mean value of the sample perimeter
      int c, x, y, mx, my;
      double sx, sy, mpv, nb;
      u_long npv;
      double vmin, vmax, threshold;
      sx = 0.0; sy = 0.0; nb = 0.0;
      [buf getMinLevel:&vmin maxLevel:&vmax];
      threshold = (vmax-vmin)*0.707;
      mpv = 0.0; npv = 0;
      for( c = 0; c < buf->_nPlanes; c++ )
      {
         for( y = 0; y < buf->_h; y++ )
         {
            for( x = 0; x < buf->_w; x++ )
            {
               REAL v = colorValue(buf,x,y,c);
               if ( (v-vmin) >= threshold )
               {
                  sx += (double)x*(v-vmin);
                  sy += (double)y*(v-vmin);
                  nb += v;
               }
               if ( x == 0 || y == 0
                    || x == buf->_w -1 || y == buf->_h -1 )
               {
                  mpv += v;
                  npv++;
               }
            }
         }
      }
      mx = (u_short)(sx/nb + 0.5);
      my = (u_short)(sy/nb + 0.5);
      mpv /= (double)npv;

      // Build the new PSF (transpose the quadrants around the barycenter)
      for( y = 0; y < s.height; y++ )
      {
         int yp;
         if ( y < (s.height+1)/2 && y < buf->_h - my )
            yp = y + my;
         else if ( y >= (s.height+1)/2 && y >= s.height - my )
            yp = y - s.height + my;
         else
            yp = -1;

         for( x = 0; x < s.width; x++ )
         {
            REAL v = 0;
            int xp;

            if ( x < (s.width+1)/2 && x < (buf->_w - mx) )
               xp = x + mx;
            else if ( x >= (s.width+1)/2 && x >= s.width - mx )
               xp = x - s.width + mx;
            else
               xp = -1;

            if ( xp >= 0 && yp >= 0 )
            {
               for( c = 0; c < buf->_nPlanes; c++ )
                  v += colorValue(buf,xp,yp,c) - mpv;
               v /= (REAL)buf->_nPlanes;
               if ( v < 0.0 )
                  v = 0.0;
            }
            else
               v = 0.0;
            colorValue(params->_psf,x,y,0) = v;
         }
      }
   }
}

/*!
 * @abstract Swap quadrants of the PSF
 * @discussion The swap is not symmetrical for odd sizes, hence the choice
 *    between back and forth swap.
 * @param psf The PSF to swap
 * @param back Whether to swap from the original image or back to it
 */
static void swapPsf( LynkeosStandardImageBuffer *psf, BOOL back )
{
   const u_short w = psf->_w, h = psf->_h;
   REAL *buf;
   u_short x, y, c;

   buf = (REAL*)malloc( (w > h ? w : h)*sizeof(REAL) );

   for( c = 0; c < psf->_nPlanes; c++ )
   {
      // Swap lines
      for( y = 0 ; y < h; y++ )
      {
         for( x = 0 ; x < w; x++ )
         {
            if ( back )
            {
               if ( x < w/2 )
                  buf[x+(w+1)/2] = colorValue(psf,x,y,c);
               else
                  buf[x-w/2] = colorValue(psf,x,y,c);
            }
            else
            {
               if ( x < (w+1)/2 )
                  buf[x+w/2] = colorValue(psf,x,y,c);
               else
                  buf[x-(w+1)/2] = colorValue(psf,x,y,c);
            }
         }
         for( x = 0; x < w; x++ )
            colorValue(psf,x,y,c) = buf[x];
      }

      // Swap colums
      for( x = 0 ; x < w; x++ )
      {
         for( y = 0 ; y < h; y++ )
         {
            if ( back )
            {
               if ( y < h/2 )
                  buf[y+(h+1)/2] = colorValue(psf,x,y,c);
               else
                  buf[y-h/2] = colorValue(psf,x,y,c);
            }
            else
            {
               if ( y < (h+1)/2 )
                  buf[y+h/2] = colorValue(psf,x,y,c);
               else
                  buf[y-(h+1)/2] = colorValue(psf,x,y,c);
            }
         }
         for( y = 0; y < h; y++ )
            colorValue(psf,x,y,c) = buf[y];
      }
   }

   free( buf );
}

NSMutableDictionary *monitorDictionary = nil;

/*!
 * @abstract Lightweight object for monitoring image size change
 * @discussion When the image size change, the LucyRichardson parameters need to
 *    be adjusted (even if the view was not opened).
 * @ingroup Processing
 */
@interface MyLucyRichardsonMonitor : NSObject
{
   NSObject <LynkeosViewDocument>      *_document;  //!< Our document
   LynkeosIntegerSize                   _imageSize; //!< PSF image size
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
 * @result Initialized monitor object
 */
- (id) initWithDocument:(NSObject <LynkeosViewDocument>*)document;
/*!
 * @abstract Process a change in the document (only PSF change is of interest)
 * @param notif The notification
 */
- (void) documentChange:(NSNotification*)notif;
@end

@implementation MyLucyRichardsonMonitor
+ (void) documentDidOpen:(NSNotification*)notif
{
   MyDocument *document = [notif object];

   // Create a monitor object for this document
   [monitorDictionary setObject:
       [[[MyLucyRichardsonMonitor alloc] initWithDocument:document] autorelease]
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
{
   if ( (self = [self init]) != nil )
   {
      _document = document;

      _imageSize = [[document imageList] imageSize];

      NSNotificationCenter *notif = [NSNotificationCenter defaultCenter];

      // Register for item change notifications
      [notif addObserver:self
                selector:@selector(documentChange:)
                    name: LynkeosItemChangedNotification
                  object:_document];
   }

   return( self );
}

- (void) dealloc
{
   // Unregister for all notifications
   [[NSNotificationCenter defaultCenter] removeObserver:self];

   [super dealloc];
}

- (void) documentChange:(NSNotification*)notif
{
   // Check if the image size has changed
   MyImageList *item = [[notif userInfo] objectForKey:LynkeosUserInfoItem];
   if ( item == [_document imageList] )
   {
      LynkeosIntegerSize newSize = [item imageSize];
      if ( newSize.width != _imageSize.width
          || newSize.height != _imageSize.height )
      {
         // Update the Lucy Richardson parameters, if any
         NSArray *stack = (NSArray*)[item getProcessingParameterWithRef:
                                                             K_PROCESS_STACK_REF
                                                          forProcessing:nil
                                                                   goUp:NO];
         if ( stack != nil )
         {
            NSEnumerator *processings = [stack objectEnumerator];
            id processing;
            while( (processing = [processings nextObject]) != nil )
            {
               if ( [processing isKindOfClass:
                                       [MyLucyRichardsonViewParameters class]] )
               {
                  MyLucyRichardsonViewParameters *param = processing;
                  if ( param->_psfKind == ImageFilePSF )
                     // Re-swap quadrants before adjusting the PSF
                     swapPsf( param->_psf, YES );
                  updatePSF(param, item);
               }
            }
         }
         _imageSize = newSize;
      }
   }
}
@end

@interface MyLucyRichardsonView(Private)
- (void) validateControls ;
- (void) zoomChange:(NSNotification*)notif ;
- (void) itemChange:(NSNotification*)notif ;
- (void) processStarted:(NSNotification*)notif ;
- (void) processEnded:(NSNotification*)notif ;
- (void) selectionRectChange:(NSNotification*)notif ;
- (void) displayPSF ;
@end

@implementation MyLucyRichardsonViewParameters
- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _psfKind = GaussianPSF;
      _gaussianRadius = 2.5;
      _selection = LynkeosMakeIntegerRect(0,0,0,0);
      _psfURL = nil;
   }

   return( self );
}

- (void) dealloc
{
   if ( _psfURL != nil )
      [_psfURL release];
   [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [super encodeWithCoder:encoder];
   [encoder encodeInt:_psfKind forKey:K_PSF_KIND_KEY];
   [encoder encodeDouble:_gaussianRadius forKey:K_RADIUS_KEY];
   [encoder encodeRect:NSRectFromIntegerRect(_selection)
                forKey:K_SEL_RECTANGLE_KEY];
   [encoder encodeObject:_psfURL forKey:K_PSF_URL_KEY];
}

- (id) initWithCoder:(NSCoder *)decoder
{
   if ( (self = [super initWithCoder:decoder]) != nil )
   {
      _psfKind = [decoder decodeIntForKey:K_PSF_KIND_KEY];
      _gaussianRadius = [decoder decodeDoubleForKey:K_RADIUS_KEY];
      _selection = LynkeosIntegerRectFromNSRect(
                                [decoder decodeRectForKey:K_SEL_RECTANGLE_KEY]);
      _psfURL = [[decoder decodeObjectForKey:K_PSF_URL_KEY] retain];
   }

   return( self );
}
@end

@implementation MyLucyRichardsonView(Private)
- (void) validateControls
{
   int kind = [_psfPopup indexOfSelectedItem];

   [_iterationText setEnabled:(_item != nil && !_isProcessing)];
   [_iterationStepper setEnabled:(_item != nil && !_isProcessing)];
   [_psfPopup setEnabled:(_item != nil && !_isProcessing)];
   [_radiusText setEnabled:(_item != nil && !_isProcessing)];
   [_radiusSlider setEnabled:(_item != nil && !_isProcessing)];
   [_gaussBox setHidden:(kind != GaussianPSF)];
   [_fileBox setHidden:(kind != ImageFilePSF)];
   [_saveButton setEnabled:(_item != nil && _params->_psf != nil
                            && !_isProcessing)];
   [_loadButton setEnabled:(_item != nil && !_isProcessing)];
   if ( kind == SelectionPSF )
      [_imageView setSelection:_params->_selection
                     resizable:!_isProcessing movable:!_isProcessing];
   else
      [_imageView setSelection:LynkeosMakeIntegerRect(0,0,0,0)
                     resizable:NO movable:NO];
   [_startButton setEnabled:(_item != nil && _params->_numberOfIteration != 0
                             && _params->_psf != nil && !_isProcessing)];
}

- (void) zoomChange:(NSNotification*)notif
{
   [self displayPSF];
}

- (void) itemChange:(NSNotification*)notif
{
   // Update item and parameters
   if ( _params != nil )
   {
      _params->_delegate = nil;
      [_params release];
   }
   [_window getItemToProcess:&_item andParameter:&_params forView:self];

   if ( _item != nil )
   {
      if ( _params == nil )
         // Create some new parameters
         _params = [[MyLucyRichardsonViewParameters alloc] init];
      else
         [_params retain];
      _params->_delegate = self;

      [_iterationText setIntValue:_params->_numberOfIteration];
      [_iterationStepper setIntValue:_params->_numberOfIteration];
      [_psfPopup selectItemAtIndex:_params->_psfKind];
      [_logRadius setDoubleValue:_params->_gaussianRadius];

      if ( _params->_psf == nil )
         updatePSF( _params, _item );
   }
   else
   {
      [_iterationText setStringValue:@""];
      [_psfPopup selectItemAtIndex:-1];
      [_radiusText setStringValue:@""];
   }

   // Display the image and PSF
   [_imageView displayItem:_item];
   [self displayPSF];
   [self validateControls];
}

- (void) processStarted:(NSNotification*)notif
{
   _isProcessing = YES;
   _currentIteration = 0;

   // Disable the controls
   [self validateControls];
}

- (void) processEnded:(NSNotification*)notif
{
   _isProcessing = NO;

   [_counterText setStringValue:@""];

   // Redisplay the image
   [_imageView displayItem:_item];
   // Reenable the controls
   [self validateControls];
}

- (void) selectionRectChange:(NSNotification*)notif
{
   NSAssert( _params->_psfKind == SelectionPSF, @"Unexpected selection" );
   _params->_selection = [_imageView getSelection];
   updatePSF( _params, _item);
   [self displayPSF];
}

- (void) displayPSF
{
   NSImage *image = nil;

   if ( _params !=nil && _params->_psf != nil )
   {
      double zoom = [_realImageView getZoom];
      NSSize s = [_psfImage frame].size;
      const int w = (int)s.width/zoom, h = (int)s.height/zoom;

      // Create a NSImage for the image view
      image = [[[NSImage alloc] initWithSize:s] autorelease];

      // Create a bitmap from the PSF center
      NSBitmapImageRep *bmap =
         [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                  pixelsWide:w
                                                  pixelsHigh:h
                                               bitsPerSample:8
                                             samplesPerPixel:
                                                         _params->_psf->_nPlanes
                                                    hasAlpha:NO
                                                    isPlanar:YES
                                              colorSpaceName:
                                                (_params->_psf->_nPlanes == 1 ?
                                                 NSCalibratedWhiteColorSpace :
                                                 NSCalibratedRGBColorSpace)
                                                 bytesPerRow:w
                                                bitsPerPixel:8] autorelease];
      double vmin, vmax, scale;
      u_short c, x, y;
      unsigned char *planes[5];

      [_params->_psf getMinLevel:&vmin maxLevel:&vmax];
      scale = 255.9/(vmax-vmin);

      [bmap getBitmapDataPlanes:planes];
      for( c = 0; c < _params->_psf->_nPlanes; c++ )
      {
         for( y = 0; y < h; y++ )
         {
            unsigned short yp;

            if ( y < h/2 )
               yp = _params->_psf->_h - h/2 + y;
            else
               yp = y - h/2;

            for( x = 0; x < w; x++ )
            {
               unsigned short xp;

               if ( x < w/2 )
                  xp = _params->_psf->_w - w/2 + x;
               else
                  xp = x - w/2;

               planes[c][y*w+x] = (int)(scale*(colorValue(_params->_psf,xp,yp,c)
                                               - vmin));
            }
         }
      }

      [image addRepresentation:bmap];
   }

   // Set the image in the view
   [_psfImage setImage:image];
}
@end

@implementation MyLucyRichardsonView
+ (void) initialize
{
   // Register the monitor class for document notifications
   NSNotificationCenter *notif = [NSNotificationCenter defaultCenter];

   monitorDictionary = [[NSMutableDictionary alloc] initWithCapacity:1];

   [notif addObserver:[MyLucyRichardsonMonitor class]
             selector:@selector(documentDidOpen:)
                 name:LynkeosDocumentDidOpenNotification
               object:nil];
   [notif addObserver:[MyLucyRichardsonMonitor class]
             selector:@selector(documentWillClose:)
                 name:LynkeosDocumentWillCloseNotification
               object:nil];
}

+ (BOOL) isStandardProcessingViewController { return(YES); }

+ (ProcessingViewKind_t) processingViewKindForConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"Lucy/Richardson does not support configuration" );
   return(ImageProcessingKind);
}

+ (BOOL) isViewControllingProcess:(Class)processingClass
                       withConfig:(id <NSObject>*)config
{
   *config = nil;
   return( processingClass == [MyLucyRichardson class] );
}

+ (void) getProcessingTitle:(NSString**)title
                  toolTitle:(NSString**)toolTitle
                        key:(NSString**)key
                       icon:(NSImage**)icon
                        tip:(NSString**)tip
                  forConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"Lucy/Richardson does not support configuration" );
   *title = NSLocalizedString(@"LucyRichardson",@"Lucy/Richardson menu");
   *toolTitle = NSLocalizedString(@"LucyRichardsonTool",
                                  @"Lucy/Richardson tool");
   *key = @"r";
   *icon = [NSImage imageNamed:@"LucyRichardson"];
   *tip = NSLocalizedString(@"LucyRichardsonTip",@"Lucy/Richardson tooltip");;
}

+ (unsigned int) allowedDisplaysForConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"Lucy/Richardson does not support configuration" );
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

      [NSBundle loadNibNamed:@"MyLucyRichardson" owner:self];
   }

   return( self );
}

- (void) dealloc
{
   if ( _params != nil )
   {
      _params->_delegate = nil;
      [_params release];
      [_logRadius release];
   }
   [super dealloc];
}

- (id) initWithWindowController: (id <LynkeosWindowController>)window
                       document: (id <LynkeosViewDocument>)document
                  configuration: (id <NSObject>)config
{
   NSAssert( config == nil, @"Lucy/Richardson does not support configuration" );

   if ( (self = [self init]) != nil )
   {
      _document = document;
      _window = window;
      _imageView = [_window getImageView];
      _realImageView = [_window getRealImageView];
      _textView = [_window getTextView];
      _logRadius = [[LynkeosLogFields alloc] initWithSlider:_radiusSlider
                                          andTextField:_radiusText];

   }

   return( self );
}

- (NSView*) getProcessingView { return( _panel ); }

- (void) setActiveView:(BOOL)active
{
   NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];

   if ( active )
   {
      // Authorize (or not) some selections
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
      [notifCenter addObserver:self
                      selector:@selector(selectionRectChange:)
                          name:LynkeosImageViewSelectionRectDidChangeNotification
                        object:_imageView];
      [notifCenter addObserver:self
                      selector:@selector(zoomChange:)
                          name:LynkeosImageViewZoomDidChangeNotification
                        object:_imageView];

      // Synchronize the display
      [self itemChange:nil];
   }
   else
   {
      // Release the parameters
      if ( _params != nil )
      {
         _params->_delegate = nil;
         [_params release];
         _params = nil;
      }

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
   return( [MyLucyRichardson class] );
}

- (oneway void) iterationEnded
{
   if ( [_progressButton state] == NSOnState )
      [_imageView displayItem:_item];
   _currentIteration++;
   [_counterText setIntValue:_currentIteration];
}

- (IBAction) iterationAction:(id)sender
{
   _params->_numberOfIteration = [sender intValue];

   // Reconcile controls
   if ( sender == _iterationStepper )
      [_iterationText setIntValue:_params->_numberOfIteration];
   else if ( sender == _iterationText )
      [_iterationStepper setIntValue:_params->_numberOfIteration];

   [self validateControls];
}

- (IBAction) psfTypeAction:(id)sender
{
   u_int newKind = [sender indexOfSelectedItem];

   if ( newKind != _params->_psfKind )
   {
      _params->_psfKind = newKind;

      if ( newKind != ImageFilePSF )
      {
         updatePSF( _params, _item);
         [self displayPSF];
      }
   }

   [self validateControls];
}

- (IBAction) radiusAction:(id)sender
{
   _params->_gaussianRadius = [_logRadius valueFrom:sender];

   updatePSF( _params, _item);
   [self displayPSF];
}

- (IBAction) loadAction:(id)sender
{
   _params->_psf = [_window loadImage];
   updatePSF( _params, _item);
   [self displayPSF];
}

- (IBAction) saveAction:(id)sender
{
   double b[2], w[2], g[2] = {1.0,1.0};

   LynkeosStandardImageBuffer *buf = [[_params->_psf copy] autorelease];
   // Transpose the quadrants for saving (0,0 at center)
   swapPsf(buf,YES);
   // And save
   [_params->_psf getMinLevel:&b[0] maxLevel:&w[0]];
   b[1] = b[0];
   w[1] = w[0];
   [_window saveImage:buf withBlack:b white:w gamma:g];
}

- (IBAction) startProcess:(id)sender
{
   _currentIteration = 0;
   [_counterText setIntValue:0];
   if ( [_progressButton state] == NSOnState )
   {
      [_item revertToOriginal];
      [_imageView displayItem:_item];
   }
   [_document startProcess:[MyLucyRichardson class]
                   forItem:_item parameters:_params];
}
@end
