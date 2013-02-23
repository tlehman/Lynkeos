//
//  Lynkeos
//  $Id: MyImageStacker.h 506 2011-03-26 18:40:46Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun Jun 17 2007.
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

/*!
* @header
 * @abstract Definitions of the "stacking" process.
 */
#ifndef __MYIMAGESTACKER_H
#define __MYIMAGESTACKER_H

#import <Foundation/Foundation.h>

#include "LynkeosProcessing.h"

#include "MyImageList.h"

/*!
 * @abstract Reference string for this process
 * @ingroup Processing
 */
extern NSString * const myImageStackerRef;

/*!
 * @abstract Reference for reading/setting the stacking parameters.
 * @ingroup Processing
 */
extern NSString * const myImageStackerParametersRef;

/*!
 * @abstract Mode of stacking
 * @ingroup Processing
 */
typedef enum
{
   Stacking_Standard,
   Stacking_Sigma_Reject,
   Stacking_Extremum
} Stack_Mode_t;

/*!
 * @abstract Kind of postprocessing after stacking (for calibration frames)
 * @ingroup Processing
 */
typedef enum
{
   NoPostStack,         //!< Leave stack as it is
   MeanStack,           //!< Pixel value is the mean of all images
   NormalizeStack       //!< Normalize so that max value = 1
} PostStack_t;

/*!
 * @abstract Stacking parameters
 * @discussion The parameters are stored at list level.
 * @ingroup Processing
 */
@interface MyImageStackerParameters : NSObject <LynkeosProcessingParameter>
{
@public
   LynkeosIntegerRect        _cropRectangle; //!< The rectangle to stack
   //! Each pixel is expanded in a _factor times _factor square, before stacking
   u_short              _factor;
   PostStack_t          _postStack;       //!< Post stack action
   BOOL                 _monochromeStack; //!< Whether to stack in monochrome
   Stack_Mode_t         _stackMethod;       //!< Stacking variant
   //! Parameters for each mode
   union method
   {
      //! Parameters for "standard deviation rejection" mode
      struct sigma
      {
         float          threshold;       //!< Standard deviation rejection thr.
         u_short        pass;            //!< Current pass
      } sigma;
      //! Parameters for "extremum (min/max)" mode
      struct extremum
      {
         BOOL           maxValue;        //!< Wether to keep min or max
      } extremum;
   }                    _method;

   NSLock*              _stackLock;       //!< Lock for orderly recombination
   unsigned             _livingThreads;   //!< How many stacking threads
   unsigned long        _imagesStacked;   //!< Total number of images stacked
}
@end

/*!
 * @abstract Strategy for the stacking mode
 * @ingroup Processing
 */
@protocol MyImageStackerModeStrategy
- (id) initWithParameters: (id <NSObject>)params
                     list:(id <LynkeosImageList>)list;
- (void) processImage: (id <LynkeosImageBuffer>)image
         withOffsets: (NSPoint*)offsets ;
- (void) finishOneProcessingThreadInList:(id <LynkeosImageList>)list ;
- (void) finishAllProcessingInList: (id <LynkeosImageList>)list;
- (LynkeosStandardImageBuffer*) stackingResult ;
@end

/*!
 * @abstract Call param which indicates which list to process
 * @discussion It is stored at document level
 * @ingroup Processing
 */
@interface MyImageStackerList : NSObject
{
@public
   id <LynkeosImageList> _list; //!< The list to stack
}
@end

/*!
 * @abstract Stacker class
 * @discussion This class is able to stack on parallel threads.<br>
 *    It stacks separately monochrome and RGB images, the stacked buffers
 *    (ie: one mono and one RGB per thread) are all recombined at the end.
 * @ingroup Processing
 */
@interface MyImageStacker : NSObject <LynkeosProcessing>
{
@private
   id <LynkeosDocument> _document;  //!< The document in which we are processing
   id <LynkeosImageList> _list;     //!< The list to stack
   //< Strategy for the selected stacking method
   NSObject <MyImageStackerModeStrategy> *_stackingStrategy;
   MyImageStackerParameters   *_params;     //!< Stacking parameters
   LynkeosStandardImageBuffer *_monoBuffer; //!< Buffer for reading mono images
   LynkeosStandardImageBuffer *_rgbBuffer;  //!< Buffer for reading RGB images
   unsigned long        _imagesStacked;     //!< Number stacked in this thread
}
@end

#endif