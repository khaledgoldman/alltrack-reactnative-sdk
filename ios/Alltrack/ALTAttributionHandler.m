#import "ALTAttributionHandler.h"
#import "ALTAlltrackFactory.h"
#import "ALTUtil.h"
#import "ALTActivityHandler.h"
#import "NSString+ALTAdditions.h"
#import "ALTTimerOnce.h"
#import "ALTPackageBuilder.h"
#import "ALTUtil.h"

static const char * const kInternalQueueName     = "com.alltrack.AttributionQueue";
static NSString   * const kAttributionTimerName   = @"Attribution timer";

@interface ALTAttributionHandler()

@property (nonatomic, strong) dispatch_queue_t internalQueue;
@property (nonatomic, strong) ALTRequestHandler *requestHandler;
@property (nonatomic, weak) id<ALTActivityHandler> activityHandler;
@property (nonatomic, weak) id<ALTLogger> logger;
@property (nonatomic, strong) ALTTimerOnce *attributionTimer;
@property (atomic, assign) BOOL paused;
@property (nonatomic, copy) NSString *lastInitiatedBy;

@end

@implementation ALTAttributionHandler
- (id)initWithActivityHandler:(id<ALTActivityHandler>) activityHandler
                startsSending:(BOOL)startsSending
                    userAgent:(NSString *)userAgent
                  urlStrategy:(ALTUrlStrategy *)urlStrategy
{
    self = [super init];
    if (self == nil) return nil;

    self.internalQueue = dispatch_queue_create(kInternalQueueName, DISPATCH_QUEUE_SERIAL);
    self.requestHandler = [[ALTRequestHandler alloc]
                                initWithResponseCallback:self
                                urlStrategy:urlStrategy
                                userAgent:userAgent
                                requestTimeout:[ALTAlltrackFactory requestTimeout]];
    self.activityHandler = activityHandler;
    self.logger = ALTAlltrackFactory.logger;
    self.paused = !startsSending;
    __weak __typeof__(self) weakSelf = self;
    self.attributionTimer = [ALTTimerOnce timerWithBlock:^{
        __typeof__(self) strongSelf = weakSelf;
        if (strongSelf == nil) return;

        [strongSelf requestAttributionI:strongSelf];
    }
                                                   queue:self.internalQueue
                                                    name:kAttributionTimerName];

    return self;
}

- (void)checkSessionResponse:(ALTSessionResponseData *)sessionResponseData {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTAttributionHandler* selfI) {
                         [selfI checkSessionResponseI:selfI
                                  sessionResponseData:sessionResponseData];
                     }];
}

- (void)checkSdkClickResponse:(ALTSdkClickResponseData *)sdkClickResponseData {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTAttributionHandler* selfI) {
                         [selfI checkSdkClickResponseI:selfI
                                  sdkClickResponseData:sdkClickResponseData];
                     }];
}

- (void)checkAttributionResponse:(ALTAttributionResponseData *)attributionResponseData {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTAttributionHandler* selfI) {
                         [selfI checkAttributionResponseI:selfI
                                  attributionResponseData:attributionResponseData];

                     }];
}

- (void)getAttribution {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTAttributionHandler* selfI) {
                         selfI.lastInitiatedBy = @"sdk";
                         [selfI waitRequestAttributionWithDelayI:selfI
                                               milliSecondsDelay:0];

                     }];
}

- (void)pauseSending {
    self.paused = YES;
}

- (void)resumeSending {
    self.paused = NO;
}

#pragma mark - internal
- (void)checkSessionResponseI:(ALTAttributionHandler*)selfI
          sessionResponseData:(ALTSessionResponseData *)sessionResponseData {
    [selfI checkAttributionI:selfI responseData:sessionResponseData];
    
    [selfI.activityHandler launchSessionResponseTasks:sessionResponseData];
}

- (void)checkSdkClickResponseI:(ALTAttributionHandler*)selfI
          sdkClickResponseData:(ALTSdkClickResponseData *)sdkClickResponseData {
    [selfI checkAttributionI:selfI responseData:sdkClickResponseData];
    
    [selfI.activityHandler launchSdkClickResponseTasks:sdkClickResponseData];
}

- (void)checkAttributionResponseI:(ALTAttributionHandler*)selfI
                  attributionResponseData:(ALTAttributionResponseData *)attributionResponseData {
    [selfI checkAttributionI:selfI responseData:attributionResponseData];

    [selfI checkDeeplinkI:selfI attributionResponseData:attributionResponseData];
    
    [selfI.activityHandler launchAttributionResponseTasks:attributionResponseData];
}

