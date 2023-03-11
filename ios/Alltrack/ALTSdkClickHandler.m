#import "ALTUtil.h"
#import "ALTLogger.h"
#import "ALTAlltrackFactory.h"
#import "ALTSdkClickHandler.h"
#import "ALTBackoffStrategy.h"
#import "ALTUserDefaults.h"
#import "ALTPackageBuilder.h"

static const char * const kInternalQueueName = "com.alltrack.SdkClickQueue";

@interface ALTSdkClickHandler()

@property (nonatomic, strong) NSMutableArray *packageQueue;
@property (nonatomic, strong) dispatch_queue_t internalQueue;
@property (nonatomic, strong) ALTRequestHandler *requestHandler;

@property (nonatomic, assign) BOOL paused;
@property (nonatomic, strong) ALTBackoffStrategy *backoffStrategy;

@property (nonatomic, weak) id<ALTLogger> logger;
@property (nonatomic, weak) id<ALTActivityHandler> activityHandler;

@property (nonatomic, assign) NSInteger lastPackageRetriesCount;

@end

@implementation ALTSdkClickHandler

#pragma mark - Public instance methods

- (id)initWithActivityHandler:(id<ALTActivityHandler>)activityHandler
                startsSending:(BOOL)startsSending
                    userAgent:(NSString *)userAgent
                  urlStrategy:(ALTUrlStrategy *)urlStrategy
{
    self = [super init];
    if (self == nil) {
        return nil;
    }

    self.internalQueue = dispatch_queue_create(kInternalQueueName, DISPATCH_QUEUE_SERIAL);
    self.logger = ALTAlltrackFactory.logger;
    self.lastPackageRetriesCount = 0;

    self.requestHandler = [[ALTRequestHandler alloc]
                           initWithResponseCallback:self
                           urlStrategy:urlStrategy
                           userAgent:userAgent
                           requestTimeout:[ALTAlltrackFactory requestTimeout]];

    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTSdkClickHandler *selfI) {
                         [selfI initI:selfI
                      activityHandler:activityHandler
                        startsSending:startsSending];
                     }];
    return self;
}

- (void)pauseSending {
    self.paused = YES;
}

- (void)resumeSending {
    self.paused = NO;
    [self sendNextSdkClick];
}

- (void)sendSdkClick:(ALTActivityPackage *)sdkClickPackage {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTSdkClickHandler *selfI) {
                         [selfI sendSdkClickI:selfI sdkClickPackage:sdkClickPackage];
                     }];
}

- (void)sendNextSdkClick {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTSdkClickHandler *selfI) {
                         [selfI sendNextSdkClickI:selfI];
                     }];
}

- (void)teardown {
    [ALTAlltrackFactory.logger verbose:@"ALTSdkClickHandler teardown"];

    if (self.packageQueue != nil) {
        [self.packageQueue removeAllObjects];
    }

    self.internalQueue = nil;
    self.logger = nil;
    self.backoffStrategy = nil;
    self.packageQueue = nil;
    self.activityHandler = nil;
}

#pragma mark - Private & helper methods

-   (void)initI:(ALTSdkClickHandler *)selfI
activityHandler:(id<ALTActivityHandler>)activityHandler
  startsSending:(BOOL)startsSending {
    selfI.activityHandler = activityHandler;
    selfI.paused = !startsSending;
    selfI.backoffStrategy = [ALTAlltrackFactory sdkClickHandlerBackoffStrategy];
    selfI.packageQueue = [NSMutableArray array];
}

- (void)sendSdkClickI:(ALTSdkClickHandler *)selfI
      sdkClickPackage:(ALTActivityPackage *)sdkClickPackage {
    [selfI.packageQueue addObject:sdkClickPackage];
    [selfI.logger debug:@"Added sdk_click %d", selfI.packageQueue.count];
    [selfI.logger verbose:@"%@", sdkClickPackage.extendedString];
    [selfI sendNextSdkClick];
}

