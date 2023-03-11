#import "AlltrackEventEmitter.h"

@implementation AlltrackEventEmitter

RCT_EXPORT_MODULE();

+ (id)allocWithZone:(NSZone *)zone {
    static AlltrackEventEmitter *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedInstance = [super allocWithZone:zone];
    });

    return sharedInstance;
}

- (NSArray<NSString *> *)supportedEvents {
    return @[@"alltrack_attribution",
             @"alltrack_eventTrackingSucceeded",
             @"alltrack_eventTrackingFailed",
             @"alltrack_sessionTrackingSucceeded",
             @"alltrack_sessionTrackingFailed",
             @"alltrack_deferredDeeplink",
             @"alltrack_conversionValueUpdated",
             @"alltrack_skad4ConversionValueUpdated"];
}

- (void)startObserving {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    for (NSString *notificationName in [self supportedEvents]) {
        [center addObserver:self
                   selector:@selector(emitEventInternal:)
                       name:notificationName
                     object:nil];
    }
}

- (void)stopObserving {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)emitEventInternal:(NSNotification *)notification {
    [self sendEventWithName:notification.name
                       body:notification.userInfo];
}

+ (void)dispatchEvent:(NSString *)eventName withDictionary:(NSDictionary *)dictionary {
    [[NSNotificationCenter defaultCenter] postNotificationName:eventName
                                                        object:self
                                                      userInfo:dictionary];
}

@end
