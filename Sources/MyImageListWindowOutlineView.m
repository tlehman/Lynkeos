//
//  Lynkeos
//  $Id: MyImageListWindowOutlineView.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Tue May 22 2007.
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

#include "MyDocument.h"
#include "MyImageListWindow.h"

@implementation MyImageListWindow(Outline)

// User select or deselect a line
- (BOOL) outlineView:(NSOutlineView*)outlineView shouldSelectItem:(id)item
{
   return ( _itemSelectionAuthorized && _dataMode == ListData );
}

- (void) outlineViewSelectionDidChange :(NSNotification*)aNotification
{
   int row = [_textView selectedRow];

   _highlightedItem = nil;

   if ( row != -1 && _dataMode == ListData )
      // Selection is valid
      _highlightedItem = [_textView itemAtRow:row];
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell
     forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
   [cell setEditable: (_itemEditionAuthorized && _dataMode == ListData)];

   // Notify, to permit a custom redraw by processing views 
   NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
      cell,        LynkeosOutlineViewCell,
      tableColumn, LynkeosOutlineViewColumn,
      item,        LynkeosOutlineViewItem,
      nil];
   [[NSNotificationCenter defaultCenter] postNotificationName:
                                   LynkeosOutlineViewWillDisplayCellNotification
                                                       object:outlineView
                                                     userInfo:dict];
}

- (id) outlineView:(NSOutlineView *)outlineView child:(int)index 
            ofItem:(id)item
{
   if ( _dataMode == ListData )
   {
      if ( item == nil )
         return( [[_currentList imageArray] objectAtIndex: index] );

      else
         return( [item getChildAtIndex:index] );
   }
   else
   {
      NSAssert( item == nil && index == 0, @"Result has no children" );
      return( _currentList );
   }
}

- (BOOL) outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
   if ( _dataMode == ListData )
      return ( [item numberOfChildren] != 0 );
   else
      return( NO );
}

- (int) outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
   if ( _dataMode == ListData )
   {
      if ( item == nil )
         return( [[_currentList imageArray] count] );
      else
         return( [item numberOfChildren] );
   }
   else
   {
      NSAssert( item == nil, @"Result has no chidren" );
      double b, w, g;

      if ( [_currentList getBlackLevel:&b whiteLevel:&w gamma:&g] )
         return(1);
      else
         return(0);
   }
}

- (id) outlineView:(NSOutlineView *)outlineView 
       objectValueForTableColumn:(NSTableColumn *)tableColumn
            byItem:(id)item
{
   id columnId = [tableColumn identifier];

   // Find this column description
   LynkeosColumnDescription *desc = [_columnsDescriptor objectForKey:columnId];
   if ( desc != nil )
   {
      // Get the parameter to display
      NSObject <LynkeosProcessingParameter> *param =
                   [item getProcessingParameterWithRef:desc->_parameterReference
                                         forProcessing:desc->_processingRef];
      if ( param != nil )
      {
         // Get the field
         id field = [param valueForKey:desc->_fieldName];
         if ( field != nil )
         {
            if ( desc->_format != nil )
            {
               long long v;
               [field getValue:&v];
               return( [NSString stringWithFormat:desc->_format, v] );
            }
            else
               return( field );
         }
      }
   }

   return( nil );
}

- (void)outlineView:(NSOutlineView *)outlineView
     setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn 
             byItem:(id)item
{
   if ( [[tableColumn identifier] isEqual:@"select"] )
   {
      MyDocument *doc = [self document];
      [doc changeEntrySelection :item value :[object boolValue]];

      // Redraw other affected lines
      if ( [item numberOfChildren] != 0 )
	 [_textView reloadItem:item reloadChildren:YES];
      else
      {
         MyImageListItem *parent = [item getParent];

         if ( parent != nil )
            [_textView reloadItem:parent reloadChildren:NO];
      }
   }
}

@end