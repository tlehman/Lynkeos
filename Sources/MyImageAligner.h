//
//  Lynkeos
//  $Id: MyImageAligner.h 475 2008-11-09 10:14:42Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun Dec 12 2005.
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

/*!
 * @header
 * @abstract Image alignment process class
 */
#ifndef __MYIMAGE_ALIGNER_H
#define __MYIMAGE_ALIGNER_H

#include "LynkeosCore/LynkeosFourierBuffer.h"
#include "LynkeosCore/LynkeosProcessing.h"

/*!
 * @abstract Reference string for this process
 * @ingroup Processing
 */
extern NSString * const myImageAlignerRef;

/*!
 * @abstract Reference for reading/setting the alignment entry parameters.
 * @ingroup Processing
 */
extern NSString * const myImageAlignerParametersRef;

/*!
 * @abstract General entry parameters for alignment
 * @ingroup Processing
 */
@interface MyImageAlignerParameters : NSObject <LynkeosProcessingParameter>
{
@public
   LynkeosIntegerPoint           _alignOrigin; //!< The alignment rectangle origin
}
@end

/*!
 * @abstract Alignment parameters saved at the document level
 * @ingroup Processing
 */
@interface MyImageAlignerListParameters : MyImageAlignerParameters
{
@public
   LynkeosIntegerSize           _alignSize;    //!< Size of the alignment rectangles
   //! The item against which align is done
   id <LynkeosProcessableItem> _referenceItem;
   //! Frequency cutoff applied before corelation
   double                 _cutoff;
   //! Correlation peak standard deviation threshold, above wich the alignment 
   //! is failed
   double                 _precisionThreshold;   
   BOOL                  _checkAlignResult;  //!< Check for false align

   //! This lock is not saved with the document. It's sole purpose is to 
   //! enforce that only one processing thread computes the 
   //! reference spectrum, and that the reference spectrum is computed before 
   //! any thread uses it
   NSLock                  *_refSpectrumLock;
   //! The spectrum of the reference item, it is shared by all processing 
   //! threads. And is no more saved.<br>
   //! It shall be nil at process creation.
   LynkeosFourierBuffer         *_referenceSpectrum;   
}
@end

/*!
 * @abstract Image aligner class
 * @discussion This class is able to align images in parallel threads
 * @ingroup Processing
 */
@interface MyImageAligner : NSObject <LynkeosProcessing>
{
@private
   id <LynkeosDocument> _document;  //!< The document in which we are processing
   //! The aligning parameters used when none other exists.
   MyImageAlignerListParameters *_rootParams;
   //! Frequency cutoff in "discrete" unit
   u_short                 _cutoff;
   //! Correlation peak standard deviation threshold in pixels unit
   double                 _precisionThreshold;
   double                 _valueThreshold;   //!< Peak minimum height
   //!< Per thread buffer for Fourier transform
   LynkeosFourierBuffer      *_bufferSpectrum;
}

@end

#endif
