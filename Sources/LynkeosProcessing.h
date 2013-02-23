//
//  Lynkeos
//  $Id: LynkeosProcessing.h 482 2008-12-08 16:38:55Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Tue Aug 30 2005.
//  Copyright (c) 2005-2008. Jean-Etienne LAMIAUD
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

/*! \defgroup Processing  Processing classes
 *
 * The processing classes provides image processing functions to the controler
 * classes
 */
/*! \defgroup Notifications Notifications provided by controller classes
 *
 * The notifications are used to provide "anonymous" calls from core classes
 * without the hassles of tight coupling.
 */
/*! \defgroup Models Model classes
 *
 * The model classes represent data manipulated by the application
 */

/*!
 * @header
 * @abstract Image list processing protocol.
 * @discussion This protocol will be conformed to, by the classes which 
 *   implements the processing of an image or a list of images.
 */
#ifndef __LYNKEOSPROCESSING_H
#define __LYNKEOSPROCESSING_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include <LynkeosCore/LynkeosCommon.h>

@protocol LynkeosImageBuffer;
@class LynkeosStandardImageBuffer;
@class LynkeosFourierBuffer;
@class LynkeosProcessableImage;

/*!
 * @abstract Floating point precision of images
 * @ingroup Processing
 */
typedef enum
{
   SINGLE_PRECISION,
   DOUBLE_PRECISION
} floating_precision_t;

/*!
 * @abstract Convenience macro for accessing a sample plane with the required 
 *   precision
 * @param s Sample plane ("planes[color]" in saveXXX context)
 * @param p precision ("precision" in saveXXX context)
 * @param x X coordinate of pixel
 * @param y Y coordinate of pixel
 * @param w The pixels line width of the samples buffer ("lineW" in 
 *   saveXXX context)
 * @ingroup Processing
 */
#define GET_SAMPLE(s,p,x,y,w)  \
   ( (p) == SINGLE_PRECISION ? \
      ((float*)s)[(y)*(w)+(x)] : ((double*)s)[(y)*(w)+(x)] )

/*!
 * @abstract Convenience macro for accessing a sample plane with the required 
 *   precision
 * @param s Sample plane ("planes[color]" in convertToPlanar context)
 * @param p precision ("precision" in convertToPlanar context)
 * @param x X coordinate of pixel
 * @param y Y coordinate of pixel
 * @param w The pixels line width of the samples buffer ("lineW" in 
 *   convertToPlanar context)
 * @param v The value to store in the output buffer
 * @ingroup Processing
 */
#define SET_SAMPLE(s,p,x,y,w,v)             \
if ( (p) == SINGLE_PRECISION )              \
{                                           \
   ((float*)s)[(y)*(w)+(x)] = (float)(v);   \
}                                           \
else                                        \
{                                           \
   ((double*)s)[(y)*(w)+(x)] = (double)(v); \
}

/*!
 * @abstract Get which processing precision this application was compiled with
 */
extern const floating_precision_t LynkeosProcessingPrecision ;

/*!
 * @abstract Adjust a value to the nearest power of 2, 3, 5, 7 for efficient FFT
 * @param n the value to adjust
 * @result The adjusted value
 * @ingroup Processing
 */
extern u_short adjustFFTside( u_short n );

/*!
 * @abstract Adjust a rectangle size for efficient FFT (keeping the same center)
 * @param r the rectangle to adjust
 * @result The adjusted rectangle
 * @ingroup Processing
 */
extern void adjustFFTrect( LynkeosIntegerRect *r );

//! \brief The number of CPUs to use in parallelizable processings
extern u_short numberOfCpus;
//! \brief Whether the CPU has SIMD instructions
extern u_char hasSIMD;

/*!
 * @abstract Processing parameter.
 * @discussion The "parameters" contains parameters for some processing classes.
 *   They are stored in the processable items and used by the processing classes
 *   and their associated graphical interfaces.<br>
 *   Well, there is nothing in this prototype... It's just a way to
 *   require inheritance of NSCoder (for saving/loading) and NSObject protocols
 *   (for memory management).
 * @ingroup Processing
 */
@protocol LynkeosProcessingParameter <NSObject,NSCoding>
@end

/*!
 * @abstract Process string for the align result
 * @ingroup Processing
 */
