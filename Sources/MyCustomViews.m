//
//  Lynkeos
//  $Id: MyCustomViews.m 501 2010-12-30 17:21:17Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Mon Aug 2, 2004.
//  Copyright (c) 2003-2005. Jean-Etienne LAMIAUD
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

#include "MyImageListWindow.h"
#include "MyCustomViews.h"

@implementation MyOutlineView

// Intercept "our" key events (and send them to the window controller)
- (void)keyDown:(NSEvent *)theEvent
{
   // Let the window controller try to handle it
   if ( ![(MyImageListWindow*)[[self window] delegate] keyDown:theEvent] )
      // Standard outline view processing
      [super keyDown:theEvent];
}

// Drag and drop management
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender 
{
   NSPasteboard *pboard;
   NSDragOperation sourceDragMask;

   sourceDragMask = [sender draggingSourceOperationMask];

   pboard = [sender draggingPasteboard];

   if ( [[pboard types] containsObject:NSFilenamesPboardType] )
   {
      if (sourceDragMask & NSDragOperationCopy)
         return NSDragOperationCopy;

      if (sourceDragMask & NSDragOperationLink)
         return NSDragOperationLink;
   }

   return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
   return( [self draggingEntered:sender] );
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
   NSPasteboard *pboard;
   NSDragOperation sourceDragMask;

   sourceDragMask = [sender draggingSourceOperationMask];
   pboard = [sender draggingPasteboard];

   if ( [[pboard types] containsObject:NSFilenamesPboardType] )
   {
      NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];

      [(MyImageListWindow*)[[self window] delegate] addFiles:files];
   }

   return YES;
}

@end

