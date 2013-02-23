//  Lynkeos
//  $Id: MyGuiConstants.h 481 2008-11-30 09:48:28Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Sun May 13, 2007.
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

/*!
 * @header
 * @abstract Definitions of tags in the GUI
 */

// Main menu tags (values below 100 are reserved for process menu entries)
#define K_SAVE_TAG               101   //!< File->Save menu
#define K_SAVE_AS_TAG            102   //!< File->"Save as" menu
#define K_REVERT_TAG             103   //!< File->"Revert to saved"
#define K_ADD_IMAGE_TAG          104   //!< File->"Add image"
#define K_SAVE_IMAGE_TAG         105   //!< File->"Save image"
#define K_EXPORT_MOVIE_TAG       106   //!< File->"Export movie"

#define K_UNDO_TAG               201   //!< Edit->Undo
#define K_REDO_TAG               202   //!< Edit->Redo
#define K_DELETE_TAG             203   //!< Edit->Delete

#define K_VIEW_MENU_TAG          300   //!< The view menu
#define K_HIDE_LIST_TAG          301   //!< Menu->"Hide list"
#define K_DETACH_PROCESS_TAG     302   //!< Menu->"Detach process"

#define K_PROCESS_MENU_TAG       400   //!< The process menu

#define K_HELP_MENU_TAG          500   //!< The help menu
#define K_PLUGIN_HELP_MENU_TAG   501   //!< The plugins help submenu

