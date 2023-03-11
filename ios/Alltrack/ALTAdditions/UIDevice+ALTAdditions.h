#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "ALTDeviceInfo.h"
#import "ALTActivityHandler.h"

@interface UIDevice(ALTAdditions)

- (int)altATTStatus;
- (BOOL)altTrackingEnabled;
- (NSString *)altIdForAdvertisers;
- (NSString *)altFbAnonymousId;
- (NSString *)altDeviceType;
- (NSString *)altDeviceName;
- (NSString *)altCreateUuid;
- (NSString *)altVendorId;
- (void)altCheckForiAd:(ALTActivityHandler *)activityHandler queue:(dispatch_queue_t)queue;
- (NSString *)altFetchAdServicesAttribution:(NSError **)errorPtr;

- (void)requestTrackingAuthorizationWithCompletionHandler:(void (^)(NSUInteger status))completion;

@end
