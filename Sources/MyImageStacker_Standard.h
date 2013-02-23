//
//  MyImageStacker_Standard.h
//  Lynkeos
//
//  Created by Jean-Etienne LAMIAUD on 01/01/11.
//  Copyright 2011 Jean-Etienne LAMIAUD. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include "MyImageStacker.h"

@interface MyImageStacker_Standard : NSObject <MyImageStackerModeStrategy>
{
   @private
   MyImageStackerParameters* _params;  //!< Stacking parameters
   LynkeosStandardImageBuffer* _monoStack; //!< Stack of mono images
   LynkeosStandardImageBuffer* _rgbStack; //!< Stack of RGB images
}
@end
