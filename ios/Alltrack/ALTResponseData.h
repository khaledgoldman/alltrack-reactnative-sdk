#import <Foundation/Foundation.h>

#import "ALTAttribution.h"
#import "ALTEventSuccess.h"
#import "ALTEventFailure.h"
#import "ALTSessionSuccess.h"
#import "ALTSessionFailure.h"
#import "ALTActivityPackage.h"

typedef NS_ENUM(int, ALTTrackingState) {
    ALTTrackingStateOptedOut = 1
};

@interface ALTResponseData : NSObject <NSCopying>

@property (nonatomic, assign) ALTActivityKind activityKind;

@property (nonatomic, copy) NSString *message;

@property (nonatomic, copy) NSString *timeStamp;

@property (nonatomic, copy) NSString *adid;

@property (nonatomic, assign) BOOL success;

@property (nonatomic, assign) BOOL willRetry;

@property (nonatomic, assign) ALTTrackingState trackingState;

@property (nonatomic, strong) NSDictionary *jsonResponse;

@property (nonatomic, copy) ALTAttribution *attribution;

@property (nonatomic, copy) NSDictionary *sendingParameters;

@property (nonatomic, strong) ALTActivityPackage *sdkClickPackage;

@property (nonatomic, strong) ALTActivityPackage *sdkPackage;

+ (id)buildResponseData:(ALTActivityPackage *)activityPackage;

@end

@interface ALTSessionResponseData : ALTResponseData

- (ALTSessionSuccess *)successResponseData;

- (ALTSessionFailure *)failureResponseData;

@end

@interface ALTSdkClickResponseData : ALTResponseData
@end

@interface ALTEventResponseData : ALTResponseData

@property (nonatomic, copy) NSString *eventToken;

@property (nonatomic, copy) NSString *callbackId;

- (ALTEventSuccess *)successResponseData;

- (ALTEventFailure *)failureResponseData;

- (id)initWithEventToken:(NSString *)eventToken
              callbackId:(NSString *)callbackId;

@end

@interface ALTAttributionResponseData : ALTResponseData

@property (nonatomic, strong) NSURL *deeplink;

@end
