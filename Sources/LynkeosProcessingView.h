//
//  Lynkeos
//  $Id: LynkeosProcessingView.h 506 2011-03-26 18:40:46Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun Nov 5 2006.
//  Copyright (c) 2006-2011. Jean-Etienne LAMIAUD
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

// Special comments for Doxygen

/*!
 \if LynkeosCore
 \mainpage
 This framework allows development of external plugins for Lynkeos.
 \else
 \page plugins Lynkeos plugins
 \endif
 Lynkeos recognizes several kind of plugins :
 - File access plugins, reader and/or writer.
 - Processing plugins ; list, image or other kind of processing.
 .
 All plugins can contain preference panes which will display in the Lynkeos
 preferences window.<br>
 The plugins are loaded at application startup
 \section filePlugin File access plugin
 A file reader plugin shall contain one class (or more) implementing the
 LynkeosImageFileReader or LynkeosMovieFileReader protocol.
 A file writer plugin shall contain one class (or more) implementing the
 LynkeosImageFileWriter or LynkeosMovieFileWriter protocol.<br>
 See the \ref fileAccess "file access" documentation for more information.
 \section processingPlugin Processing plugin
 A processing plugin shall contain a class implementing the LynkeosProcessingView
 protocol, to provide the graphical interface ; it probably should contain a
 class implementing the LynkeosProcessing protocol, to perform the processing.<br>
 See the \ref processingArch "processing architecture" documentation for more
 information.
 \section preferencePlugin Preferences in a plugin
 Any plugin can contain a class implementing the LynkeosPreferences protocol
 to provide a preferences pane.<br>
 See the protocols documentation for more information.

 \section Plugins help
 Any plugin can provide some help, to be displayed in Lynkeos application.<br>
 The plugin help files shall be put in a help folder inside the localized
 resources. The help files shall be compliant with the AppleHelp guidelines.
 And finaly, the plugin bundle shall provide the AppleHelp keys :
 - CFBundleHelpBookFolder gives the name of that folder, as explained in
 AppleHelp guidelines.
 - CFBundleHelpBookName gives the name of the main html file of the help. This
 deviates from the AppleHelp guidelines, and is specific to the Lynkeos plugins
 help.

 \page processingArch Processing architecture
 The \ref LynkeosViewDocument "document" class knows how to start processings
 that implement the \ref LynkeosProcessing protocol. The processings get their
 parameters, as \ref LynkeosProcessingParameter, inside the 
 \ref LynkeosProcessableItem to process.<br>
 The \ref LynkeosProcessingView classes take care of saving the parameters
 in the items provided by the document and ask the document to start a
 processing.<br>
 The document provides \ref Notifications "notifications" for each meaningful
 event.
 \dot
 digraph process {
 node [shape=record, fontname=Helvetica, fontsize=10];
 doc [ label="Document" URL="\ref LynkeosViewDocument"];
 window [ label="Window controller" URL="\ref LynkeosWindowController"];
 process [ label="LynkeosProcessing" URL="\ref LynkeosProcessing"];
 item [ label="LynkeosProcessableItem" URL="\ref LynkeosProcessableItem"];
 param [ label="LynkeosProcessingParameter" URL="\ref LynkeosProcessingParameter"];
 view [ label="LynkeosProcessingView" URL="\ref LynkeosProcessingView"];
 doc -> window [ arrowhead="open", style="dashed" ];
 doc -> process [ arrowhead="open", style="solid" ];
 doc -> item [ arrowhead="open", style="dashed" ];
 item -> param [ arrowhead="open", style="dashed" ];
 process -> item [ arrowhead="open", style="solid" ];
 view -> doc [ arrowhead="open", style="solid" ];
 view -> window [ arrowhead="open", style="solid" ];
 view -> process [ arrowhead="open", style="dashed" ];
 }
 \enddot
 */

/*! \defgroup Views View classes
 *
 * The view classes manage the interaction with the user.
 */

 /*!
 * @header
 * @abstract Processing related view protocol.
 */
#ifndef __LYNKEOSPROCESSINGVIEW_H
#define __LYNKEOSPROCESSINGVIEW_H

#import <Foundation/Foundation.h>

#include <LynkeosCore/LynkeosProcessing.h>
#include <LynkeosCore/LynkeosProcessableImage.h>

/*!
 * @abstract Processing kind of the controller
 * @discussion This is used for GUI organization
 * @ingroup Processing
 */
