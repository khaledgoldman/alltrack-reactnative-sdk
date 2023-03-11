#import "ALTPackageHandler.h"
#import "ALTActivityPackage.h"
#import "ALTLogger.h"
#import "ALTUtil.h"
#import "ALTAlltrackFactory.h"
#import "ALTBackoffStrategy.h"
#import "ALTPackageBuilder.h"
#import "ALTUserDefaults.h"

static NSString   * const kPackageQueueFilename = @"AlltrackIoPackageQueue";
static const char * const kInternalQueueName    = "io.alltrack.PackageQueue";


#pragma mark - private
@interface ALTPackageHandler()

@property (nonatomic, strong) dispatch_queue_t internalQueue;
@property (nonatomic, strong) dispatch_semaphore_t sendingSemaphore;
@property (nonatomic, strong) ALTRequestHandler *requestHandler;
@property (nonatomic, strong) NSMutableArray *packageQueue;
@property (nonatomic, strong) ALTBackoffStrategy *backoffStrategy;
@property (nonatomic, strong) ALTBackoffStrategy *backoffStrategyForInstallSession;
@property (nonatomic, assign) BOOL paused;
@property (nonatomic, weak) id<ALTActivityHandler> activityHandler;
@property (nonatomic, weak) id<ALTLogger> logger;
@property (nonatomic, assign) NSInteger lastPackageRetriesCount;

@end

#pragma mark -
@implementation ALTPackageHandler

- (id)initWithActivityHandler:(id<ALTActivityHandler>)activityHandler
                startsSending:(BOOL)startsSending
                    userAgent:(NSString *)userAgent
                  urlStrategy:(ALTUrlStrategy *)urlStrategy
{
    self = [super init];
    if (self == nil) return nil;

    self.internalQueue = dispatch_queue_create(kInternalQueueName, DISPATCH_QUEUE_SERIAL);
    self.backoffStrategy = [ALTAlltrackFactory packageHandlerBackoffStrategy];
    self.backoffStrategyForInstallSession = [ALTAlltrackFactory installSessionBackoffStrategy];
    self.lastPackageRetriesCount = 0;

    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTPackageHandler * selfI) {
                         [selfI initI:selfI
                     activityHandler:activityHandler
                       startsSending:startsSending
                          userAgent:userAgent
                          urlStrategy:urlStrategy];
                     }];

    return self;
}

- (void)addPackage:(ALTActivityPackage *)package {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTPackageHandler* selfI) {
                         [selfI addI:selfI package:package];
                     }];
}

- (void)sendFirstPackage {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTPackageHandler* selfI) {
                         [selfI sendFirstI:selfI];
                     }];
}

- (void)responseCallback:(ALTResponseData *)responseData {
    if (responseData.jsonResponse) {
        [self.logger debug:@"Got JSON response with message: %@", responseData.message];
    } else {
        [self.logger error:@"Could not get JSON response with message: %@", responseData.message];
    }
    // Check if any package response contains information that user has opted out.
    // If yes, disable SDK and flush any potentially stored packages that happened afterwards.
    if (responseData.trackingState == ALTTrackingStateOptedOut) {
        [self.activityHandler setTrackingStateOptedOut];
        return;
    }
    if (responseData.jsonResponse == nil) {
        [self closeFirstPackage:responseData];
    } else {
        [self sendNextPackage:responseData];
    }
}

- (void)sendNextPackage:(ALTResponseData *)responseData {
    self.lastPackageRetriesCount = 0;

    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTPackageHandler* selfI) {
                         [selfI sendNextI:selfI];
                     }];

    [self.activityHandler finishedTracking:responseData];
}