extern NSString * const LynkeosAlignRef;

/*!
 * @abstract Reference for reading/setting the alignment result.
 * @ingroup Processing
 */
extern NSString * const LynkeosAlignResultRef;

/*!
 * @abstract The alignment result for an image
 * @ingroup Processing
 */
@protocol LynkeosAlignResult <LynkeosProcessingParameter>
/*!
 * @abstract Accessor to the global offset
 */
- (NSPoint) offset;

/*!
 * @abstract "Rectification of the image"
 */
- (NSPoint) correctedCoordinatesFor:(NSPoint)source ;
@end

/*!
 * @abstract Processing parameter for image processing
 * @discussion Subclasses shall call <i>super</i> in their NSCoding method.
 * @ingroup Processing
 */
@interface LynkeosImageProcessingParameter : NSObject
                                          <LynkeosProcessingParameter,NSCopying>
{
@private
   BOOL   _excluded;  //!< Excluded from the stack of processings
   //! Allows to distinguish between occurences of the same process in the
   //! process stack
   u_long _sequence;
   Class  _processingClass;    //!< Needed to autocomplete processings
}
/*!
 * @abstract Sets the processing class which handles this parameter
 * @param c The class able to process this parameter
 */
- (void) setProcessingClass:(Class)c ;
/*!
 * @abstract Accessor to the associated processing class
 * @result The class able to process this parameter
 */
- (Class) processingClass ;

/*!
 * @abstract Whether the process is excluded from processing
 * @result YES if that process shall be skipped
 */
- (BOOL) isExcluded ;

/*!
 * @abstract Set whether the process is excluded from processing
 * @param excluded Whether the process is excluded...
 */
- (void) setExcluded:(BOOL)excluded ;
@end

/*!
 * @abstract This protocol is implemented by the classes which store and provide
 *    parameters.
 * @ingroup Processing
 */
@protocol LynkeosProcessable <NSObject>

/*!
 * @abstract Returns the required processing parameter
 * @discussion The expected behavior is that items being stored in hierachical
 *    trees, if the item cannot be found in an item, the item itself tries to
 *    retrieve it from its container item.
 * @param ref A string identifying this parameter in its class.
 * @param processing A string identifying the owner of this parameter. nil is 
 *    valid, if the parameter is of general scope.
 * @result The required parameter
 */
- (id <LynkeosProcessingParameter>) getProcessingParameterWithRef:(NSString*)ref 
                                           forProcessing:(NSString*)processing ;

/*!
 * @abstract Returns the required processing parameter
 * @param ref A string identifying this parameter in its class.
 * @param processing A string identifying the owner of this parameter. nil is 
 *    valid, if the parameter is of general scope.
 * @param goUp Whether to look for the parameter up in the hierarchy
 * @result The required parameter
 */
- (id <LynkeosProcessingParameter>) getProcessingParameterWithRef:(NSString*)ref 
                                             forProcessing:(NSString*)processing
                                                             goUp:(BOOL)goUp ;

/*!
 * @abstract Updates the required processing parameter
 * @param parameter The new parameter value
 * @param ref A string identifying this parameter in its class.
 * @param processing A string identifying the owner of this parameter. nil is 
 *    valid, if the parameter is of general scope.
 * @result The required parameter
 */
- (void) setProcessingParameter:(id <LynkeosProcessingParameter>)parameter
                        withRef:(NSString*)ref 
                  forProcessing:(NSString*)processing ;

@end

/*!
 * @abstract This protocol is implemented by the classes that can be the target
 *    of a processing
 * @ingroup Processing
 */
@protocol LynkeosProcessableItem <LynkeosProcessable>

/*!
 * @abstract Get the number of color planes
 * @result The number of color planes
 */
- (u_short) numberOfPlanes;

/*!
 * @abstract Read the image size
 * @result Image size
 */
- (LynkeosIntegerSize) imageSize;

/*!
 * @abstract Access to the processed image
 * @result The processed LynkeosImageBuffer
 */
- (id <LynkeosImageBuffer>) getImage ;

/*!
 * @abstract Access to the unprocessed image
 * @result The LynkeosImageBuffer before processing
 */
- (id <LynkeosImageBuffer>) getOriginalImage ;

