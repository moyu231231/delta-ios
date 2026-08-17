//
//  UserDefaults.h
//  BCei
//
//  Created by Laote on 2025/12/3.
//  Copyright © 2025 BCei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UserDefaults : NSObject

+ (void)setObject:(nullable id)value forKey:(NSString *)key;
+ (nullable id)getObject:(NSString *)key;
+ (nullable NSString *)getString:(NSString *)key;
+ (NSInteger)getInteger:(NSString *)key;
+ (bool)getBool:(NSString *)key;
+ (void)removeObject:(NSString *)key;

#ifdef __cplusplus
extern "C" {
#endif
    void savfloat(float value, NSString *key);
    void savbool(bool value, NSString *key);

    typedef void(^ResultBlock)(id _Nullable value);
    void GetUserValue(NSString *key, ResultBlock resultBlock);
    void savfloat4(const float value[4], NSString *key);
    void savfloat4_sync(const float value[4], NSString *key);
    void getfloat4(NSString *key, ResultBlock resultBlock);
#ifdef __cplusplus
}
#endif

@end

NS_ASSUME_NONNULL_END
