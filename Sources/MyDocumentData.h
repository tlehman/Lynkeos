//
//  Lynkeos 
//  $Id: MyDocumentData.h 462 2008-10-05 21:31:44Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Thu Jul 29 2004.
//  Copyright (c) 2004-2008. Jean-Etienne LAMIAUD
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
 * @abstract Document contents wrapper classes
 * @discussion The load and save use these classes as a root object to feed the
 *    archiver or extract from the unarchiver.
 *
 *    The V0 document format is handled by a compatibility class
 */
#ifndef __MYDOCUMENTDATA_H
#define __MYDOCUMENTDATA_H

#include "MyImageList.h"

//! Current revision of the data format
#define K_DATA_REVISION 2

/*!
 * @abstract Wrapper class for version 2 document content
 * @discussion The document attributes to be saved are copied in an instance of
 *    this class which feed the archiver
 * @ingroup Models
 */
@interface MyDocumentDataV2 : NSObject <NSCoding>
{
@public
   int                  _formatRevision;  //!< Saved data format revision
   MyImageList*         _imageList;       //!< "Real" image list
   MyImageList*		_darkFrameList;   //!< Dark frame image list
   MyImageList*		_flatFieldList;   //!< Flat field image list
   NSDictionary*        _parameters;      //!< Top level parameters
   NSDictionary*        _windowSizes;     //!< The window sizes and position
}
@end

//! Definition of MyObjectImageList compatibility class for the reader
@interface MyObjectImageList : MyImageList
{
}
@end

/*!
 * @abstract Wrapper class for version 1 document content
 * @discussion The document attributes to be saved are copied in an instance of
 *    this class which feed the archiver
 * @ingroup Models
 */
@interface MyDocumentDataV1 : NSObject <NSCoding>
{
@public
   int                  _formatRevision;  //!< Saved data format revision
   MyObjectImageList*	_imageList;       //!< "Real" image list
   MyImageList*		_darkFrameList;   //!< Dark frame image list
   MyImageList*		_flatFieldList;   //!< Flat field image list
   //! Wether to convert the flat field stack to monochrome
   BOOL                 _monochromeFlat;
   int                  _analysisMethod;  //!< Analysis method enum converted
}
@end

#endif
