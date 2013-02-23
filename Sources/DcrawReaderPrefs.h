//
//  Lynkeos
//  $Id: DcrawReaderPrefs.h 500 2010-12-30 16:06:27Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Wed Sep 24 2008.
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

#ifndef __DCRAWREADERPREFS_H
#define __DCRAWREADERPREFS_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "LynkeosCore/LynkeosPreferences.h"

extern NSString * const K_TMPDIR_KEY;
extern NSString * const K_MANUALWB_KEY;
extern NSString * const K_ROTATION_KEY;
extern NSString * const K_RED_KEY;
extern NSString * const K_GREEN1_KEY;
extern NSString * const K_BLUE_KEY;
extern NSString * const K_GREEN2_KEY;
extern NSString * const K_LEVELS_KEY;
extern NSString * const K_DARK_KEY;
extern NSString * const K_SATURATION_KEY;

@interface DcrawReaderPrefs : NSObject <LynkeosPreferences>
{
   IBOutlet NSView*           _prefsView;
   IBOutlet NSTextField*      _tmpDirText;
   IBOutlet NSButton*         _manualWbButton;
   IBOutlet NSButton*         _autoRotationButton;
   IBOutlet NSTextField*      _redText;
   IBOutlet NSTextField*      _green1Text;
   IBOutlet NSTextField*      _blueText;
   IBOutlet NSTextField*      _green2Text;
   IBOutlet NSButton*         _manualLevelsButton;
   IBOutlet NSTextField*      _darkText;
   IBOutlet NSTextField*      _saturationText;

   NSString*                  _tmpDir;
   BOOL                       _manualWB;
   BOOL                       _autoRotation;
   double                     _red;
   double                     _green1;
   double                     _blue;
   double                     _green2;
   BOOL                       _manualLevels;
   double                     _dark;
   double                     _saturation;
}

- (IBAction)changeTmpDir:(id)sender;
- (IBAction)changeManualWB:(id)sender;
- (IBAction)changeAutoRotation:(id)sender;
- (IBAction)changeRed:(id)sender;
- (IBAction)changeGreen1:(id)sender;
- (IBAction)changeBlue:(id)sender;
- (IBAction)changeGreen2:(id)sender;
- (IBAction)changeManualLevels:(id)sender;
- (IBAction)changeDark:(id)sender;
- (IBAction)changeSaturation:(id)sender;

@end

#endif /* __DCRAWREADERPREFS_H */