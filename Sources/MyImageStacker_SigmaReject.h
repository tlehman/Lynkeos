//
//  MyImageStacker_SigmaReject.h
//  Lynkeos
//
//  Created by Jean-Etienne LAMIAUD on 03/01/11.
//  Copyright 2011 Jean-Etienne LAMIAUD. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include "MyImageStacker.h"

@interface MyImageStacker_SigmaReject : NSObject <MyImageStackerModeStrategy>
{
   @private
   MyImageStackerParameters*   _params; //!< Stacking parameters
   LynkeosStandardImageBuffer* _sum;    //!< Sum of images value
   LynkeosStandardImageBuffer* _sum2;   //!< Sum of images square value
   u_short*                    _count;  //!< Buffer of pixel counts for pass 2
   id <LynkeosImageList>       _list;   //!< The list being stacked
}

@end