- (void)closeFirstPackage:(ALTResponseData *)responseData
{
    responseData.willRetry = YES;
    [self.activityHandler finishedTracking:responseData];

    self.lastPackageRetriesCount++;

    NSTimeInterval waitTime;
    if (responseData.activityKind == ALTActivityKindSession && [ALTUserDefaults getInstallTracked] == NO) {
        waitTime = [ALTUtil waitingTime:self.lastPackageRetriesCount backoffStrategy:self.backoffStrategyForInstallSession];
    } else {
        waitTime = [ALTUtil waitingTime:self.lastPackageRetriesCount backoffStrategy:self.backoffStrategy];
    }
    NSString *waitTimeFormatted = [ALTUtil secondsNumberFormat:waitTime];

    [self.logger verbose:@"Waiting for %@ seconds before retrying the %d time", waitTimeFormatted, self.lastPackageRetriesCount];
    dispatch_after
        (dispatch_time(DISPATCH_TIME_NOW, (int64_t)(waitTime * NSEC_PER_SEC)),
         self.internalQueue,
         ^{
            [self.logger verbose:@"Package handler finished waiting"];

            dispatch_semaphore_signal(self.sendingSemaphore);

            [self sendFirstPackage];
        });
}

- (void)pauseSending {
    self.paused = YES;
}

- (void)resumeSending {
    self.paused = NO;
}

- (void)updatePackages:(ALTSessionParameters *)sessionParameters
{
    // make copy to prevent possible Activity Handler changes of it
    ALTSessionParameters * sessionParametersCopy = [sessionParameters copy];

    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTPackageHandler* selfI) {
                         [selfI updatePackagesI:selfI sessionParameters:sessionParametersCopy];
                     }];
}

- (void)flush {
    [ALTUtil launchInQueue:self.internalQueue selfInject:self block:^(ALTPackageHandler *selfI) {
        [selfI flushI:selfI];
    }];
}

- (void)teardown {
    [ALTAlltrackFactory.logger verbose:@"ALTPackageHandler teardown"];
    if (self.sendingSemaphore != nil) {
        dispatch_semaphore_signal(self.sendingSemaphore);
    }
    [self teardownPackageQueueS];
    self.internalQueue = nil;
    self.sendingSemaphore = nil;
    self.requestHandler = nil;
    self.backoffStrategy = nil;
    self.activityHandler = nil;
    self.logger = nil;
}

+ (void)deleteState {
    [ALTPackageHandler deletePackageQueue];
}

+ (void)deletePackageQueue {
    [ALTUtil deleteFileWithName:kPackageQueueFilename];
}

#pragma mark - internal
- (void)
    initI:(ALTPackageHandler *)selfI
        activityHandler:(id<ALTActivityHandler>)activityHandler
        startsSending:(BOOL)startsSending
        userAgent:(NSString *)userAgent
        urlStrategy:(ALTUrlStrategy *)urlStrategy
{
    selfI.activityHandler = activityHandler;
    selfI.paused = !startsSending;
    selfI.requestHandler = [[ALTRequestHandler alloc]
                                initWithResponseCallback:self
                                urlStrategy:urlStrategy
                                userAgent:userAgent
                                requestTimeout:[ALTAlltrackFactory requestTimeout]];
    selfI.logger = ALTAlltrackFactory.logger;
    selfI.sendingSemaphore = dispatch_semaphore_create(1);
    [selfI readPackageQueueI:selfI];
}

- (void)addI:(ALTPackageHandler *)selfI
     package:(ALTActivityPackage *)newPackage
{
    [selfI.packageQueue addObject:newPackage];

    [selfI.logger debug:@"Added package %d (%@)", selfI.packageQueue.count, newPackage];
    [selfI.logger verbose:@"%@", newPackage.extendedString];

    [selfI writePackageQueueS:selfI];
}