/*!
 * @abstract Gives the item's image "sequence number"
 * @result The item's image sequence number
 * @discussion The sequence number is incremented each time the image is
 *    modified. And therefore, the item's image is guaranteed to be unchanged
 *    if the sequence number is.
 */
- (u_long) getSequenceNumber ;

/*!
 * @abstract Returns an NSImage for displaying.
 * @result A NSImage built from the processed image data.
 */
- (NSImage*) getNSImage;

/*!
 * @abstract Read a calibrated sample from an image
 * @discussion *buffer can be nil, in which case it will be allocated by the
 *   called method. The precision of the buffer is implied by the "processing"
 *   method ; because Lynkeos provides only buffers of its compiled precision.
 *
 *   The image which sample is returned, is the latest processing result or
 *   the "original" image if no processing result was saved ; in which case, 
 *   calibration frames, if any, are applied.
 * @param buffer The image or Fourier buffer to fill, if nil it is created
 * @param rect The rectangle in which to extract the sample (it shall be 
 *   entirely inside the image)
 */
- (void) getImageSample:(LynkeosStandardImageBuffer**)buffer 
                 inRect:(LynkeosIntegerRect)rect ;

/*!
 * @abstract Access to the Fourier transform of the image
 * @param buffer The buffer in which to put the transform
 * @param rect The rectangle from which the data to transform is extracted
 * @param prepareInverse Wether to prepare the buffer for an inverse transform
 * @result The Fourier transform of the processed image
 */
- (void) getFourierTransform:(LynkeosFourierBuffer**)buffer 
                     forRect:(LynkeosIntegerRect)rect
              prepareInverse:(BOOL)prepareInverse ;

/*!
 * @abstract Set the fourier transform after processing
 * @discussion The processable item makes the inverse transform when appropriate
 * @param buffer The processed fourier transform
 */
- (void) setFourierTransform:(LynkeosFourierBuffer*)buffer ;

/*!
 * @abstract Save the resulting image
 * @param buffer The buffer containing the image processing result.
 */
- (void) setImage:(LynkeosStandardImageBuffer*)buffer ;

/*!
 * @abstract Save the resulting image as the original image
 * @param buffer The buffer containing the image processing result.
 */
- (void) setOriginalImage:(LynkeosStandardImageBuffer*)buffer ;

/*!
 * @abstract Delete any processing result and go back to using the "original"
 *    image.
 * @result None
 */
- (void) revertToOriginal ;

/*!
 * @abstract Wether the image is the original or has been processed
 * @result YES if the image has not been processed
 */
- (BOOL) isOriginal ;

/*!
 * @abstract Whether the image (even if original) comes from some process
 * @discussion A freshly stacked image is the original image for the item, but
 *    does come from the stacking process.
 * @result NO when the image comes from a file
 */
- (BOOL) isProcessed ;

/*!
 * @abstract Sets the levels for image visualization
 * @param black The level below which only black is diplayed
 * @param white The level above which white is displayed
 * @param gamma The gamma correction
 */
- (void) setBlackLevel:(double)black whiteLevel:(double)white
                  gamma:(double)gamma ;

/*!
 * @abstract Retrieves the global levels for image visualization
 * @discussion If the levels are not set, all parameters will be NaNs
 * @param[out] black The level below which only black is diplayed
 * @param[out] white The level above which white is displayed
 * @param[out] gamma The gamma correction
 * @result Wether the levels are set
 * @param gamma The gamma correction
 */
- (BOOL) getBlackLevel:(double*)black whiteLevel:(double*)white
                 gamma:(double*)gamma ;

/*!
 * @abstract Retrieves the minimum and maximum levels of an image
 * @discussion If the levels are not set, min and max will be NaNs
 * @param[out] vmin The minimum level of the image
 * @param[out] vmax The maximum level
 * @result Wether the levels are set
 */
- (BOOL) getMinLevel:(double*)vmin maxLevel:(double*)vmax ;

/*!
 * @abstract Sets the levels for one color plane
 * @discussion These settings are applied before the global settings during
 *    image visualization
 * @param black The level below which only black is diplayed
 * @param white The level above which white is displayed
 * @param gamma The gamma correction
 * @param plane The plane number
 */
- (void) setBlackLevel:(double)black whiteLevel:(double)white
                 gamma:(double)gamma forPlane:(u_short)plane ;

