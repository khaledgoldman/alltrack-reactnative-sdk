#import <objc/runtime.h>
#import "AlltrackSdkDelegate.h"

#if __has_include(<React/RCTAssert.h>)
#import <React/RCTEventDispatcher.h>
#else // back compatibility for RN version < 0.40
#import "RCTEventDispatcher.h"
#endif

static dispatch_once_t onceToken;
static AlltrackSdkDelegate *defaultInstance = nil;

@implementation AlltrackSdkDelegate

#pragma mark - Object lifecycle methods

- (id)init {
    self = [super init];
    if (nil == self) {
        return nil;
    }
    return self;
}

#pragma mark - Public methods

+ (id)getInstanceWithSwizzleOfAttributionCallback:(BOOL)swizzleAttributionCallback
                           eventSucceededCallback:(BOOL)swizzleEventSucceededCallback
                              eventFailedCallback:(BOOL)swizzleEventFailedCallback
                         sessionSucceededCallback:(BOOL)swizzleSessionSucceededCallback
                            sessionFailedCallback:(BOOL)swizzleSessionFailedCallback
                         deferredDeeplinkCallback:(BOOL)swizzleDeferredDeeplinkCallback
                   conversionValueUpdatedCallback:(BOOL)swizzleConversionValueUpdatedCallback
              skad4ConversionValueUpdatedCallback:(BOOL)swizzleSkad4ConversionValueUpdatedCallback
                     shouldLaunchDeferredDeeplink:(BOOL)shouldLaunchDeferredDeeplink {
    dispatch_once(&onceToken, ^{
        defaultInstance = [[AlltrackSdkDelegate alloc] init];

        // Do the swizzling where and if needed.
        if (swizzleAttributionCallback) {
            [defaultInstance swizzleCallbackMethod:@selector(alltrackAttributionChanged:)
                                  swizzledSelector:@selector(alltrackAttributionChangedWannabe:)];
        }
        if (swizzleEventSucceededCallback) {
            [defaultInstance swizzleCallbackMethod:@selector(alltrackEventTrackingSucceeded:)
                                  swizzledSelector:@selector(alltrackEventTrackingSucceededWannabe:)];
        }
        if (swizzleEventFailedCallback) {
            [defaultInstance swizzleCallbackMethod:@selector(alltrackEventTrackingFailed:)
                                  swizzledSelector:@selector(alltrackEventTrackingFailedWannabe:)];
        }
        if (swizzleSessionSucceededCallback) {
            [defaultInstance swizzleCallbackMethod:@selector(alltrackSessionTrackingSucceeded:)
                                  swizzledSelector:@selector(alltrackSessionTrackingSucceededWannabe:)];
        }
        if (swizzleSessionFailedCallback) {
            [defaultInstance swizzleCallbackMethod:@selector(alltrackSessionTrackingFailed:)
                                  swizzledSelector:@selector(alltrackSessionTrackingFailedWananbe:)];
        }
        if (swizzleDeferredDeeplinkCallback) {
            [defaultInstance swizzleCallbackMethod:@selector(alltrackDeeplinkResponse:)
                                  swizzledSelector:@selector(alltrackDeeplinkResponseWannabe:)];
        }
        if (swizzleConversionValueUpdatedCallback) {
            [defaultInstance swizzleCallbackMethod:@selector(alltrackConversionValueUpdated:)
                                  swizzledSelector:@selector(alltrackConversionValueUpdatedWannabe:)];
        }
        if (swizzleSkad4ConversionValueUpdatedCallback) {
            [defaultInstance swizzleCallbackMethod:@selector(alltrackConversionValueUpdated:coarseValue:lockWindow:)
                                  swizzledSelector:@selector(alltrackConversionValueUpdatedWannabe:coarseValue:lockWindow:)];
        }
        [defaultInstance setShouldLaunchDeferredDeeplink:shouldLaunchDeferredDeeplink];
    });

    return defaultInstance;
}

+ (void)teardown {
    defaultInstance = nil;
    onceToken = 0;
}

#pragma mark - Private & helper methods

