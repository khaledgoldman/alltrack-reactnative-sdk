#include <dlfcn.h>

#import "ALTSKAdNetwork.h"
#import "ALTUserDefaults.h"
#import "ALTAlltrackFactory.h"
#import "ALTLogger.h"

@interface ALTSKAdNetwork()

@property (nonatomic, weak) id<ALTLogger> logger;

@end

@implementation ALTSKAdNetwork

#pragma mark - Lifecycle

+ (instancetype)getInstance {
    static ALTSKAdNetwork *defaultInstance = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        defaultInstance = [[self alloc] init];
    });
    return defaultInstance;
}

- (instancetype)init {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    self.logger = [ALTAlltrackFactory logger];

    return self;
}

#pragma mark - SKAdNetwork API

- (void)registerAppForAdNetworkAttribution {
    Class class = [self getSKAdNetworkClass];
    SEL selector = NSSelectorFromString(@"registerAppForAdNetworkAttribution");
    if (@available(iOS 14.0, *)) {
        if ([self isApiAvailableForClass:class andSelector:selector]) {
            NSMethodSignature *methodSignature = [class methodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
            [invocation setSelector:selector];
            [invocation setTarget:class];
            [invocation invoke];
            [self.logger verbose:@"Call to SKAdNetwork's registerAppForAdNetworkAttribution method made"];
        }
    } else {
        [self.logger warn:@"SKAdNetwork's registerAppForAdNetworkAttribution method not available for this operating system version"];
    }
}

- (void)updateConversionValue:(NSInteger)conversionValue {
    Class class = [self getSKAdNetworkClass];
    SEL selector = NSSelectorFromString(@"updateConversionValue:");
    if (@available(iOS 14.0, *)) {
        if ([self isApiAvailableForClass:class andSelector:selector]) {
            NSMethodSignature *methodSignature = [class methodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
            [invocation setSelector:selector];
            [invocation setTarget:class];
            [invocation setArgument:&conversionValue atIndex:2];
            [invocation invoke];
            [self.logger verbose:@"Call to SKAdNetwork's updateConversionValue: method made with value %d", conversionValue];
        }
    } else {
        [self.logger warn:@"SKAdNetwork's updateConversionValue: method not available for this operating system version"];
    }
}

- (void)updatePostbackConversionValue:(NSInteger)conversionValue
                    completionHandler:(void (^)(NSError *error))completion {
    Class class = [self getSKAdNetworkClass];
    SEL selector = NSSelectorFromString(@"updatePostbackConversionValue:completionHandler:");
    if (@available(iOS 15.4, *)) {
        if ([self isApiAvailableForClass:class andSelector:selector]) {
            NSMethodSignature *methodSignature = [class methodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
            [invocation setSelector:selector];
            [invocation setTarget:class];
            [invocation setArgument:&conversionValue atIndex:2];
            [invocation setArgument:&completion atIndex:3];
            [invocation invoke];
        }
    } else {
        [self.logger warn:@"SKAdNetwork's updatePostbackConversionValue:completionHandler: method not available for this operating system version"];
    }
}

- (void)updatePostbackConversionValue:(NSInteger)fineValue
                          coarseValue:(NSString *)coarseValue
                    completionHandler:(void (^)(NSError *error))completion {
    Class class = [self getSKAdNetworkClass];
    SEL selector = NSSelectorFromString(@"updatePostbackConversionValue:coarseValue:completionHandler:");
    if (@available(iOS 16.1, *)) {
        if ([self isApiAvailableForClass:class andSelector:selector]) {
            NSMethodSignature *methodSignature = [class methodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
            [invocation setSelector:selector];
            [invocation setTarget:class];
            [invocation setArgument:&fineValue atIndex:2];
            [invocation setArgument:&coarseValue atIndex:3];
            [invocation setArgument:&completion atIndex:4];
            [invocation invoke];
        }
    } else {
        [self.logger warn:@"SKAdNetwork's updatePostbackConversionValue:coarseValue:completionHandler: method not available for this operating system version"];
    }
}

- (void)updatePostbackConversionValue:(NSInteger)fineValue
                          coarseValue:(NSString *)coarseValue
                           lockWindow:(BOOL)lockWindow
                    completionHandler:(void (^)(NSError *error))completion {
    Class class = [self getSKAdNetworkClass];
    SEL selector = NSSelectorFromString(@"updatePostbackConversionValue:coarseValue:lockWindow:completionHandler:");
    if (@available(iOS 16.1, *)) {
        if ([self isApiAvailableForClass:class andSelector:selector]) {
            NSMethodSignature *methodSignature = [class methodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
            [invocation setSelector:selector];
            [invocation setTarget:class];
            [invocation setArgument:&fineValue atIndex:2];
            [invocation setArgument:&coarseValue atIndex:3];
            [invocation setArgument:&lockWindow atIndex:4];
            [invocation setArgument:&completion atIndex:5];
            [invocation invoke];
        }
    } else {
        [self.logger warn:@"SKAdNetwork's updatePostbackConversionValue:coarseValue:lockWindow:completionHandler: method not available for this operating system version"];
    }
}

#pragma mark - Alltrack helper methods

- (void)altRegisterWithCompletionHandler:(void (^)(NSError *error))callback {
    if ([ALTUserDefaults getSkadRegisterCallTimestamp] != nil) {
        [self.logger debug:@"Call to register app with SKAdNetwork already made for this install"];
        callback(nil);
        return;
    }
    [self registerAppForAdNetworkAttribution];
    callback(nil);
    [self writeSkAdNetworkRegisterCallTimestamp];
}

- (void)altUpdateConversionValue:(NSInteger)conversionValue
                     coarseValue:(NSString *)coarseValue
                      lockWindow:(NSNumber *)lockWindow
               completionHandler:(void (^)(NSError *error))callback {
    if (coarseValue != nil && lockWindow != nil) {
        // 4.0 world
        [self updatePostbackConversionValue:conversionValue
                                coarseValue:[self getSkAdNetworkCoarseConversionValue:coarseValue]
                                 lockWindow:[lockWindow boolValue]
                          completionHandler:^(NSError * _Nonnull error) {
            if (error) {
                [self.logger error:@"Call to SKAdNetwork's updatePostbackConversionValue:coarseValue:lockWindow:completionHandler: method with conversion value: %d, coarse value: %@, lock window: %d failed\nDescription: %@", conversionValue, coarseValue, [lockWindow boolValue], error.localizedDescription];
            } else {
                [self.logger debug:@"Called SKAdNetwork's updatePostbackConversionValue:coarseValue:lockWindow:completionHandler: method with conversion value: %d, coarse value: %@, lock window: %d", conversionValue, coarseValue, [lockWindow boolValue]];
            }
            callback(error);
        }];
    } else {
        // pre 4.0 world
        if (@available(iOS 15.4, *)) {
            [self updatePostbackConversionValue:conversionValue
                              completionHandler:^(NSError * _Nonnull error) {
                if (error) {
                    [self.logger error:@"Call to updatePostbackConversionValue:completionHandler: method with conversion value: %d failed\nDescription: %@", conversionValue, error.localizedDescription];
                } else {
                    [self.logger debug:@"Called SKAdNetwork's updatePostbackConversionValue:completionHandler: method with conversion value: %d", conversionValue];
                }
                callback(error);
            }];
        } else if (@available(iOS 14.0, *)) {
            [self updateConversionValue:conversionValue];
            callback(nil);
        } else {
            [self.logger error:@"SKAdNetwork API not available on this iOS version"];
            callback(nil);
        }
    }
}

#pragma mark - Private

- (BOOL)isApiAvailableForClass:(Class)class andSelector:(SEL)selector {
#if !(TARGET_OS_TV)
    if (class == nil) {
        [self.logger warn:@"StoreKit.framework not found in the app (SKAdNetwork class not found)"];
        return NO;
    }
    if (!selector) {
        [self.logger warn:@"Selector for given method was not found"];
        return NO;
    }
    if ([class respondsToSelector:selector] == NO) {
        [self.logger warn:@"%@ method implementation not found", NSStringFromSelector(selector)];
        return NO;
    }
    return YES;
#else
    [self.logger debug:@"%@ method implementation not available for tvOS platform", NSStringFromSelector(selector)];
    return NO;
#endif
}

- (void)writeSkAdNetworkRegisterCallTimestamp {
    NSDate *callTime = [NSDate date];
    [ALTUserDefaults saveSkadRegisterCallTimestamp:callTime];
}

- (NSString *)getSkAdNetworkCoarseConversionValue:(NSString *)alltrackCoarseValue {
#if !(TARGET_OS_TV)
    if (@available(iOS 16.1, *)) {
        if ([alltrackCoarseValue isEqualToString:@"low"]) {
            NSString * __autoreleasing *lowValue = (NSString * __autoreleasing *)dlsym(RTLD_DEFAULT, "SKAdNetworkCoarseConversionValueLow");
            return *lowValue;
        } else if ([alltrackCoarseValue isEqualToString:@"medium"]) {
            NSString * __autoreleasing *mediumValue = (NSString * __autoreleasing *)dlsym(RTLD_DEFAULT, "SKAdNetworkCoarseConversionValueMedium");
            return *mediumValue;
        } else if ([alltrackCoarseValue isEqualToString:@"high"]) {
            NSString * __autoreleasing *highValue = (NSString * __autoreleasing *)dlsym(RTLD_DEFAULT, "SKAdNetworkCoarseConversionValueHigh");
            return *highValue;
        } else {
            return nil;
        }
    } else {
        return nil;
    }
#else
    return nil;
#endif
}

- (Class)getSKAdNetworkClass {
    return NSClassFromString(@"SKAdNetwork");
}

@end