typedef enum
{
   ListManagementKind,     //!< Acts on the lists contents or organization
   ListProcessingKind,     //!< Acts on a list without changing the images
   ImageProcessingKind,    //!< Acts on an image
   OtherProcessingKind     //!< Something not falling in above categories
} ProcessingViewKind_t;

/*!
 * @abstract List working mode
 * @ingroup Processing
 */
typedef enum
{
   DarkFrameMode = 1,      //!< Currently working on dark frames
   FlatFieldMode = 2,      //!< Currently working on flat fields
   ImageMode     = 4       //!< Currently working on the images
} ListMode_t;

/*!
 * @abstract Which data is used
 * @ingroup Processing
 */
typedef enum
{
   ListData = 8,        //!< Working on the lists
   ResultData = 16      //!< Working on the stacked result
} DataMode_t;

/*!
 * @abstract Part of the alignment result needed for display
 * @ingroup Processing
 */
@protocol LynkeosViewAlignResult <LynkeosAlignResult>
/*!
 * @abstract Affine transform to display the image
 */
- (NSAffineTransform*) alignTransform ;

/*!
 * @abstract Accessor to the x offset for displaying in the text view
 */
- (NSNumber*) dx;

/*!
 * @abstract Accessor to the y offset for displaying in the text view
 */
- (NSNumber*) dy;
@end

#pragma mark N   Document Notifications
/// \name DocumentNotifications
///  Document notifications.
//@{
/*!
 * @abstract Notification sent when a new document is loaded.
 * @discussion The associated object is the document itself. There is no user
 *    info.
 * @ingroup Notifications
 */
extern NSString * const LynkeosDocumentDidLoadNotification;
///@}

/*!
 * @abstract Protocol implemented by the document for processing views
 * @discussion The document provides the notification
 *    \ref LynkeosDocumentDidLoadNotification.
 * @ingroup Processing
 */
@protocol LynkeosViewDocument <LynkeosDocument>
- (id <LynkeosImageList>) imageList;               ///< Images to be processed
- (id <LynkeosImageList>) darkFrameList;           ///< Thermal noise images
- (id <LynkeosImageList>) flatFieldList;           ///< Optical attenuations
- (id <LynkeosImageList>) currentList;             ///< The list under use
- (ListMode_t) listMode ;                 ///< The mode associated to the list
- (DataMode_t) dataMode ;             ///< Whether to act on list or result
/*!
 * @abstract Set the list we will be working on from now
 * @param mode The new current list (image/flat/dark)
 */
- (void) setListMode :(ListMode_t)mode ;

/*!
 * @abstract Set the data we will work with
 */
- (void) setDataMode:(DataMode_t)mode ;

@end

#pragma mark N Image view Notifications
/// \name ImageNotifications
/// Notifications associated with the image view.
//@{
/*!
 * @abstract Selection rectangle has changed.
 * @discussion The object is the image view, the dictionary contains the index
 *    of the modified selection.
 * @ingroup Notifications
 */
extern NSString * const LynkeosImageViewSelectionRectDidChangeNotification;

/*!
 * @abstract User info key for the selection index.
 * @ingroup Notifications
 */
extern NSString * const LynkeosImageViewSelectionRectIndex;

/*!
 * @abstract When the zoom changes.
 * @discussion The object is the image view
 * @ingroup Notifications
 */
extern NSString * const LynkeosImageViewZoomDidChangeNotification;

/*!
 * @abstract Image view is being redrawn.
 * @discussion The object is the image view. There is no user info.<br>
 *    Processing views can use this notification to add drawings in the image
 *    view
 * @ingroup Notifications
 */
extern NSString * const LynkeosImageViewRedrawNotification;
//@}

/*!
 * @abstract Protocol implemented by the window image view for processing views.
 * @discussion The image view provides the folowing notifications :
 *    \ref LynkeosImageViewSelectionRectDidChangeNotification,
 *    \ref LynkeosImageViewZoomDidChangeNotification,
 *    \ref LynkeosImageViewRedrawNotification.
 * @ingroup Processing
 */
@protocol LynkeosImageView

/*!
 * @abstract Set the item to display in the view
 * @discussion The align result is taken into account if present
 * @param item The item to display
 */
- (void) displayItem:(id <LynkeosProcessableItem>)item ;

/*!
 * @abstract Update the item's image
 * @discussion This method is used for redisplaying the image after a change of
 *    settings.<br>
 *    This method redisplays inconditionally the image, use it on purpose.
 */