- (void)alltrackAttributionChangedWannabe:(ALTAttribution *)attribution {
    if (attribution == nil) {
        return;
    }

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [self addValueOrEmpty:dictionary key:@"trackerToken" value:attribution.trackerToken];
    [self addValueOrEmpty:dictionary key:@"trackerName" value:attribution.trackerName];
    [self addValueOrEmpty:dictionary key:@"network" value:attribution.network];
    [self addValueOrEmpty:dictionary key:@"campaign" value:attribution.campaign];
    [self addValueOrEmpty:dictionary key:@"creative" value:attribution.creative];
    [self addValueOrEmpty:dictionary key:@"adgroup" value:attribution.adgroup];
    [self addValueOrEmpty:dictionary key:@"clickLabel" value:attribution.clickLabel];
    [self addValueOrEmpty:dictionary key:@"adid" value:attribution.adid];
    [self addValueOrEmpty:dictionary key:@"costType" value:attribution.costType];
    [self addValueOrEmpty:dictionary key:@"costAmount" value:attribution.costAmount];
    [self addValueOrEmpty:dictionary key:@"costCurrency" value:attribution.costCurrency];
    [AlltrackEventEmitter dispatchEvent:@"alltrack_attribution" withDictionary:dictionary];
}

- (void)alltrackEventTrackingSucceededWannabe:(ALTEventSuccess *)eventSuccessResponseData {
    if (nil == eventSuccessResponseData) {
        return;
    }

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [self addValueOrEmpty:dictionary key:@"message" value:eventSuccessResponseData.message];
    [self addValueOrEmpty:dictionary key:@"timestamp" value:eventSuccessResponseData.timeStamp];
    [self addValueOrEmpty:dictionary key:@"adid" value:eventSuccessResponseData.adid];
    [self addValueOrEmpty:dictionary key:@"eventToken" value:eventSuccessResponseData.eventToken];
    [self addValueOrEmpty:dictionary key:@"callbackId" value:eventSuccessResponseData.callbackId];
    if (eventSuccessResponseData.jsonResponse != nil) {
        NSData *dataJsonResponse = [NSJSONSerialization dataWithJSONObject:eventSuccessResponseData.jsonResponse options:0 error:nil];
        NSString *stringJsonResponse = [[NSString alloc] initWithBytes:[dataJsonResponse bytes]
                                                                length:[dataJsonResponse length]
                                                              encoding:NSUTF8StringEncoding];
        [self addValueOrEmpty:dictionary key:@"jsonResponse" value:stringJsonResponse];
    }
    [AlltrackEventEmitter dispatchEvent:@"alltrack_eventTrackingSucceeded" withDictionary:dictionary];
}

- (void)alltrackEventTrackingFailedWannabe:(ALTEventFailure *)eventFailureResponseData {
    if (nil == eventFailureResponseData) {
        return;
    }

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [self addValueOrEmpty:dictionary key:@"message" value:eventFailureResponseData.message];
    [self addValueOrEmpty:dictionary key:@"timestamp" value:eventFailureResponseData.timeStamp];
    [self addValueOrEmpty:dictionary key:@"adid" value:eventFailureResponseData.adid];
    [self addValueOrEmpty:dictionary key:@"eventToken" value:eventFailureResponseData.eventToken];
    [self addValueOrEmpty:dictionary key:@"callbackId" value:eventFailureResponseData.callbackId];
    [dictionary setObject:(eventFailureResponseData.willRetry ? @"true" : @"false") forKey:@"willRetry"];
    if (eventFailureResponseData.jsonResponse != nil) {
        NSData *dataJsonResponse = [NSJSONSerialization dataWithJSONObject:eventFailureResponseData.jsonResponse options:0 error:nil];
        NSString *stringJsonResponse = [[NSString alloc] initWithBytes:[dataJsonResponse bytes]
                                                                length:[dataJsonResponse length]
                                                              encoding:NSUTF8StringEncoding];
        [self addValueOrEmpty:dictionary key:@"jsonResponse" value:stringJsonResponse];
    }
    [AlltrackEventEmitter dispatchEvent:@"alltrack_eventTrackingFailed" withDictionary:dictionary];
}