/*!
 * @abstract Retrieves the levels for image visualization
 * @discussion If the levels are not set, all parameters will be NaNs
 * @param[out] black The level below which only black is diplayed
 * @param[out] white The level above which white is displayed
 * @param[out] gamma The gamma correction
 * @param plane The plane number
 * @result Wether the levels are set
 */
- (BOOL) getBlackLevel:(double*)black whiteLevel:(double*)white
                 gamma:(double*)gamma forPlane:(u_short)plane ;

/*!
 * @abstract Retrieves the minimum and maximum levels of an image
 * @discussion If the levels are not set, min and max will be NaNs
 * @param[out] vmin The minimum level of the image
 * @param[out] vmax The maximum level
 * @param plane The plane number
 * @result Wether the levels are set
 */
- (BOOL) getMinLevel:(double*)vmin maxLevel:(double*)vmax
            forPlane:(u_short)plane ;
@end

/*!
 * @abstract Base protocol for an image list
 * @ingroup Processing
 */
@protocol LynkeosImageList <LynkeosProcessableItem>
/*!
 * @abstract Get direct access to the array of images
 * @result The image array
 */
- (NSMutableArray*) imageArray ;

/*!
 * @abstract Get the first item selected for processing in the list
 * @result The first selected item
 */
- (id <LynkeosProcessableItem>) firstItem ;

/*!
 * @abstract Get the last item selected for processing in the list
 * @result The last selected item
 */
- (id <LynkeosProcessableItem>) lastItem ;

/*!
 * @abstract Get an enumerator over all the images in the list
 * @result The list's images enumerator
 */
- (NSEnumerator*) imageEnumerator ;

/*!
 * @abstract Get an enumerator in the given direction over the list's images 
 *   starting at the given item
 * @param item The starting item
 * @param direct The sense (direct=YES, reverse=NO)
 * @param skip Whether to skip unselected images
 * @result The list's images enumerator
 */
- (NSEnumerator*) imageEnumeratorStartAt:(id)item 
                                      directSense:(BOOL)direct
                                   skipUnselected:(BOOL)skip;
@end

#pragma mark N   Notifications
/// \name Notifications
///  Processing notifications.
//@{
/*!
 * @abstract When a process is started.
 * @discussion The object is the document, the user info contains the processing
 *    class.
 */
extern NSString * const LynkeosProcessStartedNotification;
/*!
 * @abstract When a process ends.
 * @discussion The object is the document, the user info contains the processing
 *    class.
 * @ingroup Notifications
 */
extern NSString * const LynkeosProcessEndedNotification;
/*!
 * @abstract The key for retrieving the process class from the user info.
 * @ingroup Notifications
 */
extern NSString * const LynkeosUserInfoProcess;

/*!
 * @abstract When all the image processings attached to an item are applied
 * @discussion  The object is the document, the user info is the same as 
 *    \ref LynkeosItemChangedNotification.
 * @ingroup Notifications
 */
extern NSString * const LynkeosProcessStackEndedNotification;

/*!
 * @abstract When an item of the document is changed.
 * @discussion The object is the document, the user info contains the item
 *    accessible by the key \ref LynkeosUserInfoItem
 * @ingroup Notifications
 */
extern NSString * const LynkeosItemChangedNotification;
/*!
 * @abstract The key to retrieve the item from the user info
 * @ingroup Notifications
 */
extern NSString * const LynkeosUserInfoItem;

/*!
 * @abstract When an item was used by a list process
 * @discussion  The object is the document, the user info is the same as 
 *    \ref LynkeosItemChangedNotification.
 * @ingroup Notifications
 */
extern NSString * const LynkeosItemWasProcessedNotification;

/*!
 * @abstract When an item is added to a list.
 * @discussion There is no user info, because of possible coalescing
 * @ingroup Notifications
 */
extern NSString * const LynkeosItemAddedNotification;
/*!
 * @abstract When an item is added or removed to/from a list.
 * @discussion There is no user info, because of possible coalescing
 * @ingroup Notifications
 */
extern NSString * const LynkeosItemRemovedNotification;

/*!
 * @abstract When the current list is changed
 * @ingroup Notifications
 */