- (void) updateImage ;

/*!
 * @abstract Retrieve the current selection.
 * @result The current selection rectangle 
 */
- (LynkeosIntegerRect) getSelection ;

/*!
 * @abstract Retrieve a selection at a given index.
 * @param index The index of the selection to retrieve
 * @result The current selection rectangle 
 */
- (LynkeosIntegerRect) getSelectionAtIndex:(u_short)index ;

/*!
 * @abstract Get the modifiers associated with the selection
 * @result The modifiers of the current selection
 */
- (unsigned int) getModifiers ;

/*!
 * @abstract Set the selection rectangle
 * @discussion For compatibility reasons, all indexed selections are removed
 * @param selection The new current selection rectangle.
 * @param resize Is this new selection resizable.
 * @param move Whether the selection can be moved
 */
- (void) setSelection :(LynkeosIntegerRect)selection
             resizable:(BOOL)resize
               movable:(BOOL)move;

/*!
 * @abstract Set a given selection rectangle
 * @discussion The first unused index shall be used to create a new selection.
 * @param selection The new selection rectangle.
 * @param index The index of the selection
 * @param resize Is this new selection resizable.
 * @param move Whether the selection can be moved
 */
- (void) setSelection :(LynkeosIntegerRect)selection
               atIndex:(u_short)index
             resizable:(BOOL)resize
               movable:(BOOL)move;

#warning "Add a delete selection method"

/*!
 * @abstract Get the image zoom factor
 * @result The image zoom factor
 */
- (double) getZoom ;

/*!
 * @abstract Set the image view zoom factor
 * @param zoom The new zoom factor
 */
- (void) setZoom:(double)zoom ;

@end

/*!
 * @abstract Prefered way of displaying the view.
 * @ingroup Processing
 */
typedef enum
{
   //! Processing view is displayed in the main window, at the bottom left
   BottomTab = 1,
   //! Processing view occupies all the left margin of the main window
   BottomTab_NoList = 2,
   //! Processing view is displayed in a separate window
   SeparateView = 4,
   /*! Processing view is displayed in a separate window and the main window
    *  displays only the image */
   SeparateView_NoList = 8
} LynkeosProcessingViewFrame_t;

#pragma mark N   Window controller Notifications
/// \name WindowNotifications
///  Window controller notifications.
//@{
/*!
 * @abstract Notification that a new document is opened
 * @discussion The object is the document. The user info contains the window
 *    controller.<br>
 *    This notification can be used to spawn lightweight objects for monitoring
 *    the document.
 * @ingroup Notifications
 */
extern NSString * const LynkeosDocumentDidOpenNotification;
/*!
 * @abstract Notification that the document is about to close.
 * @discussion The object is the document. The user info contains the window
 *    controller.<br>
 * @ingroup Notifications
 */
extern NSString * const LynkeosDocumentWillCloseNotification;
/*!
 * @abstract User info key to get the window controller in notifications.
 * @ingroup Notifications
 */
extern NSString * const LynkeosUserinfoWindowController;

/*!
 * @abstract Notification that the textview is redrawing one of its cells.
 * @discussion The object is the NSOutlineView. The user info contains the
 *    NSCell being redrawn, the NSTableColumn where the cell belongs and the
 *    LynkeosProcessable item being drawn in the cell.<br>
 *    This notification shall be used to add custom drawings in the text view.
 * @ingroup Notifications
 */
extern NSString * const LynkeosOutlineViewWillDisplayCellNotification;
/*!
 * @abstract Key to get the item in LynkeosOutlineViewWillDisplayCellNotification
 * @ingroup Notifications
 */
extern NSString * const LynkeosOutlineViewItem;
/*!
 * @abstract Key to get the outline view in LynkeosOutlineViewWillDisplayCellNotification
 * @ingroup Notifications
 */
extern NSString * const LynkeosOutlineViewCell;
/*!
 * @abstract Key to get the column in LynkeosOutlineViewWillDisplayCellNotification
 * @ingroup Notifications
 */
extern NSString * const LynkeosOutlineViewColumn;
///@}

@protocol LynkeosProcessingView;

/*!
 * @abstract This protocol is provided by the document window controller.
 * @discussion The window controller provides the following notifications
 *    \ref LynkeosDocumentDidOpenNotification,
 *    \ref LynkeosDocumentWillCloseNotification,
 *    \ref LynkeosOutlineViewWillDisplayCellNotification,
 * @ingroup Processing
 */