- (void)alltrackSessionTrackingSucceededWannabe:(ALTSessionSuccess *)sessionSuccessResponseData {
    if (nil == sessionSuccessResponseData) {
        return;
    }

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [self addValueOrEmpty:dictionary key:@"message" value:sessionSuccessResponseData.message];
    [self addValueOrEmpty:dictionary key:@"timestamp" value:sessionSuccessResponseData.timeStamp];
    [self addValueOrEmpty:dictionary key:@"adid" value:sessionSuccessResponseData.adid];
    if (sessionSuccessResponseData.jsonResponse != nil) {
        NSData *dataJsonResponse = [NSJSONSerialization dataWithJSONObject:sessionSuccessResponseData.jsonResponse options:0 error:nil];
        NSString *stringJsonResponse = [[NSString alloc] initWithBytes:[dataJsonResponse bytes]
                                                                length:[dataJsonResponse length]
                                                              encoding:NSUTF8StringEncoding];
        [self addValueOrEmpty:dictionary key:@"jsonResponse" value:stringJsonResponse];
    }
    [AlltrackEventEmitter dispatchEvent:@"alltrack_sessionTrackingSucceeded" withDictionary:dictionary];
}

- (void)alltrackSessionTrackingFailedWananbe:(ALTSessionFailure *)sessionFailureResponseData {
    if (nil == sessionFailureResponseData) {
        return;
    }

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [self addValueOrEmpty:dictionary key:@"message" value:sessionFailureResponseData.message];
    [self addValueOrEmpty:dictionary key:@"timestamp" value:sessionFailureResponseData.timeStamp];
    [self addValueOrEmpty:dictionary key:@"adid" value:sessionFailureResponseData.adid];
    [dictionary setObject:(sessionFailureResponseData.willRetry ? @"true" : @"false") forKey:@"willRetry"];
    if (sessionFailureResponseData.jsonResponse != nil) {
        NSData *dataJsonResponse = [NSJSONSerialization dataWithJSONObject:sessionFailureResponseData.jsonResponse options:0 error:nil];
        NSString *stringJsonResponse = [[NSString alloc] initWithBytes:[dataJsonResponse bytes]
                                                                length:[dataJsonResponse length]
                                                              encoding:NSUTF8StringEncoding];
        [self addValueOrEmpty:dictionary key:@"jsonResponse" value:stringJsonResponse];
    }
    [AlltrackEventEmitter dispatchEvent:@"alltrack_sessionTrackingFailed" withDictionary:dictionary];
}

- (BOOL)alltrackDeeplinkResponseWannabe:(NSURL *)deeplink {
    NSString *path = [deeplink absoluteString];
    [AlltrackEventEmitter dispatchEvent:@"alltrack_deferredDeeplink" withDictionary:@{@"uri": path}];
    return _shouldLaunchDeferredDeeplink;
}

- (void)alltrackConversionValueUpdatedWannabe:(NSNumber *)conversionValue {
    // NSString *strConversionValue = [conversionValue stringValue];
    [AlltrackEventEmitter dispatchEvent:@"alltrack_conversionValueUpdated" withDictionary:@{@"conversionValue": conversionValue}];
}


- (void)alltrackConversionValueUpdatedWannabe:(nullable NSNumber *)fineValue
                                coarseValue:(nullable NSString *)coarseValue
                                 lockWindow:(nullable NSNumber *)lockWindow {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [self addValueOrEmpty:dictionary key:@"fineValue" value:[fineValue stringValue]];
    [self addValueOrEmpty:dictionary key:@"coarseValue" value:coarseValue];
    [self addValueOrEmpty:dictionary key:@"lockWindow" value:[lockWindow stringValue]];
    [AlltrackEventEmitter dispatchEvent:@"alltrack_skad4ConversionValueUpdated" withDictionary:dictionary];
}

- (void)swizzleCallbackMethod:(SEL)originalSelector
             swizzledSelector:(SEL)swizzledSelector {
    Class class = [self class];
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
    BOOL didAddMethod = class_addMethod(class,
                                        originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));
    if (didAddMethod) {
        class_replaceMethod(class,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

- (void)addValueOrEmpty:(NSMutableDictionary *)dictionary
                    key:(NSString *)key
                  value:(NSObject *)value {
    if (nil != value) {
        [dictionary setObject:[NSString stringWithFormat:@"%@", value] forKey:key];
    } else {
        [dictionary setObject:@"" forKey:key];
    }
}

@end
