#import "ALTResponseData.h"
#import "ALTActivityKind.h"

@implementation ALTResponseData

- (id)init
{
    self = [super init];
    
    if (self == nil) {
        return nil;
    }

    return self;
}

+ (ALTResponseData *)responseData {
    return [[ALTResponseData alloc] init];
}

+ (id)buildResponseData:(ALTActivityPackage *)activityPackage {
    ALTActivityKind activityKind;
    
    if (activityPackage == nil) {
        activityKind = ALTActivityKindUnknown;
    } else {
        activityKind = activityPackage.activityKind;
    }

    ALTResponseData *responseData = nil;

    switch (activityKind) {
        case ALTActivityKindSession:
            responseData = [[ALTSessionResponseData alloc] init];
            break;
        case ALTActivityKindClick:
            responseData = [[ALTSdkClickResponseData alloc] init];
            responseData.sdkClickPackage = activityPackage;
            break;
        case ALTActivityKindEvent:
            responseData = [[ALTEventResponseData alloc]
                                initWithEventToken:
                                    [activityPackage.parameters
                                        objectForKey:@"event_token"]
                                callbackId:
                                    [activityPackage.parameters
                                        objectForKey:@"event_callback_id"]];
            break;
        case ALTActivityKindAttribution:
            responseData = [[ALTAttributionResponseData alloc] init];
            break;
        default:
            responseData = [[ALTResponseData alloc] init];
            break;
    }

    responseData.sdkPackage = activityPackage;
    responseData.activityKind = activityKind;

    return responseData;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"message:%@ timestamp:%@ adid:%@ success:%d willRetry:%d attribution:%@ trackingState:%d, json:%@",
            self.message, self.timeStamp, self.adid, self.success, self.willRetry, self.attribution, self.trackingState, self.jsonResponse];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    ALTResponseData* copy = [[[self class] allocWithZone:zone] init];

    if (copy) {
        copy.message = [self.message copyWithZone:zone];
        copy.timeStamp = [self.timeStamp copyWithZone:zone];
        copy.adid = [self.adid copyWithZone:zone];
        copy.willRetry = self.willRetry;
        copy.trackingState = self.trackingState;
        copy.jsonResponse = [self.jsonResponse copyWithZone:zone];
        copy.attribution = [self.attribution copyWithZone:zone];
    }

    return copy;
}

@end

@implementation ALTSessionResponseData

- (ALTSessionSuccess *)successResponseData {
    ALTSessionSuccess *successResponseData = [ALTSessionSuccess sessionSuccessResponseData];

    successResponseData.message = self.message;
    successResponseData.timeStamp = self.timeStamp;
    successResponseData.adid = self.adid;
    successResponseData.jsonResponse = self.jsonResponse;

    return successResponseData;
}

- (ALTSessionFailure *)failureResponseData {
    ALTSessionFailure *failureResponseData = [ALTSessionFailure sessionFailureResponseData];

    failureResponseData.message = self.message;
    failureResponseData.timeStamp = self.timeStamp;
    failureResponseData.adid = self.adid;
    failureResponseData.willRetry = self.willRetry;
    failureResponseData.jsonResponse = self.jsonResponse;

    return failureResponseData;
}

- (id)copyWithZone:(NSZone *)zone {
    ALTSessionResponseData* copy = [super copyWithZone:zone];
    return copy;
}

@end

@implementation ALTSdkClickResponseData

@end

@implementation ALTEventResponseData

- (id)initWithEventToken:(NSString *)eventToken
       callbackId:(NSString *)callbackId
{
    self = [super init];
    
    if (self == nil) {
        return nil;
    }

    self.eventToken = eventToken;
    self.callbackId = callbackId;

    return self;
}

- (ALTEventSuccess *)successResponseData {
    ALTEventSuccess *successResponseData = [ALTEventSuccess eventSuccessResponseData];

    successResponseData.message = self.message;
    successResponseData.timeStamp = self.timeStamp;
    successResponseData.adid = self.adid;
    successResponseData.eventToken = self.eventToken;
    successResponseData.callbackId = self.callbackId;
    successResponseData.jsonResponse = self.jsonResponse;

    return successResponseData;
}

- (ALTEventFailure *)failureResponseData {
    ALTEventFailure *failureResponseData = [ALTEventFailure eventFailureResponseData];

    failureResponseData.message = self.message;
    failureResponseData.timeStamp = self.timeStamp;
    failureResponseData.adid = self.adid;
    failureResponseData.eventToken = self.eventToken;
    failureResponseData.callbackId = self.callbackId;
    failureResponseData.willRetry = self.willRetry;
    failureResponseData.jsonResponse = self.jsonResponse;

    return failureResponseData;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"message:%@ timestamp:%@ adid:%@ eventToken:%@ success:%d willRetry:%d attribution:%@ json:%@",
            self.message, self.timeStamp, self.adid, self.eventToken, self.success, self.willRetry, self.attribution, self.jsonResponse];
}

- (id)copyWithZone:(NSZone *)zone {
    ALTEventResponseData *copy = [super copyWithZone:zone];

    if (copy) {
        copy.eventToken = [self.eventToken copyWithZone:zone];
    }

    return copy;
}

@end

@implementation ALTAttributionResponseData

- (id)copyWithZone:(NSZone *)zone {
    ALTAttributionResponseData *copy = [super copyWithZone:zone];
    
    return copy;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"message:%@ timestamp:%@ adid:%@ success:%d willRetry:%d attribution:%@ deeplink:%@ json:%@",
            self.message, self.timeStamp, self.adid, self.success, self.willRetry, self.attribution, self.deeplink, self.jsonResponse];
}

@end

