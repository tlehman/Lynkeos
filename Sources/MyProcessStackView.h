//
//  Lynkeos
//  $Id: MyProcessStackView.h 479 2008-11-23 14:28:07Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sat Oct 27 2007.
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

#ifndef __MYPROCESSSTACKVIEW_H
#define __MYPROCESSSTACKVIEW_H

#import <Foundation/Foundation.h>

#include <LynkeosCore/LynkeosProcessingView.h>
#include "MyImageListWindow.h"

/*!
 * @abstract Image processing stack management
 * @discussion This window allows to :
 *    <ul>
 *    <li>modify a processing by acting on its controls in this window
 *    <li>delete a processing with a button on a side column
 *    <li>insert a new processing with a popup of image processings in a side
 *    column
 *    </ul>
 */
@interface MyProcessStackView : NSObject <LynkeosProcessingView,
                                          LynkeosViewDocument,
                                          LynkeosWindowController>
{
   IBOutlet NSOutlineView     *_view;        //!< The outline view
   MyImageListWindow          *_window;      //!< The document window
   id <LynkeosViewDocument>    _document;    //!< The document
   id <LynkeosImageView>       _imageView;   //!< For displaying the result

   LynkeosProcessableImage    *_item;        //!< The item being edited
   NSMutableArray             *_stack;       //!< The item's process stack
   //! Controllers for the stack
   NSMutableArray             *_procViewControllers;

   float                      _defaultRowHeight;   //!< To display text

   BOOL                       _isProcessing;       //!< If a process is running
}
@end

#endif