- (void)sendNextSdkClickI:(ALTSdkClickHandler *)selfI {
    if (selfI.paused) {
        return;
    }
    NSUInteger queueSize = selfI.packageQueue.count;
    if (queueSize == 0) {
        return;
    }
    if ([selfI.activityHandler isGdprForgotten]) {
        [selfI.logger debug:@"sdk_click request won't be fired for forgotten user"];
        return;
    }

    ALTActivityPackage *sdkClickPackage = [self.packageQueue objectAtIndex:0];
    [self.packageQueue removeObjectAtIndex:0];

    if (![sdkClickPackage isKindOfClass:[ALTActivityPackage class]]) {
        [selfI.logger error:@"Failed to read sdk_click package"];
        [selfI sendNextSdkClick];
        return;
    }
    
    if ([ALTPackageBuilder isAdServicesPackage:sdkClickPackage]) {
        // refresh token
        NSString *token = [ALTUtil fetchAdServicesAttribution:nil];
        
        if (token != nil && ![sdkClickPackage.parameters[ALTAttributionTokenParameter] isEqualToString:token]) {
            // update token
            [ALTPackageBuilder parameters:sdkClickPackage.parameters
                                setString:token
                                   forKey:ALTAttributionTokenParameter];
            
            // update created_at
            [ALTPackageBuilder parameters:sdkClickPackage.parameters
                              setDate1970:[NSDate.date timeIntervalSince1970]
                                   forKey:@"created_at"];
        }
    }

    dispatch_block_t work = ^{
        NSDictionary *sendingParameters = @{
            @"sent_at": [ALTUtil formatSeconds1970:[NSDate.date timeIntervalSince1970]]
        };

        [selfI.requestHandler sendPackageByPOST:sdkClickPackage
                              sendingParameters:sendingParameters];

        [selfI sendNextSdkClick];
    };

    if (selfI.lastPackageRetriesCount <= 0) {
        work();
        return;
    }

    NSTimeInterval waitTime = [ALTUtil waitingTime:selfI.lastPackageRetriesCount backoffStrategy:self.backoffStrategy];
    NSString *waitTimeFormatted = [ALTUtil secondsNumberFormat:waitTime];

    [self.logger verbose:@"Waiting for %@ seconds before retrying sdk_click for the %d time", waitTimeFormatted, selfI.lastPackageRetriesCount];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(waitTime * NSEC_PER_SEC)), self.internalQueue, work);
}

- (void)responseCallback:(ALTResponseData *)responseData {
    if (responseData.jsonResponse) {
        [self.logger debug:
            @"Got click JSON response with message: %@", responseData.message];
    } else {
        [self.logger error:
            @"Could not get click JSON response with message: %@", responseData.message];
    }
    // Check if any package response contains information that user has opted out.
    // If yes, disable SDK and flush any potentially stored packages that happened afterwards.
    if (responseData.trackingState == ALTTrackingStateOptedOut) {
        self.lastPackageRetriesCount = 0;
        [self.activityHandler setTrackingStateOptedOut];
        return;
    }
    if (responseData.jsonResponse == nil) {
        self.lastPackageRetriesCount++;
        [self.logger error:@"Retrying sdk_click package for the %d time", self.lastPackageRetriesCount];
        [self sendSdkClick:responseData.sdkClickPackage];
        return;
    }
    self.lastPackageRetriesCount = 0;
    
    if ([responseData.sdkClickPackage.parameters.allValues containsObject:ALTiAdPackageKey]) {
        // received iAd click package response, clear the errors from UserDefaults
        [ALTUserDefaults cleariAdErrors];
        [self.logger info:@"Received iAd click response"];
    }
    
    if ([ALTPackageBuilder isAdServicesPackage:responseData.sdkClickPackage]) {
        // set as tracked
        [ALTUserDefaults setAdServicesTracked];
        [self.logger info:@"Received Apple Ads click response"];
    }

    [self.activityHandler finishedTracking:responseData];
}

@end