extern NSString * const LynkeosListChangeNotification;

/*!
 * @abstract When the current data mode changes
 * @ingroup Notifications
 */
extern NSString * const LynkeosDataModeChangeNotification;
///@}

/*!
 * @abstract This protocol gathers the methods provided to the processing 
 *    classes by the document.
 * @discussion The document provides the following notifications :
 *    \ref LynkeosProcessStartedNotification,
 *    \ref LynkeosProcessEndedNotification,
 *    \ref LynkeosProcessStackEndedNotification,
 *    \ref LynkeosItemChangedNotification,
 *    \ref LynkeosItemWasProcessedNotification,
 *    \ref LynkeosItemAddedNotification,
 *    \ref LynkeosItemRemovedNotification,
 *    \ref LynkeosListChangeNotification,
 *    \ref LynkeosDataModeChangeNotification.
 * @ingroup Processing
 */
@protocol LynkeosDocument <LynkeosProcessable>

/*!
 * @abstract Start a list processing in several threads.
 * @param processingClass The class of the processing objects.
 * @param enumerator An enumerator of the items to process (ie: of ONLY the
 *    items to process).
 * @param params Volatile parameters needed by the process
 */
- (void) startProcess: (Class) processingClass
       withEnumerator: (NSEnumerator*)enumerator
           parameters:(id <NSObject>)params ;

/*!
 * @abstract Start the processing of an single item, in a separate thread
 * @param processingClass The class of the processing object
 * @param item The item to process
 * @param params The processing parameters
 */
- (void) startProcess: (Class) processingClass
              forItem: (LynkeosProcessableImage*)item
           parameters: (LynkeosImageProcessingParameter*)params ;

/*!
 * @abstract Stop the current processing.
 * @result None
 */
- (void) stopProcess ;

/*!
 * @abstract Kinds of multiprocessor optimisation
 * @discussion The optims can be combined with an "or".
 */
typedef enum
{
   NoParallelOptimization = 0,   //!< No optimisation at all
   FFTW3ThreadsOptimization = 1, //!< Use FFTW3 threading
   ListThreadsOptimizations = 2  //!< Use list processing threading
} ParallelOptimization_t;

/*!
 * @abstract Signals that an item was used in the process
 * @discussion This method shall not be called by processes which modify the
 *    items ; as it causes an "item changed" notification, this method is
 *    at least useless in this case, maybe even harmful.
 * @param item The item which was processed
 */
- (oneway void) itemWasProcessed:(id <LynkeosProcessableItem>)item;
@end

/*!
 * @abstract Common protocol for all processing classes.
 * @discussion The class will be instantiated in a thread by 
 *   a processing controller, which will pass it the items to process.<br>
 *   The processing parameters are placed in @ref LynkeosProcessingParameter 
 *   "processing parameters" by the associated graphical interface.<br>
 *   The processing results can be placed in parameters or in the "image"
 *   attribute of the @ref LynkeosProcessableItem "processed item".<br>
 * @ingroup Processing
 */
@protocol LynkeosProcessing <NSObject>

/*!
 * @abstract Wether this processing class can be executed in parallel threads.
 * @result Parallelization kind
 */
+ (ParallelOptimization_t) supportParallelization ;

/*!
 * @abstract Initializes the process instance with its document.
 * @discussion This method provides access to a proxy of the document which is
 *    meant to call exclusively the methods of the LynkeosDocument protocol (as
 *    implied by the typing). If another document method needs to be accessed, as
 *    a "processable item" for example, its reference shall be provided by the
 *    process enumerator (ie: it shall be an item).
 * @param document The document which data is being processed.
 * @param params Optional parameters for the process
 * @param precision The precision in which Lynkeos is running (needed for plugin
 *    processes, wich are not compiled in the main application).
 */
- (id <LynkeosProcessing>) initWithDocument: (id <LynkeosDocument>)document
                                 parameters:(id <NSObject>)params
                                  precision:(floating_precision_t)precision;

/*!
 * @abstract Apply the processing to an item.
 * @param item The item to process.
 */
- (void) processItem :(id <LynkeosProcessableItem>)item ;

/*!
 * @abstract There will be no more items to process.
 * @discussion This method can update the document with any cumulated results.
 */
- (void) finishProcessing ;

@end

#endif