- (void)checkAttributionI:(ALTAttributionHandler*)selfI
             responseData:(ALTResponseData *)responseData {
    if (responseData.jsonResponse == nil) {
        return;
    }

    NSNumber *timerMilliseconds = [responseData.jsonResponse objectForKey:@"ask_in"];

    if (timerMilliseconds != nil) {
        [selfI.activityHandler setAskingAttribution:YES];

        selfI.lastInitiatedBy = @"backend";
        [selfI waitRequestAttributionWithDelayI:selfI
                              milliSecondsDelay:[timerMilliseconds intValue]];

        return;
    }

    [selfI.activityHandler setAskingAttribution:NO];

    NSDictionary * jsonAttribution = [responseData.jsonResponse objectForKey:@"attribution"];
    responseData.attribution = [ALTAttribution dataWithJsonDict:jsonAttribution adid:responseData.adid];
}

- (void)checkDeeplinkI:(ALTAttributionHandler*)selfI
attributionResponseData:(ALTAttributionResponseData *)attributionResponseData {
    if (attributionResponseData.jsonResponse == nil) {
        return;
    }

    NSDictionary * jsonAttribution = [attributionResponseData.jsonResponse objectForKey:@"attribution"];
    if (jsonAttribution == nil) {
        return;
    }

    NSString *deepLink = [jsonAttribution objectForKey:@"deeplink"];
    if (deepLink == nil) {
        return;
    }

    attributionResponseData.deeplink = [NSURL URLWithString:deepLink];
}

- (void)requestAttributionI:(ALTAttributionHandler*)selfI {
    if (selfI.paused) {
        [selfI.logger debug:@"Attribution handler is paused"];
        return;
    }
    if ([selfI.activityHandler isGdprForgotten]) {
        [selfI.logger debug:@"Attribution request won't be fired for forgotten user"];
        return;
    }

    ALTActivityPackage* attributionPackage = [selfI buildAndGetAttributionPackageI:selfI];

    [selfI.logger verbose:@"%@", attributionPackage.extendedString];

    NSDictionary *sendingParameters = @{
        @"sent_at": [ALTUtil formatSeconds1970:[NSDate.date timeIntervalSince1970]]
    };

    [selfI.requestHandler sendPackageByGET:attributionPackage
                        sendingParameters:sendingParameters];
}

- (void)responseCallback:(ALTResponseData *)responseData {
    if (responseData.jsonResponse) {
        [self.logger debug:
            @"Got attribution JSON response with message: %@", responseData.message];
    } else {
        [self.logger error:
            @"Could not get attribution JSON response with message: %@", responseData.message];
    }

    // Check if any package response contains information that user has opted out.
    // If yes, disable SDK and flush any potentially stored packages that happened afterwards.
    if (responseData.trackingState == ALTTrackingStateOptedOut) {
        [self.activityHandler setTrackingStateOptedOut];
        return;
    }

    if ([responseData isKindOfClass:[ALTAttributionResponseData class]]) {
        [self checkAttributionResponse:(ALTAttributionResponseData*)responseData];
    }
}

- (void)waitRequestAttributionWithDelayI:(ALTAttributionHandler*)selfI
                       milliSecondsDelay:(int)milliSecondsDelay {
    NSTimeInterval secondsDelay = milliSecondsDelay / 1000;
    NSTimeInterval nextAskIn = [selfI.attributionTimer fireIn];
    if (nextAskIn > secondsDelay) {
        return;
    }

    if (milliSecondsDelay > 0) {
        [selfI.logger debug:@"Waiting to query attribution in %d milliseconds", milliSecondsDelay];
    }

    // set the new time the timer will fire in
    [selfI.attributionTimer startIn:secondsDelay];
}

- (ALTActivityPackage *)buildAndGetAttributionPackageI:(ALTAttributionHandler*)selfI
{
    double now = [NSDate.date timeIntervalSince1970];

    ALTPackageBuilder *attributionBuilder = [[ALTPackageBuilder alloc]
                                             initWithPackageParams:selfI.activityHandler.packageParams
                                             activityState:selfI.activityHandler.activityState
                                             config:selfI.activityHandler.alltrackConfig
                                             sessionParameters:selfI.activityHandler.sessionParameters
                                             trackingStatusManager:selfI.activityHandler.trackingStatusManager
                                             createdAt:now];
    ALTActivityPackage *attributionPackage = [attributionBuilder buildAttributionPackage:selfI.lastInitiatedBy];

    selfI.lastInitiatedBy = nil;

    return attributionPackage;
}

#pragma mark - private

- (void)teardown {
    [ALTAlltrackFactory.logger verbose:@"ALTAttributionHandler teardown"];

    if (self.attributionTimer != nil) {
        [self.attributionTimer cancel];
    }
    self.internalQueue = nil;
    self.activityHandler = nil;
    self.logger = nil;
    self.attributionTimer = nil;
    self.requestHandler = nil;
}

@end