@protocol LynkeosWindowController <NSObject>
/*!
 * @abstract Get the sizes of the window elements
 * @result A dictionary containing the sizes ; usable only by the controller itself
 */
- (NSDictionary*) windowSizes ;


/*!
 * @abstract Access to the "list" view.
 * @discussion Mainly to register for notifications.
 */
- (NSOutlineView*) getTextView ;

/*!
 * @abstract Access to the image view
 * @discussion This method may return a proxy for the image view. Processing
 *    should use this method in most cases ; if for a specific and good reason
 *    it needs to access the real image view, it shall use getRealImageView.
 * @result The main window image view
 */
- (id <LynkeosImageView>) getImageView ;

/*!
 * @abstract Access to the real image view
 * @result The main window image view, not the proxy, if any
 */
- (id <LynkeosImageView>) getRealImageView ;

/*!
 * @abstract Access to the currently hilighted item
 * @result The hilighted item
 */
- (id <LynkeosProcessableItem>) highlightedItem ;

/*!
 * @abstract Change the hilighted item
 * @param item The new item to hilight
 */
- (void) highlightItem :(id <LynkeosProcessableItem>)item ;

/*!
 * @abstract Authorize (or not) the selection of the working list
 * @param auth Whether to authorize or not
 */
- (void) setListSelectionAuthorization: (BOOL)auth;
/*!
 * @abstract Authorize (or not) the selection of the list/result mode
 * @param auth Whether to authorize or not
 */
- (void) setDataModeSelectionAuthorization: (BOOL)auth ;
/*!
 * @abstract Authorize (or not) the selection of items in the list
 * @param auth Whether to authorize or not
 */
- (void) setItemSelectionAuthorization: (BOOL)auth ;
/*!
 * @abstract Authorize (or not) the modification of items in the list
 * @param auth Whether to authorize or not
 */
- (void) setItemEditionAuthorization: (BOOL)auth ;

/*!
 * @abstract Enable (or not) all the GUI items that launch one process
 * @param c The class of the processing
 * @param ident Identifier for the processing instance
 * @param auth Whether to authorize or not
 */
- (void) setProcessing:(Class)c andIdent:(NSString*)ident
         authorization:(BOOL)auth ;

/*!
 * @abstract Get the item selected for image processing
 * @param item The item currently selected for processing
 * @param param The parameter currently selected for processing (nil if none)
 * @param sender The processing view requiring the item and parameter
 */
- (void) getItemToProcess:(LynkeosProcessableImage**)item
             andParameter:(LynkeosImageProcessingParameter**)param
                  forView:(id <LynkeosProcessingView>)sender ;

/*!
 * @abstract Saves an image, using the registered writers
 * @discussion The levels and gamma array contain a value for each plane plus
 *    a value for the global levels and gamma
 * @param image The image to save
 * @param black Black level for each plane
 * @param white White level for each plane
 * @param gamma Gamma correction exponent for each plane
 */
- (void) saveImage:(LynkeosStandardImageBuffer*)image
         withBlack:(double*)black white:(double*)white gamma:(double*)gamma ;

/*!
 * @abstract Load an image, using the registered image readers
 * @result The loaded image
 */
- (LynkeosStandardImageBuffer*) loadImage ;
@end

/*!
 * @abstract Protocol implemented by the "view" part of each processing
 * @discussion This protocol will be conformed to, by the classes which 
 *    implements a view controling a kind of image or list processing.<br>
 *    The processing view class is instantiated by the main window
 *    controller when needed.<br>
 *    Remark: Each instance is attached to one document and window controller.
 * @ingroup Processing
 */
@protocol LynkeosProcessingView <NSObject>

/*!
 * @abstract Should the plugin controller auto-register that class
 * @discussion The processing view is given here an opportunity to register
 *    some alternate view with the plugin controller. If it does so, it
 *    shall return "No" to avoid being registered the standard way.<br>
 *    Standard processing view controllers shall just return "Yes".
 * @result Whether to register as a standard processing controller
 */
+ (BOOL) isStandardProcessingViewController ;

/*!
 * @abstract Category to which this processing view controller belongs.
 * @param config The configuration for this processing class if any
 * @result The processing view kind
 */
+ (ProcessingViewKind_t) processingViewKindForConfig:(id <NSObject>)config;