- (void)sendFirstI:(ALTPackageHandler *)selfI
{
    NSUInteger queueSize = selfI.packageQueue.count;
    if (queueSize == 0) return;

    if (selfI.paused) {
        [selfI.logger debug:@"Package handler is paused"];
        return;
    }

    if (dispatch_semaphore_wait(selfI.sendingSemaphore, DISPATCH_TIME_NOW) != 0) {
        [selfI.logger verbose:@"Package handler is already sending"];
        return;
    }

    ALTActivityPackage *activityPackage = [selfI.packageQueue objectAtIndex:0];
    if (![activityPackage isKindOfClass:[ALTActivityPackage class]]) {
        [selfI.logger error:@"Failed to read activity package"];
        [selfI sendNextI:selfI];
        return;
    }

    NSMutableDictionary *sendingParameters = [NSMutableDictionary dictionaryWithCapacity:2];
    if (queueSize - 1 > 0) {
        [ALTPackageBuilder parameters:sendingParameters
                               setInt:(int)queueSize - 1
                               forKey:@"queue_size"];
    }
    [ALTPackageBuilder parameters:sendingParameters
                        setString:[ALTUtil formatSeconds1970:[NSDate.date timeIntervalSince1970]]
                           forKey:@"sent_at"];

    [selfI.requestHandler sendPackageByPOST:activityPackage
                          sendingParameters:[sendingParameters copy]];
}

- (void)sendNextI:(ALTPackageHandler *)selfI {
    if ([selfI.packageQueue count] > 0) {
        [selfI.packageQueue removeObjectAtIndex:0];
        [selfI writePackageQueueS:selfI];
    }

    dispatch_semaphore_signal(selfI.sendingSemaphore);
    [selfI sendFirstI:selfI];
}

- (void)updatePackagesI:(ALTPackageHandler *)selfI
      sessionParameters:(ALTSessionParameters *)sessionParameters
{
    [selfI.logger debug:@"Updating package handler queue"];
    [selfI.logger verbose:@"Session callback parameters: %@", sessionParameters.callbackParameters];
    [selfI.logger verbose:@"Session partner parameters: %@", sessionParameters.partnerParameters];

    for (ALTActivityPackage * activityPackage in selfI.packageQueue) {
        // callback parameters
        NSDictionary * mergedCallbackParameters = [ALTUtil mergeParameters:sessionParameters.callbackParameters
                                                                    source:activityPackage.callbackParameters
                                                             parameterName:@"Callback"];

        [ALTPackageBuilder parameters:activityPackage.parameters
                        setDictionary:mergedCallbackParameters
                               forKey:@"callback_params"];

        // partner parameters
        NSDictionary * mergedPartnerParameters = [ALTUtil mergeParameters:sessionParameters.partnerParameters
                                                                   source:activityPackage.partnerParameters
                                                            parameterName:@"Partner"];

        [ALTPackageBuilder parameters:activityPackage.parameters
                        setDictionary:mergedPartnerParameters
                               forKey:@"partner_params"];
    }

    [selfI writePackageQueueS:selfI];
}

- (void)flushI:(ALTPackageHandler *)selfI {
    [selfI.packageQueue removeAllObjects];
    [selfI writePackageQueueS:selfI];
}

#pragma mark - private
- (void)readPackageQueueI:(ALTPackageHandler *)selfI {
    [NSKeyedUnarchiver setClass:[ALTActivityPackage class] forClassName:@"AIActivityPackage"];
    
    id object = [ALTUtil readObject:kPackageQueueFilename
                         objectName:@"Package queue"
                              class:[NSArray class]
                         syncObject:[ALTPackageHandler class]];
    
    if (object != nil) {
        selfI.packageQueue = object;
    } else {
        selfI.packageQueue = [NSMutableArray array];
    }

}

- (void)writePackageQueueS:(ALTPackageHandler *)selfS {
    if (selfS.packageQueue == nil) {
        return;
    }
    
    [ALTUtil writeObject:selfS.packageQueue
                fileName:kPackageQueueFilename
              objectName:@"Package queue"
              syncObject:[ALTPackageHandler class]];
}

- (void)teardownPackageQueueS {
    @synchronized ([ALTPackageHandler class]) {
        if (self.packageQueue == nil) {
            return;
        }
        
        [self.packageQueue removeAllObjects];
        self.packageQueue = nil;
    }
}

- (void)dealloc {
    // Cleanup code
    if (self.sendingSemaphore != nil) {
        dispatch_semaphore_signal(self.sendingSemaphore);
    }
}

@end
