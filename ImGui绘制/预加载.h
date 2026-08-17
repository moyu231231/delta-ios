
#ifdef __OBJC__
    #if __has_include(<TargetConditionals.h>)
        #import <TargetConditionals.h>
    #endif
    
    #import <Foundation/Foundation.h>
    #import <UIKit/UIKit.h>
    
    #import <notify.h>
    #import <objc/runtime.h>
    #import <objc/objc-api.h>
    #import <objc/NSObject.h>
    #import <CoreFoundation/CFBase.h>
#endif

#ifdef __cplusplus
    #include <string>
    #include <vector>
#endif

#if __has_include(<AvailabilityVersions.h>)
    #import <AvailabilityVersions.h>
#endif
