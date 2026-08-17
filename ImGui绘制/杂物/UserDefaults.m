//
//  UserDefaults.m
//  BCei
//
//  Created by Laote on 2025/12/3.
//  Copyright © 2025 BCei. All rights reserved.
//

#import "UserDefaults.h"

@implementation UserDefaults

+ (NSUserDefaults *)tixDefaults {
    NSString *bundleIdentifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
    NSString *suiteName = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Library/Preferences/%@.plist", bundleIdentifier]];
    return [[NSUserDefaults alloc] initWithSuiteName:suiteName];
}

+ (void)setObject:(nullable id)value forKey:(NSString *)key {
    [[self tixDefaults] synchronize];
    [[self tixDefaults] setObject:value forKey:key];
}

+ (nullable id)getObject:(NSString *)key {
    NSUserDefaults *Defaults = [self tixDefaults];
    return [Defaults objectForKey:key];
}

+ (nullable NSString *)getString:(NSString *)key {
    return [[self tixDefaults] stringForKey:key];
}

+ (NSInteger)getInteger:(NSString *)key {
    return [[self tixDefaults] integerForKey:key];
}

+ (bool)getBool:(NSString *)key {
    return [[self tixDefaults] boolForKey:key];
}

+ (void)removeObject:(NSString *)key {
    [[self tixDefaults] removeObjectForKey:key];
}

void savfloat(float value, NSString *key) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [UserDefaults setObject:@(value) forKey:key];
    });
}

void savbool(bool value, NSString *key) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [UserDefaults setObject:@(value) forKey:key];
    });
}

void GetUserValue(NSString *key, ResultBlock resultBlock) {
    if (!resultBlock) return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        id value = [UserDefaults getObject:key];
        dispatch_async(dispatch_get_main_queue(), ^{
            resultBlock(value);
        });
    });
}

void savfloat4(const float value[4], NSString *key) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSData *data = [NSData dataWithBytes:value length:sizeof(float) * 4];
        [UserDefaults setObject:data forKey:key];
    });
}

void savfloat4_sync(const float value[4], NSString *key) {
    NSData *data = [NSData dataWithBytes:value length:sizeof(float) * 4];
    [UserDefaults setObject:data forKey:key];
    [[UserDefaults tixDefaults] synchronize];
}

void getfloat4(NSString *key, ResultBlock resultBlock) {
    if (!resultBlock) return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        id obj = [UserDefaults getObject:key];
        float values[4] = {1.0f, 1.0f, 0.0f, 1.0f};
        if ([obj isKindOfClass:[NSData class]] && [(NSData *)obj length] == sizeof(float) * 4) {
            memcpy(values, [(NSData *)obj bytes], sizeof(values));
        }
        NSData *resultData = [NSData dataWithBytes:values length:sizeof(values)];
        dispatch_async(dispatch_get_main_queue(), ^{
            resultBlock(resultData);
        });
    });
}

@end
