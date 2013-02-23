//
//  MyImageStacker_Extrema.h
//  Lynkeos
//
//  Created by Jean-Etienne LAMIAUD on 09/01/11.
//  Copyright 2011 Jean-Etienne LAMIAUD. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include <MyImageStacker.h>

@interface MyImageStacker_Extrema : NSObject <MyImageStackerModeStrategy>
{
@private
   MyImageStackerParameters*   _params; //!< Stacking parameters
   LynkeosStandardImageBuffer* _extremum; //!< Sum of images value
}
@end