/*!
 * @abstract Whether this view controls the given processing class
 * @discussion This method is used only for "image processing" controllers.
 *    Other kind of processing controller shall return NO.<br>
 *    It is assumed that only one controller respond YES for any given
 *    processing class ; if not, the first in the scan will be taken.
 * @param processingClass The processing class which cotroller is looked for
 * @param[out] config The config for this processing class if any
 * @result Whether this view controls the given processing class
 */
+ (BOOL) isViewControllingProcess:(Class)processingClass
                       withConfig:(id <NSObject>*)config ;

/*!
 * @abstract View characteristics.
 * @discussion The values should be the same as those returned for the
 *    preferences pane, if any.<br>
 *    The plugin controller, at startup, scans for classes implenting this
 *    protocol, the toolbar and menu are built by calling this method.
 * @param title The (localized) name of the processing, used in the menu.
 * @param toolTitle The (localized) name of the processing, used in the toolbar
 * @param key A key shortcut for this item's menu.
 * @param icon The processing icon, used in the toolbar.
 * @param tip A tooltip for that processing
 * @param config The optional configuration object
 */
+ (void) getProcessingTitle:(NSString**)title
                  toolTitle:(NSString**)toolTitle
                        key:(NSString**)key
                       icon:(NSImage**)icon
                        tip:(NSString**)tip
                  forConfig:(id <NSObject>)config;

/*!
 * @abstract Allowed ways of displaying the process view
 * @param config The configuration for this processing class if any
 * @result Bitfield of the allowed displays (\ref LynkeosProcessingViewFrame_t)
 */
+ (unsigned int) allowedDisplaysForConfig:(id <NSObject>)config;

/*!
 * @abstract Initialize a processing view instance
 * @param window The window controller
 * @param document The document
 * @param config Optional configuration for customizing the view
 */
- (id) initWithWindowController: (id <LynkeosWindowController>)window
                       document: (id <LynkeosViewDocument>)document
                  configuration: (id <NSObject>)config ;

/*!
 * @abstract Access to the processing view
 * @result The view which controls a processing
 */
- (NSView*) getProcessingView ;

/*!
 * @abstract Prefered way of displaying the processing view
 * @discussion This is not a class method to allow for "per document"
 *    customization
 * @result Preferred display
 */
- (LynkeosProcessingViewFrame_t) preferredDisplay ;

/*!
 * @abstract What processing class is controlled by this processing view
 * @result The processing class controlled by this instance
 */
- (Class) processingClass ;

/*!
 * @abstract Informs about activity of the view
 */
- (void) setActiveView:(BOOL)active ;

/*!
 * @abstract Get the parameters being processed
 * @discussion The image processing view shall allocate new parameters if
 *    applicable and it has no parameters yet. Other kind of processing need
 *    not return anything if they have no parameters or if their parameters are
 *    spread on the items of the list.
 * @result The current parameters.
 */
- (id <LynkeosProcessingParameter>) getCurrentParameters ;
@end

/*!
 * @abstract Informal protocol for validating the process view
 * @discussion To be implemented by processing view controllers which allow
 *    working on dark frame or flat field
 * @ingroup Processing
 */
@interface NSObject(LynkeosProcessingViewAdditions)
/*!
 * @abstract Authorized list and data modes for this processing view controller
 * @discussion The processing view will be inhibited for unauthorized list
 *    modes.
 *    Upon processing view activation, the window will switch to the authorized
 *    data mode if needed.
 *    If this method is not implemented, only image mode is authorized ; and 
 *    list mode for list management or processing, list and result modes for
 *    others.
 * @param config The optional configuration for this processing.
 * @result A bitfield of ListMode_t and DataMode_t
 */
+ (unsigned int) authorizedModesForConfig:(id <NSObject>)config ;

/*!
 * @abstract Whether the processing view implements its own progress indicator
 * @result YES when the processing view implements its own progress indicator
 */
+ (BOOL) hasProgressIndicator ;

/*!
 * @abstract Whether the processing view manages the zoom of the image view
 * @discussion If not implemented or it returns NO, the image view will use one
 *   zoom value for list mode and another one for result mode. If it returns 
 *   YES, the zoom value is not altered when changing mode, it is up to the
 *   processing view to change it.
 * @result YES when the processing view controls the image view zoom
 */
+ (BOOL) handleImageViewZoom ;

/*!
 * @abstract This method allows a processing view controller to react on keys
 * @param theEvent The key event to process
 * @result Whether the event was processed
 */
- (BOOL) handleKeyDown:(NSEvent *)theEvent ;
@end

#endif