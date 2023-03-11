#import <UIKit/UIKit.h>

#import "ALTActivityPackage.h"
#import "ALTActivityHandler.h"
#import "ALTPackageBuilder.h"
#import "ALTPackageHandler.h"
#import "ALTLogger.h"
#import "ALTTimerCycle.h"
#import "ALTTimerOnce.h"
#import "ALTUtil.h"
#import "ALTAlltrackFactory.h"
#import "ALTAttributionHandler.h"
#import "NSString+ALTAdditions.h"
#import "ALTSdkClickHandler.h"
#import "ALTUserDefaults.h"
#import "ALTUrlStrategy.h"
#import "ALTSKAdNetwork.h"

NSString * const ALTiAdPackageKey = @"iad3";
NSString * const ALTAdServicesPackageKey = @"apple_ads";

typedef void (^activityHandlerBlockI)(ALTActivityHandler * activityHandler);

static NSString   * const kActivityStateFilename = @"AlltrackIoActivityState";
static NSString   * const kAttributionFilename   = @"AlltrackIoAttribution";
static NSString   * const kSessionCallbackParametersFilename   = @"AlltrackSessionCallbackParameters";
static NSString   * const kSessionPartnerParametersFilename    = @"AlltrackSessionPartnerParameters";
static NSString   * const kAlltrackPrefix          = @"alltrack_";
static const char * const kInternalQueueName     = "io.alltrack.ActivityQueue";
static NSString   * const kForegroundTimerName   = @"Foreground timer";
static NSString   * const kBackgroundTimerName   = @"Background timer";
static NSString   * const kDelayStartTimerName   = @"Delay Start timer";

static NSTimeInterval kForegroundTimerInterval;
static NSTimeInterval kForegroundTimerStart;
static NSTimeInterval kBackgroundTimerInterval;
static double kSessionInterval;
static double kSubSessionInterval;
static const int kiAdRetriesCount = 3;
static const int kAdServicesdRetriesCount = 1;

@implementation ALTInternalState

- (BOOL)isEnabled { return self.enabled; }
- (BOOL)isDisabled { return !self.enabled; }
- (BOOL)isOffline { return self.offline; }
- (BOOL)isOnline { return !self.offline; }
- (BOOL)isInBackground { return self.background; }
- (BOOL)isInForeground { return !self.background; }
- (BOOL)isInDelayedStart { return self.delayStart; }
- (BOOL)isNotInDelayedStart { return !self.delayStart; }
- (BOOL)itHasToUpdatePackages { return self.updatePackages; }
- (BOOL)isFirstLaunch { return self.firstLaunch; }
- (BOOL)hasSessionResponseNotBeenProcessed { return !self.sessionResponseProcessed; }

@end

@implementation ALTSavedPreLaunch

- (id)init {
    self = [super init];
    if (self) {
        // online by default
        self.offline = NO;
    }
    return self;
}

@end

#pragma mark -
@interface ALTActivityHandler()

@property (nonatomic, strong) dispatch_queue_t internalQueue;
@property (nonatomic, strong) ALTPackageHandler *packageHandler;
@property (nonatomic, strong) ALTAttributionHandler *attributionHandler;
@property (nonatomic, strong) ALTSdkClickHandler *sdkClickHandler;
@property (nonatomic, strong) ALTActivityState *activityState;
@property (nonatomic, strong) ALTTimerCycle *foregroundTimer;
@property (nonatomic, strong) ALTTimerOnce *backgroundTimer;
@property (nonatomic, assign) NSInteger iAdRetriesLeft;
@property (nonatomic, assign) NSInteger adServicesRetriesLeft;
@property (nonatomic, strong) ALTInternalState *internalState;
@property (nonatomic, strong) ALTPackageParams *packageParams;
@property (nonatomic, strong) ALTTimerOnce *delayStartTimer;
@property (nonatomic, strong) ALTSessionParameters *sessionParameters;
// weak for object that Activity Handler does not "own"
@property (nonatomic, weak) id<ALTLogger> logger;
@property (nonatomic, weak) NSObject<AlltrackDelegate> *alltrackDelegate;
// copy for objects shared with the user
@property (nonatomic, copy) ALTConfig *alltrackConfig;
@property (nonatomic, weak) ALTSavedPreLaunch *savedPreLaunch;
@property (nonatomic, copy) NSData* deviceTokenData;
@property (nonatomic, copy) NSString* basePath;
@property (nonatomic, copy) NSString* gdprPath;
@property (nonatomic, copy) NSString* subscriptionPath;

- (void)prepareDeeplinkI:(ALTActivityHandler *_Nullable)selfI
            responseData:(ALTAttributionResponseData *_Nullable)attributionResponseData NS_EXTENSION_UNAVAILABLE_IOS("");

@end

// copy from ADClientError
typedef NS_ENUM(NSInteger, AltADClientError) {
    AltADClientErrorUnknown = 0,
    AltADClientErrorTrackingRestrictedOrDenied = 1,
    AltADClientErrorMissingData = 2,
    AltADClientErrorCorruptResponse = 3,
    AltADClientErrorRequestClientError = 4,
    AltADClientErrorRequestServerError = 5,
    AltADClientErrorRequestNetworkError = 6,
    AltADClientErrorUnsupportedPlatform = 7,
    AltCustomErrorTimeout = 100,
};

#pragma mark -
@implementation ALTActivityHandler

@synthesize attribution = _attribution;
@synthesize trackingStatusManager = _trackingStatusManager;

- (id)initWithConfig:(ALTConfig *)alltrackConfig
      savedPreLaunch:(ALTSavedPreLaunch *)savedPreLaunch
{
    self = [super init];
    if (self == nil) return nil;

    if (alltrackConfig == nil) {
        [ALTAlltrackFactory.logger error:@"AlltrackConfig missing"];
        return nil;
    }

    if (![alltrackConfig isValid]) {
        [ALTAlltrackFactory.logger error:@"AlltrackConfig not initialized correctly"];
        return nil;
    }
    
    // check if ASA and IDFA tracking were switched off and warn just in case
    if (alltrackConfig.allowIdfaReading == NO) {
        [ALTAlltrackFactory.logger warn:@"IDFA reading has been switched off"];
    }
    if (alltrackConfig.allowiAdInfoReading == NO) {
        [ALTAlltrackFactory.logger warn:@"iAd info reading has been switched off"];
    }
    if (alltrackConfig.allowAdServicesInfoReading == NO) {
        [ALTAlltrackFactory.logger warn:@"AdServices info reading has been switched off"];
    }

    self.alltrackConfig = alltrackConfig;
    self.savedPreLaunch = savedPreLaunch;
    self.alltrackDelegate = alltrackConfig.delegate;

    // init logger to be available everywhere
    self.logger = ALTAlltrackFactory.logger;

    [self.logger lockLogLevel];

    // inject app token be available in activity state
    [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                    block:^{
        [ALTActivityState saveAppToken:alltrackConfig.appToken];
    }];

    // read files to have sync values available
    [self readAttribution];
    [self readActivityState];
    
    // register SKAdNetwork attribution if we haven't already
    if (self.alltrackConfig.isSKAdNetworkHandlingActive) {
        [[ALTSKAdNetwork getInstance] altRegisterWithCompletionHandler:^(NSError * _Nonnull error) {
            if (error) {
                // handle error
            }
        }];
    }

    self.internalState = [[ALTInternalState alloc] init];

    if (savedPreLaunch.enabled != nil) {
        if (savedPreLaunch.preLaunchActionsArray == nil) {
            savedPreLaunch.preLaunchActionsArray = [[NSMutableArray alloc] init];
        }

        BOOL newEnabled = [savedPreLaunch.enabled boolValue];
        [savedPreLaunch.preLaunchActionsArray addObject:^(ALTActivityHandler * activityHandler){
            [activityHandler setEnabledI:activityHandler enabled:newEnabled];
        }];
    }

    // check if SDK is enabled/disabled
    self.internalState.enabled = savedPreLaunch.enabled != nil ? [savedPreLaunch.enabled boolValue] : YES;
    // reads offline mode from pre launch
    self.internalState.offline = savedPreLaunch.offline;
    // in the background by default
    self.internalState.background = YES;
    // delay start not configured by default
    self.internalState.delayStart = NO;
    // does not need to update packages by default
    if (self.activityState == nil) {
        self.internalState.updatePackages = NO;
    } else {
        self.internalState.updatePackages = self.activityState.updatePackages;
    }
    if (self.activityState == nil) {
        self.internalState.firstLaunch = YES;
    } else {
        self.internalState.firstLaunch = NO;
    }
    // does not have the session response by default
    self.internalState.sessionResponseProcessed = NO;

    self.iAdRetriesLeft = kiAdRetriesCount;
    self.adServicesRetriesLeft = kAdServicesdRetriesCount;

    self.trackingStatusManager = [[ALTTrackingStatusManager alloc] initWithActivityHandler:self];

    self.internalQueue = dispatch_queue_create(kInternalQueueName, DISPATCH_QUEUE_SERIAL);
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI initI:selfI
                     preLaunchActions:savedPreLaunch];
                     }];

    /* Not needed, done already in initI:preLaunchActionsArray: method.
    // self.deviceTokenData = savedPreLaunch.deviceTokenData;
    if (self.activityState != nil) {
        [self setDeviceToken:[ALTUserDefaults getPushToken]];
    }
    */

    [self addNotificationObserver];

    return self;
}

- (void)applicationDidBecomeActive {
    self.internalState.background = NO;

    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI delayStartI:selfI];

                         [selfI stopBackgroundTimerI:selfI];

                         [selfI startForegroundTimerI:selfI];

                         [selfI.logger verbose:@"Subsession start"];

                         [selfI startI:selfI];
                     }];
}

- (void)applicationWillResignActive {
    self.internalState.background = YES;

    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI stopForegroundTimerI:selfI];

                         [selfI startBackgroundTimerI:selfI];

                         [selfI.logger verbose:@"Subsession end"];

                         [selfI endI:selfI];
                     }];
}

- (void)trackEvent:(ALTEvent *)event {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         // track event called before app started
                         if (selfI.activityState == nil) {
                             [selfI startI:selfI];
                         }
                         [selfI eventI:selfI event:event];
                     }];
}

- (void)finishedTracking:(ALTResponseData *)responseData {
    [self checkConversionValue:responseData];

    // redirect session responses to attribution handler to check for attribution information
    if ([responseData isKindOfClass:[ALTSessionResponseData class]]) {
        [self.attributionHandler checkSessionResponse:(ALTSessionResponseData*)responseData];
        return;
    }

    // redirect sdk_click responses to attribution handler to check for attribution information
    if ([responseData isKindOfClass:[ALTSdkClickResponseData class]]) {
        [self.attributionHandler checkSdkClickResponse:(ALTSdkClickResponseData*)responseData];
        return;
    }

    // check if it's an event response
    if ([responseData isKindOfClass:[ALTEventResponseData class]]) {
        [self launchEventResponseTasks:(ALTEventResponseData*)responseData];
        return;
    }
}

- (void)launchEventResponseTasks:(ALTEventResponseData *)eventResponseData {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI launchEventResponseTasksI:selfI eventResponseData:eventResponseData];
                     }];
}

- (void)launchSessionResponseTasks:(ALTSessionResponseData *)sessionResponseData {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI launchSessionResponseTasksI:selfI sessionResponseData:sessionResponseData];
                     }];
}

- (void)launchSdkClickResponseTasks:(ALTSdkClickResponseData *)sdkClickResponseData {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI launchSdkClickResponseTasksI:selfI sdkClickResponseData:sdkClickResponseData];
                     }];
}

- (void)launchAttributionResponseTasks:(ALTAttributionResponseData *)attributionResponseData {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI launchAttributionResponseTasksI:selfI attributionResponseData:attributionResponseData];
                     }];
}

- (void)setEnabled:(BOOL)enabled {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI setEnabledI:selfI enabled:enabled];
                     }];
}

- (void)setOfflineMode:(BOOL)offline {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI setOfflineModeI:selfI offline:offline];
                     }];
}

- (BOOL)isEnabled {
    return [self isEnabledI:self];
}

- (BOOL)isGdprForgotten {
    return [self isGdprForgottenI:self];
}

- (NSString *)adid {
    if (self.activityState == nil) {
        return nil;
    }
    return self.activityState.adid;
}

- (void)appWillOpenUrl:(NSURL *)url withClickTime:(NSDate *)clickTime {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI appWillOpenUrlI:selfI url:url clickTime:clickTime];
                     }];
}

- (void)setDeviceToken:(NSData *)deviceToken {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI setDeviceTokenI:selfI deviceToken:deviceToken];
                     }];
}

- (void)setPushToken:(NSString *)pushToken {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI setPushTokenI:selfI pushToken:pushToken];
                     }];
}

- (void)setGdprForgetMe {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI setGdprForgetMeI:selfI];
                     }];
}

- (void)setTrackingStateOptedOut {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI setTrackingStateOptedOutI:selfI];
                     }];
}

- (void)setAdServicesAttributionToken:(NSString *)token
                                error:(NSError *)error {
    if (![ALTUtil isNull:error]) {
        [self.logger warn:@"Unable to read AdServices details"];
        
        // 3 == platform not supported
        if (error.code != 3 && self.adServicesRetriesLeft > 0) {
            self.adServicesRetriesLeft = self.adServicesRetriesLeft - 1;
            // retry after 5 seconds
            dispatch_time_t retryTime = dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC);
            dispatch_after(retryTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self checkForAdServicesAttributionI:self];
            });
        } else {
            [self sendAdServicesClickPackage:self
                                      token:nil
                            errorCodeNumber:[NSNumber numberWithInteger:error.code]];
        }
    } else {
        [self sendAdServicesClickPackage:self
                                  token:token
                        errorCodeNumber:nil];
    }
}

- (void)setAttributionDetails:(NSDictionary *)attributionDetails
                        error:(NSError *)error
{
    if (![ALTUtil isNull:error]) {
        [self.logger warn:@"Unable to read iAd details"];

        if (self.iAdRetriesLeft  < 0) {
            [self.logger warn:@"Number of retries to get iAd information surpassed"];
            return;
        }

        switch (error.code) {
            // if first request was unsuccessful and ended up with one of the following error codes:
            // apply following retry logic:
            //      - 1st retry after 5 seconds
            //      - 2nd retry after 2 seconds
            //      - 3rd retry after 2 seconds
            case AltADClientErrorUnknown:
            case AltADClientErrorMissingData:
            case AltADClientErrorCorruptResponse:
            case AltADClientErrorRequestClientError:
            case AltADClientErrorRequestServerError:
            case AltADClientErrorRequestNetworkError:
            case AltCustomErrorTimeout: {
                
                [self saveiAdErrorCode:error.code];
                
                int64_t iAdRetryDelay = 0;
                switch (self.iAdRetriesLeft) {
                    case 2:
                        iAdRetryDelay = 5 * NSEC_PER_SEC;
                        break;
                    default:
                        iAdRetryDelay = 2 * NSEC_PER_SEC;
                        break;
                }
                self.iAdRetriesLeft = self.iAdRetriesLeft - 1;
                dispatch_time_t retryTime = dispatch_time(DISPATCH_TIME_NOW, iAdRetryDelay);
                dispatch_after(retryTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self checkForiAdI:self];
                });
                return;
            }
            case AltADClientErrorTrackingRestrictedOrDenied:
            case AltADClientErrorUnsupportedPlatform:
                return;
            default:
                return;
        }
    }

    // check if it's a valid attribution details
    if (![ALTUtil checkAttributionDetails:attributionDetails]) {
        return;
    }

    // send immediately if there is no previous attribution details
    if (self.activityState == nil ||
        self.activityState.attributionDetails == nil)
    {
        // send immediately
        [self sendIad3ClickPackage:self attributionDetails:attributionDetails];
        // save in the background queue
        [ALTUtil launchInQueue:self.internalQueue
                    selfInject:self
                         block:^(ALTActivityHandler * selfI) {
                             [selfI saveAttributionDetailsI:selfI
                                         attributionDetails:attributionDetails];

                         }];
        return;
    }

    // check if new updates previous written one
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         if ([attributionDetails isEqualToDictionary:selfI.activityState.attributionDetails]) {
                             return;
                         }

                         [selfI sendIad3ClickPackage:selfI attributionDetails:attributionDetails];

                         // save new iAd details
                         [selfI saveAttributionDetailsI:selfI
                                     attributionDetails:attributionDetails];
                     }];
}

- (void)saveiAdErrorCode:(NSInteger)code {
    NSString *codeKey;
    switch (code) {
        case AltADClientErrorUnknown:
            codeKey = @"AltADClientErrorUnknown";
            break;
        case AltADClientErrorMissingData:
            codeKey = @"AltADClientErrorMissingData";
            break;
        case AltADClientErrorCorruptResponse:
            codeKey = @"AltADClientErrorCorruptResponse";
            break;
        case AltCustomErrorTimeout:
            codeKey = @"AltCustomErrorTimeout";
            break;
        default:
            codeKey = @"";
            break;
    }
    
    if (![codeKey isEqualToString:@""]) {
        [ALTUserDefaults saveiAdErrorKey:codeKey];
    }
}

- (void)sendIad3ClickPackage:(ALTActivityHandler *)selfI
          attributionDetails:(NSDictionary *)attributionDetails
 {
     if (![selfI isEnabledI:selfI]) {
         return;
     }

     if (ALTAlltrackFactory.iAdFrameworkEnabled == NO) {
         [self.logger verbose:@"Sending iAd details to server suppressed."];
         return;
     }

     double now = [NSDate.date timeIntervalSince1970];
     if (selfI.activityState != nil) {
         [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                         block:^{
             double lastInterval = now - selfI.activityState.lastActivity;
             selfI.activityState.lastInterval = lastInterval;
         }];
     }
     ALTPackageBuilder *clickBuilder = [[ALTPackageBuilder alloc]
                                        initWithPackageParams:selfI.packageParams
                                        activityState:selfI.activityState
                                        config:selfI.alltrackConfig
                                        sessionParameters:self.sessionParameters
                                        trackingStatusManager:self.trackingStatusManager
                                        createdAt:now];

     clickBuilder.attributionDetails = attributionDetails;

     ALTActivityPackage *clickPackage = [clickBuilder buildClickPackage:ALTiAdPackageKey];
     [selfI.sdkClickHandler sendSdkClick:clickPackage];
}

- (void)sendAdServicesClickPackage:(ALTActivityHandler *)selfI
                             token:(NSString *)token
                   errorCodeNumber:(NSNumber *)errorCodeNumber
 {
     if (![selfI isEnabledI:selfI]) {
         return;
     }

     if (ALTAlltrackFactory.adServicesFrameworkEnabled == NO) {
         [self.logger verbose:@"Sending AdServices attribution to server suppressed."];
         return;
     }

     double now = [NSDate.date timeIntervalSince1970];
     if (selfI.activityState != nil) {
         [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                         block:^{
             double lastInterval = now - selfI.activityState.lastActivity;
             selfI.activityState.lastInterval = lastInterval;
         }];
     }
     ALTPackageBuilder *clickBuilder = [[ALTPackageBuilder alloc]
                                        initWithPackageParams:selfI.packageParams
                                       activityState:selfI.activityState
                                       config:selfI.alltrackConfig
                                       sessionParameters:self.sessionParameters
                                       trackingStatusManager:self.trackingStatusManager
                                       createdAt:now];

     ALTActivityPackage *clickPackage =
        [clickBuilder buildClickPackage:ALTAdServicesPackageKey
                                  token:token
                        errorCodeNumber:errorCodeNumber];
     [selfI.sdkClickHandler sendSdkClick:clickPackage];
}

- (void)saveAttributionDetailsI:(ALTActivityHandler *)selfI
             attributionDetails:(NSDictionary *)attributionDetails
{
    // save new iAd details
    [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                    block:^{
        selfI.activityState.attributionDetails = attributionDetails;
    }];
    [selfI writeAttributionI:selfI];
}

- (void)setAskingAttribution:(BOOL)askingAttribution {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI setAskingAttributionI:selfI
                                   askingAttribution:askingAttribution];
                     }];
}

- (void)foregroundTimerFired {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI foregroundTimerFiredI:selfI];
                     }];
}

- (void)backgroundTimerFired {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI backgroundTimerFiredI:selfI];
                     }];
}

- (void)sendFirstPackages {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI sendFirstPackagesI:selfI];
                     }];
}

- (void)addSessionCallbackParameter:(NSString *)key
                              value:(NSString *)value {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI addSessionCallbackParameterI:selfI key:key value:value];
                     }];
}

- (void)addSessionPartnerParameter:(NSString *)key
                             value:(NSString *)value {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI addSessionPartnerParameterI:selfI key:key value:value];
                     }];
}

- (void)removeSessionCallbackParameter:(NSString *)key {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI removeSessionCallbackParameterI:selfI key:key];
                     }];
}

- (void)removeSessionPartnerParameter:(NSString *)key {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI removeSessionPartnerParameterI:selfI key:key];
                     }];
}

- (void)resetSessionCallbackParameters {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI resetSessionCallbackParametersI:selfI];
                     }];
}

- (void)resetSessionPartnerParameters {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI resetSessionPartnerParametersI:selfI];
                     }];
}

- (void)trackAdRevenue:(NSString *)source payload:(NSData *)payload {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI adRevenueI:selfI source:source payload:payload];
                     }];
}

- (void)trackSubscription:(ALTSubscription *)subscription {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
        [selfI trackSubscriptionI:selfI subscription:subscription];
    }];
}

- (void)disableThirdPartySharing {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI disableThirdPartySharingI:selfI];
                     }];
}

- (void)trackThirdPartySharing:(nonnull ALTThirdPartySharing *)thirdPartySharing {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
        BOOL tracked =
            [selfI trackThirdPartySharingI:selfI thirdPartySharing:thirdPartySharing];
        if (! tracked) {
            if (self.savedPreLaunch.preLaunchAlltrackThirdPartySharingArray == nil) {
                self.savedPreLaunch.preLaunchAlltrackThirdPartySharingArray =
                    [[NSMutableArray alloc] init];
            }

            [self.savedPreLaunch.preLaunchAlltrackThirdPartySharingArray
                addObject:thirdPartySharing];
        }
    }];
}

- (void)trackMeasurementConsent:(BOOL)enabled {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
        BOOL tracked =
            [selfI trackMeasurementConsentI:selfI enabled:enabled];
        if (! tracked) {
            selfI.savedPreLaunch.lastMeasurementConsentTracked =
                [NSNumber numberWithBool:enabled];
        }
    }];
}

- (void)trackAdRevenue:(ALTAdRevenue *)adRevenue {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
        [selfI trackAdRevenueI:selfI adRevenue:adRevenue];
    }];
}

- (void)checkForNewAttStatus {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
        [selfI checkForNewAttStatusI:selfI];
    }];
}

- (void)writeActivityState {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                         [selfI writeActivityStateI:selfI];
                     }];
}

- (void)trackAttStatusUpdate {
    [ALTUtil launchInQueue:self.internalQueue
                selfInject:self
                     block:^(ALTActivityHandler * selfI) {
                        [selfI trackAttStatusUpdateI:selfI];
                     }];
}
- (void)trackAttStatusUpdateI:(ALTActivityHandler *)selfI {
    double now = [NSDate.date timeIntervalSince1970];

    ALTPackageBuilder *infoBuilder = [[ALTPackageBuilder alloc]
                                      initWithPackageParams:selfI.packageParams
                                                activityState:selfI.activityState
                                                config:selfI.alltrackConfig
                                                sessionParameters:selfI.sessionParameters
                                                trackingStatusManager:self.trackingStatusManager
                                                createdAt:now];

    ALTActivityPackage *infoPackage = [infoBuilder buildInfoPackage:@"att"];
    [selfI.packageHandler addPackage:infoPackage];
    
    if (selfI.alltrackConfig.eventBufferingEnabled) {
        [selfI.logger info:@"Buffered event %@", infoPackage.suffix];
    } else {
        [selfI.packageHandler sendFirstPackage];
    }
}

- (NSString *)getBasePath {
    return _basePath;
}

- (NSString *)getGdprPath {
    return _gdprPath;
}

- (NSString *)getSubscriptionPath {
    return _subscriptionPath;
}

- (void)teardown
{
    [ALTAlltrackFactory.logger verbose:@"ALTActivityHandler teardown"];
    [self removeNotificationObserver];
    if (self.backgroundTimer != nil) {
        [self.backgroundTimer cancel];
    }
    if (self.foregroundTimer != nil) {
        [self.foregroundTimer cancel];
    }
    if (self.delayStartTimer != nil) {
        [self.delayStartTimer cancel];
    }
    if (self.attributionHandler != nil) {
        [self.attributionHandler teardown];
    }
    if (self.packageHandler != nil) {
        [self.packageHandler teardown];
    }
    if (self.sdkClickHandler != nil) {
        [self.sdkClickHandler teardown];
    }
    [self teardownActivityStateS];
    [self teardownAttributionS];
    [self teardownAllSessionParametersS];

    [ALTUtil teardown];

    self.internalQueue = nil;
    self.packageHandler = nil;
    self.attributionHandler = nil;
    self.sdkClickHandler = nil;
    self.foregroundTimer = nil;
    self.backgroundTimer = nil;
    self.alltrackDelegate = nil;
    self.alltrackConfig = nil;
    self.internalState = nil;
    self.packageParams = nil;
    self.delayStartTimer = nil;
    self.logger = nil;
}

+ (void)deleteState
{
    [ALTActivityHandler deleteActivityState];
    [ALTActivityHandler deleteAttribution];
    [ALTActivityHandler deleteSessionCallbackParameter];
    [ALTActivityHandler deleteSessionPartnerParameter];

    [ALTUserDefaults clearAlltrackStuff];
}

+ (void)deleteActivityState {
    [ALTUtil deleteFileWithName:kActivityStateFilename];
}

+ (void)deleteAttribution {
    [ALTUtil deleteFileWithName:kAttributionFilename];
}

+ (void)deleteSessionCallbackParameter {
    [ALTUtil deleteFileWithName:kSessionCallbackParametersFilename];
}

+ (void)deleteSessionPartnerParameter {
    [ALTUtil deleteFileWithName:kSessionPartnerParametersFilename];
}

#pragma mark - internal
- (void)initI:(ALTActivityHandler *)selfI
preLaunchActions:(ALTSavedPreLaunch*)preLaunchActions
{
    // get session values
    kSessionInterval = ALTAlltrackFactory.sessionInterval;
    kSubSessionInterval = ALTAlltrackFactory.subsessionInterval;
    // get timer values
    kForegroundTimerStart = ALTAlltrackFactory.timerStart;
    kForegroundTimerInterval = ALTAlltrackFactory.timerInterval;
    kBackgroundTimerInterval = ALTAlltrackFactory.timerInterval;

    selfI.packageParams = [ALTPackageParams packageParamsWithSdkPrefix:selfI.alltrackConfig.sdkPrefix];

    // read files that are accessed only in Internal sections
    selfI.sessionParameters = [[ALTSessionParameters alloc] init];
    [selfI readSessionCallbackParametersI:selfI];
    [selfI readSessionPartnerParametersI:selfI];

    if (selfI.alltrackConfig.eventBufferingEnabled)  {
        [selfI.logger info:@"Event buffering is enabled"];
    }
    
    if (selfI.alltrackConfig.defaultTracker != nil) {
        [selfI.logger info:@"Default tracker: '%@'", selfI.alltrackConfig.defaultTracker];
    }

    if (selfI.deviceTokenData != nil) {
        [selfI.logger info:@"Push token: '%@'", selfI.deviceTokenData];
        if (selfI.activityState != nil) {
            [selfI setDeviceToken:selfI.deviceTokenData];
        }
    } else {
        if (selfI.activityState != nil) {
            NSData *deviceToken = [ALTUserDefaults getPushTokenData];
            [selfI setDeviceToken:deviceToken];
            NSString *pushToken = [ALTUserDefaults getPushTokenString];
            [selfI setPushToken:pushToken];
        }
    }

    if (selfI.activityState != nil) {
        if ([ALTUserDefaults getGdprForgetMe]) {
            [selfI setGdprForgetMe];
        }
    }

    selfI.foregroundTimer = [ALTTimerCycle timerWithBlock:^{
        [selfI foregroundTimerFired];
    }
                                                    queue:selfI.internalQueue
                                                startTime:kForegroundTimerStart
                                             intervalTime:kForegroundTimerInterval
                                                     name:kForegroundTimerName
    ];

    if (selfI.alltrackConfig.sendInBackground) {
        [selfI.logger info:@"Send in background configured"];
        selfI.backgroundTimer = [ALTTimerOnce timerWithBlock:^{ [selfI backgroundTimerFired]; }
                                                      queue:selfI.internalQueue
                                                        name:kBackgroundTimerName];
    }

    if (selfI.activityState == nil &&
        selfI.alltrackConfig.delayStart > 0)
    {
        [selfI.logger info:@"Delay start configured"];
        selfI.internalState.delayStart = YES;
        selfI.delayStartTimer = [ALTTimerOnce timerWithBlock:^{ [selfI sendFirstPackages]; }
                                                       queue:selfI.internalQueue
                                                        name:kDelayStartTimerName];
    }

    [ALTUtil updateUrlSessionConfiguration:selfI.alltrackConfig];

    ALTUrlStrategy *packageHandlerUrlStrategy =
        [[ALTUrlStrategy alloc]
             initWithUrlStrategyInfo:selfI.alltrackConfig.urlStrategy
             extraPath:preLaunchActions.extraPath];

    selfI.packageHandler = [[ALTPackageHandler alloc]
                                initWithActivityHandler:selfI
                                startsSending:
                                    [selfI toSendI:selfI sdkClickHandlerOnly:NO]
                                userAgent:selfI.alltrackConfig.userAgent
                                urlStrategy:packageHandlerUrlStrategy];

    // update session parameters in package queue
    if ([selfI itHasToUpdatePackagesI:selfI]) {
        [selfI updatePackagesI:selfI];
     }


    ALTUrlStrategy *attributionHandlerUrlStrategy =
        [[ALTUrlStrategy alloc]
             initWithUrlStrategyInfo:selfI.alltrackConfig.urlStrategy
             extraPath:preLaunchActions.extraPath];

    selfI.attributionHandler = [[ALTAttributionHandler alloc]
                                    initWithActivityHandler:selfI
                                    startsSending:
                                        [selfI toSendI:selfI sdkClickHandlerOnly:NO]
                                    userAgent:selfI.alltrackConfig.userAgent
                                    urlStrategy:attributionHandlerUrlStrategy];

    ALTUrlStrategy *sdkClickHandlerUrlStrategy =
        [[ALTUrlStrategy alloc]
             initWithUrlStrategyInfo:selfI.alltrackConfig.urlStrategy
             extraPath:preLaunchActions.extraPath];

    selfI.sdkClickHandler = [[ALTSdkClickHandler alloc]
                                initWithActivityHandler:selfI
                                startsSending:[selfI toSendI:selfI sdkClickHandlerOnly:YES]
                                userAgent:selfI.alltrackConfig.userAgent
                                urlStrategy:sdkClickHandlerUrlStrategy];

    [selfI checkLinkMeI:selfI];
    [selfI.trackingStatusManager checkForNewAttStatus];

    [selfI preLaunchActionsI:selfI
       preLaunchActionsArray:preLaunchActions.preLaunchActionsArray];

    [ALTUtil launchInMainThreadWithInactive:^(BOOL isInactive) {
        [ALTUtil launchInQueue:self.internalQueue selfInject:self block:^(ALTActivityHandler * selfI) {
            if (!isInactive) {
                [selfI.logger debug:@"Start sdk, since the app is already in the foreground"];
                selfI.internalState.background = NO;
                [selfI startI:selfI];
            } else {
                [selfI.logger debug:@"Wait for the app to go to the foreground to start the sdk"];
            }
        }];
    }];
}

- (void)startI:(ALTActivityHandler *)selfI {
    // it shouldn't start if it was disabled after a first session
    if (selfI.activityState != nil
        && !selfI.activityState.enabled) {
        return;
    }

    [selfI updateHandlersStatusAndSendI:selfI];
    
    [selfI processCoppaComplianceI:selfI];
    
    [selfI processSessionI:selfI];

    [selfI checkAttributionStateI:selfI];

    [selfI processCachedDeeplinkI:selfI];
}

- (void)processSessionI:(ALTActivityHandler *)selfI {
    double now = [NSDate.date timeIntervalSince1970];

    // very first session
    if (selfI.activityState == nil) {
        selfI.activityState = [[ALTActivityState alloc] init];

        // selfI.activityState.deviceToken = [ALTUtil convertDeviceToken:selfI.deviceTokenData];
        NSData *deviceToken = [ALTUserDefaults getPushTokenData];
        NSString *deviceTokenString = [ALTUtil convertDeviceToken:deviceToken];
        NSString *pushToken = [ALTUserDefaults getPushTokenString];
        [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                        block:^{
            selfI.activityState.deviceToken = deviceTokenString != nil ? deviceTokenString : pushToken;
        }];

        // track the first session package only if it's enabled
        if ([selfI.internalState isEnabled]) {
            // If user chose to be forgotten before install has ever tracked, don't track it.
            if ([ALTUserDefaults getGdprForgetMe]) {
                [selfI setGdprForgetMeI:selfI];
            } else {
                [selfI processCoppaComplianceI:selfI];
                
                // check if disable third party sharing request came, then send it first
                if ([ALTUserDefaults getDisableThirdPartySharing]) {
                    [selfI disableThirdPartySharingI:selfI];
                }
                if (selfI.savedPreLaunch.preLaunchAlltrackThirdPartySharingArray != nil) {
                    for (ALTThirdPartySharing *thirdPartySharing
                         in selfI.savedPreLaunch.preLaunchAlltrackThirdPartySharingArray)
                    {
                        [selfI trackThirdPartySharingI:selfI
                                     thirdPartySharing:thirdPartySharing];
                    }

                    selfI.savedPreLaunch.preLaunchAlltrackThirdPartySharingArray = nil;
                }
                if (selfI.savedPreLaunch.lastMeasurementConsentTracked != nil) {
                    [selfI
                        trackMeasurementConsentI:selfI
                        enabled:[selfI.savedPreLaunch.lastMeasurementConsentTracked boolValue]];

                    selfI.savedPreLaunch.lastMeasurementConsentTracked = nil;
                }

                [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                                block:^{
                    selfI.activityState.sessionCount = 1; // this is the first session
                }];
                [selfI transferSessionPackageI:selfI now:now];
            }
        }

        [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                        block:^{
            [selfI.activityState resetSessionAttributes:now];
            selfI.activityState.enabled = [selfI.internalState isEnabled];
            selfI.activityState.updatePackages = [selfI.internalState itHasToUpdatePackages];
        }];

        if (selfI.alltrackConfig.allowiAdInfoReading == YES) {
            [selfI checkForiAdI:selfI];
        }
        if (selfI.alltrackConfig.allowAdServicesInfoReading == YES) {
            [selfI checkForAdServicesAttributionI:selfI];
        }

        [selfI writeActivityStateI:selfI];
        [ALTUserDefaults removePushToken];
        [ALTUserDefaults removeDisableThirdPartySharing];

        return;
    }

    double lastInterval = now - selfI.activityState.lastActivity;
    if (lastInterval < 0) {
        [selfI.logger error:@"Time travel!"];
        [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                        block:^{
            selfI.activityState.lastActivity = now;
        }];
        [selfI writeActivityStateI:selfI];
        return;
    }

    // new session
    if (lastInterval > kSessionInterval) {
        [self trackNewSessionI:now withActivityHandler:selfI];
        return;
    }

    // new subsession
    if (lastInterval > kSubSessionInterval) {
        [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                        block:^{
            selfI.activityState.subsessionCount++;
            selfI.activityState.sessionLength += lastInterval;
            selfI.activityState.lastActivity = now;
        }];
        [selfI.logger verbose:@"Started subsession %d of session %d",
         selfI.activityState.subsessionCount,
         selfI.activityState.sessionCount];
        [selfI writeActivityStateI:selfI];
        return;
    }

    [selfI.logger verbose:@"Time span since last activity too short for a new subsession"];
}

- (void)trackNewSessionI:(double)now withActivityHandler:(ALTActivityHandler *)selfI {
    if (selfI.activityState.isGdprForgotten) {
        return;
    }

    [selfI checkForAdServicesAttributionI:selfI];

    double lastInterval = now - selfI.activityState.lastActivity;
    [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                    block:^{
        selfI.activityState.sessionCount++;
        selfI.activityState.lastInterval = lastInterval;
    }];
    [selfI transferSessionPackageI:selfI now:now];
    [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                    block:^{
        [selfI.activityState resetSessionAttributes:now];
    }];
    [selfI writeActivityStateI:selfI];
}

- (void)transferSessionPackageI:(ALTActivityHandler *)selfI
                            now:(double)now {
    ALTPackageBuilder *sessionBuilder = [[ALTPackageBuilder alloc]
                                         initWithPackageParams:selfI.packageParams
                                         activityState:selfI.activityState
                                         config:selfI.alltrackConfig
                                         sessionParameters:selfI.sessionParameters
                                         trackingStatusManager:self.trackingStatusManager
                                         createdAt:now];
    ALTActivityPackage *sessionPackage = [sessionBuilder buildSessionPackage:[selfI.internalState isInDelayedStart]];
    [selfI.packageHandler addPackage:sessionPackage];
    [selfI.packageHandler sendFirstPackage];
}

- (void)checkAttributionStateI:(ALTActivityHandler *)selfI {
    if (![selfI checkActivityStateI:selfI]) return;

    // if it's the first launch
    if ([selfI.internalState isFirstLaunch]) {
        // and it hasn't received the session response
        if ([selfI.internalState hasSessionResponseNotBeenProcessed]) {
            return;
        }
    }

    // if there is already an attribution saved and there was no attribution being asked
    if (selfI.attribution != nil && !selfI.activityState.askingAttribution) {
        return;
    }

    [selfI.attributionHandler getAttribution];
}

- (void)processCachedDeeplinkI:(ALTActivityHandler *)selfI {
    if (![selfI checkActivityStateI:selfI]) return;

    NSURL *cachedDeeplinkUrl = [ALTUserDefaults getDeeplinkUrl];
    if (cachedDeeplinkUrl == nil) {
        return;
    }
    NSDate *cachedDeeplinkClickTime = [ALTUserDefaults getDeeplinkClickTime];
    if (cachedDeeplinkClickTime == nil) {
        return;
    }

    [selfI appWillOpenUrlI:selfI url:cachedDeeplinkUrl clickTime:cachedDeeplinkClickTime];
    [ALTUserDefaults removeDeeplink];
}

- (void)endI:(ALTActivityHandler *)selfI {
    // pause sending if it's not allowed to send
    if (![selfI toSendI:selfI]) {
        [selfI pauseSendingI:selfI];
    }

    double now = [NSDate.date timeIntervalSince1970];
    if ([selfI updateActivityStateI:selfI now:now]) {
        [selfI writeActivityStateI:selfI];
    }
}

- (void)eventI:(ALTActivityHandler *)selfI
         event:(ALTEvent *)event {
    if (![selfI isEnabledI:selfI]) return;
    if (![selfI checkEventI:selfI event:event]) return;
    if (![selfI checkTransactionIdI:selfI transactionId:event.transactionId]) return;
    if (selfI.activityState.isGdprForgotten) { return; }

    double now = [NSDate.date timeIntervalSince1970];

    [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                    block:^{
        selfI.activityState.eventCount++;
    }];
    [selfI updateActivityStateI:selfI now:now];

    // create and populate event package
    ALTPackageBuilder *eventBuilder = [[ALTPackageBuilder alloc]
                                       initWithPackageParams:selfI.packageParams
                                       activityState:selfI.activityState
                                       config:selfI.alltrackConfig
                                       sessionParameters:selfI.sessionParameters
                                       trackingStatusManager:self.trackingStatusManager
                                       createdAt:now];
    ALTActivityPackage *eventPackage = [eventBuilder buildEventPackage:event
                                                             isInDelay:[selfI.internalState isInDelayedStart]];
    [selfI.packageHandler addPackage:eventPackage];

    if (selfI.alltrackConfig.eventBufferingEnabled) {
        [selfI.logger info:@"Buffered event %@", eventPackage.suffix];
    } else {
        [selfI.packageHandler sendFirstPackage];
    }

    // if it is in the background and it can send, start the background timer
    if (selfI.alltrackConfig.sendInBackground && [selfI.internalState isInBackground]) {
        [selfI startBackgroundTimerI:selfI];
    }

    [selfI writeActivityStateI:selfI];
}

- (void)adRevenueI:(ALTActivityHandler *)selfI
            source:(NSString *)source
           payload:(NSData *)payload {
    if (!selfI.activityState) {
        return;
    }
    if (![selfI isEnabledI:selfI]) {
        return;
    }
    if (selfI.activityState.isGdprForgotten) {
        return;
    }

    double now = [NSDate.date timeIntervalSince1970];

    // Create and submit ad revenue package.
    ALTPackageBuilder *adRevenueBuilder = [[ALTPackageBuilder alloc]
                                           initWithPackageParams:selfI.packageParams
                                                   activityState:selfI.activityState
                                                   config:selfI.alltrackConfig
                                                   sessionParameters:selfI.sessionParameters
                                                   trackingStatusManager:self.trackingStatusManager
                                                   createdAt:now];

    ALTActivityPackage *adRevenuePackage = [adRevenueBuilder buildAdRevenuePackage:source payload:payload];
    [selfI.packageHandler addPackage:adRevenuePackage];
    if (selfI.alltrackConfig.eventBufferingEnabled) {
        [selfI.logger info:@"Buffered event %@", adRevenuePackage.suffix];
    } else {
        [selfI.packageHandler sendFirstPackage];
    }
}

- (void)trackSubscriptionI:(ALTActivityHandler *)selfI
              subscription:(ALTSubscription *)subscription {
    if (!selfI.activityState) {
        return;
    }
    if (![selfI isEnabledI:selfI]) {
        return;
    }
    if (selfI.activityState.isGdprForgotten) {
        return;
    }

    double now = [NSDate.date timeIntervalSince1970];

    // Create and submit ad revenue package.
    ALTPackageBuilder *subscriptionBuilder = [[ALTPackageBuilder alloc]
                                              initWithPackageParams:selfI.packageParams
                                                    activityState:selfI.activityState
                                                    config:selfI.alltrackConfig
                                                    sessionParameters:selfI.sessionParameters
                                                    trackingStatusManager:self.trackingStatusManager
                                                    createdAt:now];

    ALTActivityPackage *subscriptionPackage = [subscriptionBuilder buildSubscriptionPackage:subscription
                                                                                  isInDelay:[selfI.internalState isInDelayedStart]];
    [selfI.packageHandler addPackage:subscriptionPackage];
    if (selfI.alltrackConfig.eventBufferingEnabled) {
        [selfI.logger info:@"Buffered event %@", subscriptionPackage.suffix];
    } else {
        [selfI.packageHandler sendFirstPackage];
    }
}

- (void)disableThirdPartySharingI:(ALTActivityHandler *)selfI {
    // cache the disable third party sharing request, so that the request order maintains
    // even this call returns before making server request
    [ALTUserDefaults setDisableThirdPartySharing];

    if (!selfI.activityState) {
        return;
    }
    if (![selfI isEnabledI:selfI]) {
        return;
    }
    if (selfI.activityState.isGdprForgotten) {
        return;
    }
    if (selfI.activityState.isThirdPartySharingDisabled) {
        return;
    }
    if (selfI.alltrackConfig.coppaCompliantEnabled) {
        [selfI.logger warn:@"Call to disable third party sharing API ignored, already done when COPPA enabled"];
        return;
    }

    [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                    block:^{
        selfI.activityState.isThirdPartySharingDisabled = YES;
    }];
    [selfI writeActivityStateI:selfI];

    double now = [NSDate.date timeIntervalSince1970];

    // build package
    ALTPackageBuilder *dtpsBuilder = [[ALTPackageBuilder alloc]
                                      initWithPackageParams:selfI.packageParams
                                            activityState:selfI.activityState
                                            config:selfI.alltrackConfig
                                            sessionParameters:selfI.sessionParameters
                                            trackingStatusManager:self.trackingStatusManager
                                            createdAt:now];

    ALTActivityPackage *dtpsPackage = [dtpsBuilder buildDisableThirdPartySharingPackage];

    [selfI.packageHandler addPackage:dtpsPackage];

    [ALTUserDefaults removeDisableThirdPartySharing];

    if (selfI.alltrackConfig.eventBufferingEnabled) {
        [selfI.logger info:@"Buffered event %@", dtpsPackage.suffix];
    } else {
        [selfI.packageHandler sendFirstPackage];
    }
}

- (BOOL)trackThirdPartySharingI:(ALTActivityHandler *)selfI
                thirdPartySharing:(nonnull ALTThirdPartySharing *)thirdPartySharing
{
    if (!selfI.activityState) {
        return NO;
    }
    if (![selfI isEnabledI:selfI]) {
        return NO;
    }
    if (selfI.activityState.isGdprForgotten) {
        return NO;
    }
    if (selfI.alltrackConfig.coppaCompliantEnabled) {
        [selfI.logger warn:@"Calling third party sharing API not allowed when COPPA enabled"];
        return NO;
    }

    double now = [NSDate.date timeIntervalSince1970];

    // build package
    ALTPackageBuilder *tpsBuilder = [[ALTPackageBuilder alloc]
                                     initWithPackageParams:selfI.packageParams
                                            activityState:selfI.activityState
                                            config:selfI.alltrackConfig
                                            sessionParameters:selfI.sessionParameters
                                            trackingStatusManager:self.trackingStatusManager
                                            createdAt:now];

    ALTActivityPackage *dtpsPackage = [tpsBuilder buildThirdPartySharingPackage:thirdPartySharing];

    [selfI.packageHandler addPackage:dtpsPackage];

    if (selfI.alltrackConfig.eventBufferingEnabled) {
        [selfI.logger info:@"Buffered event %@", dtpsPackage.suffix];
    } else {
        [selfI.packageHandler sendFirstPackage];
    }

    return YES;
}

- (BOOL)trackMeasurementConsentI:(ALTActivityHandler *)selfI
                         enabled:(BOOL)enabled
{
    if (!selfI.activityState) {
        return NO;
    }
    if (![selfI isEnabledI:selfI]) {
        return NO;
    }
    if (selfI.activityState.isGdprForgotten) {
        return NO;
    }

    double now = [NSDate.date timeIntervalSince1970];

    // build package
    ALTPackageBuilder *tpsBuilder = [[ALTPackageBuilder alloc]
                                     initWithPackageParams:selfI.packageParams
                                            activityState:selfI.activityState
                                            config:selfI.alltrackConfig
                                            sessionParameters:selfI.sessionParameters
                                            trackingStatusManager:self.trackingStatusManager
                                            createdAt:now];

    ALTActivityPackage *mcPackage = [tpsBuilder buildMeasurementConsentPackage:enabled];

    [selfI.packageHandler addPackage:mcPackage];

    if (selfI.alltrackConfig.eventBufferingEnabled) {
        [selfI.logger info:@"Buffered event %@", mcPackage.suffix];
    } else {
        [selfI.packageHandler sendFirstPackage];
    }

    return YES;
}

- (void)trackAdRevenueI:(ALTActivityHandler *)selfI
              adRevenue:(ALTAdRevenue *)adRevenue
{
    if (!selfI.activityState) {
        return;
    }
    if (![selfI isEnabledI:selfI]) {
        return;
    }
    if (selfI.activityState.isGdprForgotten) {
        return;
    }
    if (![selfI checkAdRevenueI:selfI adRevenue:adRevenue]) {
        return;
    }

    double now = [NSDate.date timeIntervalSince1970];

    // Create and submit ad revenue package.
    ALTPackageBuilder *adRevenueBuilder = [[ALTPackageBuilder alloc] initWithPackageParams:selfI.packageParams
                                                                          activityState:selfI.activityState
                                                                                 config:selfI.alltrackConfig
                                                                      sessionParameters:selfI.sessionParameters
                                                                  trackingStatusManager:self.trackingStatusManager
                                                                              createdAt:now];

    ALTActivityPackage *adRevenuePackage = [adRevenueBuilder buildAdRevenuePackage:adRevenue
                                                                         isInDelay:[selfI.internalState isInDelayedStart]];
    [selfI.packageHandler addPackage:adRevenuePackage];
    if (selfI.alltrackConfig.eventBufferingEnabled) {
        [selfI.logger info:@"Buffered event %@", adRevenuePackage.suffix];
    } else {
        [selfI.packageHandler sendFirstPackage];
    }
}

- (void)checkForNewAttStatusI:(ALTActivityHandler *)selfI {
    if (!selfI.activityState) {
        return;
    }
    if (![selfI isEnabledI:selfI]) {
        return;
    }
    if (selfI.activityState.isGdprForgotten) {
        return;
    }
    if (!selfI.trackingStatusManager) {
        return;
    }
    
    [selfI.trackingStatusManager checkForNewAttStatus];
}

- (void)launchEventResponseTasksI:(ALTActivityHandler *)selfI
                eventResponseData:(ALTEventResponseData *)eventResponseData {
    [selfI updateAdidI:selfI adid:eventResponseData.adid];

    // event success callback
    if (eventResponseData.success
        && [selfI.alltrackDelegate respondsToSelector:@selector(alltrackEventTrackingSucceeded:)])
    {
        [selfI.logger debug:@"Launching success event tracking delegate"];
        [ALTUtil launchInMainThread:selfI.alltrackDelegate
                           selector:@selector(alltrackEventTrackingSucceeded:)
                         withObject:[eventResponseData successResponseData]];
        return;
    }
    // event failure callback
    if (!eventResponseData.success
        && [selfI.alltrackDelegate respondsToSelector:@selector(alltrackEventTrackingFailed:)])
    {
        [selfI.logger debug:@"Launching failed event tracking delegate"];
        [ALTUtil launchInMainThread:selfI.alltrackDelegate
                           selector:@selector(alltrackEventTrackingFailed:)
                         withObject:[eventResponseData failureResponseData]];
        return;
    }
}

- (void)launchSessionResponseTasksI:(ALTActivityHandler *)selfI
                sessionResponseData:(ALTSessionResponseData *)sessionResponseData {
    [selfI updateAdidI:selfI adid:sessionResponseData.adid];

    BOOL toLaunchAttributionDelegate = [selfI updateAttributionI:selfI attribution:sessionResponseData.attribution];

    // mark install as tracked on success
    if (sessionResponseData.success) {
        [ALTUserDefaults setInstallTracked];
    }

    // session success callback
    if (sessionResponseData.success
        && [selfI.alltrackDelegate respondsToSelector:@selector(alltrackSessionTrackingSucceeded:)])
    {
        [selfI.logger debug:@"Launching success session tracking delegate"];
        [ALTUtil launchInMainThread:selfI.alltrackDelegate
                           selector:@selector(alltrackSessionTrackingSucceeded:)
                         withObject:[sessionResponseData successResponseData]];
    }
    // session failure callback
    if (!sessionResponseData.success
        && [selfI.alltrackDelegate respondsToSelector:@selector(alltrackSessionTrackingFailed:)])
    {
        [selfI.logger debug:@"Launching failed session tracking delegate"];
        [ALTUtil launchInMainThread:selfI.alltrackDelegate
                           selector:@selector(alltrackSessionTrackingFailed:)
                         withObject:[sessionResponseData failureResponseData]];
    }

    // try to update and launch the attribution changed delegate
    if (toLaunchAttributionDelegate) {
        [selfI.logger debug:@"Launching attribution changed delegate"];
        [ALTUtil launchInMainThread:selfI.alltrackDelegate
                           selector:@selector(alltrackAttributionChanged:)
                         withObject:sessionResponseData.attribution];
    }

    // if attribution didn't update and it's still null -> ask for attribution
    if (selfI.attribution == nil && selfI.activityState.askingAttribution == NO) {
        [selfI.attributionHandler getAttribution];
    }

    selfI.internalState.sessionResponseProcessed = YES;
}

- (void)launchSdkClickResponseTasksI:(ALTActivityHandler *)selfI
                sdkClickResponseData:(ALTSdkClickResponseData *)sdkClickResponseData {
    [selfI updateAdidI:selfI adid:sdkClickResponseData.adid];

    BOOL toLaunchAttributionDelegate = [selfI updateAttributionI:selfI attribution:sdkClickResponseData.attribution];

    // try to update and launch the attribution changed delegate
    if (toLaunchAttributionDelegate) {
        [selfI.logger debug:@"Launching attribution changed delegate"];
        [ALTUtil launchInMainThread:selfI.alltrackDelegate
                           selector:@selector(alltrackAttributionChanged:)
                         withObject:sdkClickResponseData.attribution];
    }
}

- (void)launchAttributionResponseTasksI:(ALTActivityHandler *)selfI
                attributionResponseData:(ALTAttributionResponseData *)attributionResponseData {
    [selfI checkConversionValue:attributionResponseData];

    [selfI updateAdidI:selfI adid:attributionResponseData.adid];

    BOOL toLaunchAttributionDelegate = [selfI updateAttributionI:selfI
                                                     attribution:attributionResponseData.attribution];

    // try to update and launch the attribution changed delegate non-blocking
    if (toLaunchAttributionDelegate) {
        [selfI.logger debug:@"Launching attribution changed delegate"];
        [ALTUtil launchInMainThread:selfI.alltrackDelegate
                           selector:@selector(alltrackAttributionChanged:)
                         withObject:attributionResponseData.attribution];
    }

    [selfI prepareDeeplinkI:selfI responseData:attributionResponseData];
}

- (void)prepareDeeplinkI:(ALTActivityHandler *)selfI
            responseData:(ALTAttributionResponseData *)attributionResponseData {
    if (attributionResponseData == nil) {
        return;
    }

    if (attributionResponseData.deeplink == nil) {
        return;
    }

    [selfI.logger info:@"Open deep link (%@)", attributionResponseData.deeplink.absoluteString];

    [ALTUtil launchInMainThread:^{
        BOOL toLaunchDeeplink = YES;

        if ([selfI.alltrackDelegate respondsToSelector:@selector(alltrackDeeplinkResponse:)]) {
            toLaunchDeeplink = [selfI.alltrackDelegate alltrackDeeplinkResponse:attributionResponseData.deeplink];
        }

        if (toLaunchDeeplink) {
            [ALTUtil launchDeepLinkMain:attributionResponseData.deeplink];
        }
    }];
}

- (void)updateAdidI:(ALTActivityHandler *)selfI
               adid:(NSString *)adid {
    if (adid == nil) {
        return;
    }

    if ([adid isEqualToString:selfI.activityState.adid]) {
        return;
    }

    [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                    block:^{
        selfI.activityState.adid = adid;
    }];
    [selfI writeActivityStateI:selfI];
}

- (BOOL)updateAttributionI:(ALTActivityHandler *)selfI
               attribution:(ALTAttribution *)attribution {
    if (attribution == nil) {
        return NO;
    }
    if ([attribution isEqual:selfI.attribution]) {
        return NO;
    }
    // copy attribution property
    //  to avoid using the same object for the delegate
    selfI.attribution = attribution;
    [selfI writeAttributionI:selfI];

    if (selfI.alltrackDelegate == nil) {
        return NO;
    }

    if (![selfI.alltrackDelegate respondsToSelector:@selector(alltrackAttributionChanged:)]) {
        return NO;
    }

    return YES;
}

- (void)setEnabledI:(ALTActivityHandler *)selfI enabled:(BOOL)enabled {
    // compare with the saved or internal state
    if (![selfI hasChangedStateI:selfI
                   previousState:[selfI isEnabled]
                       nextState:enabled
                     trueMessage:@"Alltrack already enabled"
                    falseMessage:@"Alltrack already disabled"]) {
        return;
    }

    // If user is forgotten, forbid re-enabling.
    if (enabled) {
        if ([selfI isGdprForgottenI:selfI]) {
            [selfI.logger debug:@"Re-enabling SDK for forgotten user not allowed"];
            return;
        }
    }

    // save new enabled state in internal state
    selfI.internalState.enabled = enabled;

    if (selfI.activityState == nil) {
        [selfI checkStatusI:selfI
               pausingState:!enabled
              pausingMessage:@"Handlers will start as paused due to the SDK being disabled"
        remainsPausedMessage:@"Handlers will still start as paused"
            unPausingMessage:@"Handlers will start as active due to the SDK being enabled"];
        return;
    }

    // Save new enabled state in activity state.
    [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                    block:^{
        selfI.activityState.enabled = enabled;
    }];
    [selfI writeActivityStateI:selfI];

    // Check if upon enabling install has been tracked.
    if (enabled) {
        if ([ALTUserDefaults getGdprForgetMe]) {
            [selfI setGdprForgetMe];
        } else {
            [selfI processCoppaComplianceI:selfI];
            if ([ALTUserDefaults getDisableThirdPartySharing]) {
                [selfI disableThirdPartySharing];
            }
            if (selfI.savedPreLaunch.preLaunchAlltrackThirdPartySharingArray != nil) {
                for (ALTThirdPartySharing *thirdPartySharing
                     in selfI.savedPreLaunch.preLaunchAlltrackThirdPartySharingArray)
                {
                    [selfI trackThirdPartySharingI:selfI thirdPartySharing:thirdPartySharing];
                }

                selfI.savedPreLaunch.preLaunchAlltrackThirdPartySharingArray = nil;
            }
            if (selfI.savedPreLaunch.lastMeasurementConsentTracked != nil) {
                [selfI
                    trackMeasurementConsent:
                        [selfI.savedPreLaunch.lastMeasurementConsentTracked boolValue]];

                selfI.savedPreLaunch.lastMeasurementConsentTracked = nil;
            }

            [selfI checkLinkMeI:selfI];
        }

        if (![ALTUserDefaults getInstallTracked]) {
            double now = [NSDate.date timeIntervalSince1970];
            [self trackNewSessionI:now withActivityHandler:selfI];
        }
        NSData *deviceToken = [ALTUserDefaults getPushTokenData];
        if (deviceToken != nil && ![selfI.activityState.deviceToken isEqualToString:[ALTUtil convertDeviceToken:deviceToken]]) {
            [self setDeviceToken:deviceToken];
        }
        NSString *pushToken = [ALTUserDefaults getPushTokenString];
        if (pushToken != nil && ![selfI.activityState.deviceToken isEqualToString:pushToken]) {
            [self setPushToken:pushToken];
        }
        if (selfI.alltrackConfig.allowiAdInfoReading == YES) {
            [selfI checkForiAdI:selfI];
        }
        if (selfI.alltrackConfig.allowAdServicesInfoReading == YES) {
            [selfI checkForAdServicesAttributionI:selfI];
        }
    }

    [selfI checkStatusI:selfI
           pausingState:!enabled
          pausingMessage:@"Pausing handlers due to SDK being disabled"
    remainsPausedMessage:@"Handlers remain paused"
        unPausingMessage:@"Resuming handlers due to SDK being enabled"];
}

- (void)checkForiAdI:(ALTActivityHandler *)selfI {
    [ALTUtil checkForiAd:selfI queue:selfI.internalQueue];
}

- (BOOL)shouldFetchAdServicesI:(ALTActivityHandler *)selfI {
    if (selfI.alltrackConfig.allowAdServicesInfoReading == NO) {
        return NO;
    }
    
    // Fetch if no attribution OR not sent to backend yet
    if ([ALTUserDefaults getAdServicesTracked]) {
        [selfI.logger debug:@"AdServices attribution info already read"];
    }
    return (selfI.attribution == nil || ![ALTUserDefaults getAdServicesTracked]);
}

- (void)checkForAdServicesAttributionI:(ALTActivityHandler *)selfI {
    if (@available(iOS 14.3, tvOS 14.3, *)) {
        if ([selfI shouldFetchAdServicesI:selfI]) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSError *error = nil;
                NSString *token = [ALTUtil fetchAdServicesAttribution:&error];
                [selfI setAdServicesAttributionToken:token error:error];
            });
        }
    }
}

- (void)setOfflineModeI:(ALTActivityHandler *)selfI
                offline:(BOOL)offline {
    // compare with the internal state
    if (![selfI hasChangedStateI:selfI
                   previousState:[selfI.internalState isOffline]
                       nextState:offline
                     trueMessage:@"Alltrack already in offline mode"
                    falseMessage:@"Alltrack already in online mode"])
    {
        return;
    }

    // save new offline state in internal state
    selfI.internalState.offline = offline;

    if (selfI.activityState == nil) {
        [selfI checkStatusI:selfI
               pausingState:offline
             pausingMessage:@"Handlers will start paused due to SDK being offline"
       remainsPausedMessage:@"Handlers will still start as paused"
           unPausingMessage:@"Handlers will start as active due to SDK being online"];
        return;
    }

    [selfI checkStatusI:selfI
           pausingState:offline
         pausingMessage:@"Pausing handlers to put SDK offline mode"
   remainsPausedMessage:@"Handlers remain paused"
       unPausingMessage:@"Resuming handlers to put SDK in online mode"];
}

- (BOOL)hasChangedStateI:(ALTActivityHandler *)selfI
           previousState:(BOOL)previousState
               nextState:(BOOL)nextState
             trueMessage:(NSString *)trueMessage
            falseMessage:(NSString *)falseMessage
{
    if (previousState != nextState) {
        return YES;
    }

    if (previousState) {
        [selfI.logger debug:trueMessage];
    } else {
        [selfI.logger debug:falseMessage];
    }

    return NO;
}

- (void)checkStatusI:(ALTActivityHandler *)selfI
        pausingState:(BOOL)pausingState
      pausingMessage:(NSString *)pausingMessage
remainsPausedMessage:(NSString *)remainsPausedMessage
    unPausingMessage:(NSString *)unPausingMessage
{
    // it is changing from an active state to a pause state
    if (pausingState) {
        [selfI.logger info:pausingMessage];
    }
    // check if it's remaining in a pause state
    else if ([selfI pausedI:selfI sdkClickHandlerOnly:NO]) {
        // including the sdk click handler
        if ([selfI pausedI:selfI sdkClickHandlerOnly:YES]) {
            [selfI.logger info:remainsPausedMessage];
        } else {
            // or except it
            [selfI.logger info:[remainsPausedMessage stringByAppendingString:@", except the Sdk Click Handler"]];
        }
    } else {
        // it is changing from a pause state to an active state
        [selfI.logger info:unPausingMessage];
    }

    [selfI updateHandlersStatusAndSendI:selfI];
}

- (void)appWillOpenUrlI:(ALTActivityHandler *)selfI
                    url:(NSURL *)url
              clickTime:(NSDate *)clickTime {
    if (![selfI isEnabledI:selfI]) {
        return;
    }
    if ([ALTUtil isNull:url]) {
        return;
    }
    if (![ALTUtil isDeeplinkValid:url]) {
        return;
    }

    NSArray *queryArray = [url.query componentsSeparatedByString:@"&"];
    if (queryArray == nil) {
        queryArray = @[];
    }

    NSMutableDictionary *alltrackDeepLinks = [NSMutableDictionary dictionary];
    ALTAttribution *deeplinkAttribution = [[ALTAttribution alloc] init];
    for (NSString *fieldValuePair in queryArray) {
        [selfI readDeeplinkQueryStringI:selfI queryString:fieldValuePair alltrackDeepLinks:alltrackDeepLinks attribution:deeplinkAttribution];
    }

    double now = [NSDate.date timeIntervalSince1970];
    [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                    block:^{
        double lastInterval = now - selfI.activityState.lastActivity;
        selfI.activityState.lastInterval = lastInterval;
    }];
    ALTPackageBuilder *clickBuilder = [[ALTPackageBuilder alloc]
                                       initWithPackageParams:selfI.packageParams
                                                activityState:selfI.activityState
                                                config:selfI.alltrackConfig
                                                sessionParameters:selfI.sessionParameters
                                                trackingStatusManager:self.trackingStatusManager
                                                createdAt:now];

    clickBuilder.deeplinkParameters = [alltrackDeepLinks copy];
    clickBuilder.attribution = deeplinkAttribution;
    clickBuilder.clickTime = clickTime;
    clickBuilder.deeplink = [url absoluteString];

    ALTActivityPackage *clickPackage = [clickBuilder buildClickPackage:@"deeplink"];
    [selfI.sdkClickHandler sendSdkClick:clickPackage];
}

- (BOOL)readDeeplinkQueryStringI:(ALTActivityHandler *)selfI
                     queryString:(NSString *)queryString
                 alltrackDeepLinks:(NSMutableDictionary*)alltrackDeepLinks
                     attribution:(ALTAttribution *)deeplinkAttribution
{
    NSArray* pairComponents = [queryString componentsSeparatedByString:@"="];
    if (pairComponents.count != 2) return NO;

    NSString* key = [pairComponents objectAtIndex:0];
    if (![key hasPrefix:kAlltrackPrefix]) return NO;

    NSString* keyDecoded = [key altUrlDecode];

    NSString* value = [pairComponents objectAtIndex:1];
    if (value.length == 0) return NO;

    NSString* valueDecoded = [value altUrlDecode];
    if (!valueDecoded) return NO;

    NSString* keyWOutPrefix = [keyDecoded substringFromIndex:kAlltrackPrefix.length];
    if (keyWOutPrefix.length == 0) return NO;

    if (![selfI trySetAttributionDeeplink:deeplinkAttribution withKey:keyWOutPrefix withValue:valueDecoded]) {
        [alltrackDeepLinks setObject:valueDecoded forKey:keyWOutPrefix];
    }

    return YES;
}

- (BOOL)trySetAttributionDeeplink:(ALTAttribution *)deeplinkAttribution
                          withKey:(NSString *)key
                        withValue:(NSString*)value
{
    if ([key isEqualToString:@"tracker"]) {
        deeplinkAttribution.trackerName = value;
        return YES;
    }

    if ([key isEqualToString:@"campaign"]) {
        deeplinkAttribution.campaign = value;
        return YES;
    }

    if ([key isEqualToString:@"adgroup"]) {
        deeplinkAttribution.adgroup = value;
        return YES;
    }

    if ([key isEqualToString:@"creative"]) {
        deeplinkAttribution.creative = value;
        return YES;
    }

    return NO;
}

- (void)setDeviceTokenI:(ALTActivityHandler *)selfI
            deviceToken:(NSData *)deviceToken {
    if (![selfI isEnabledI:selfI]) {
        return;
    }
    if (!selfI.activityState) {
        return;
    }
    if (selfI.activityState.isGdprForgotten) {
        return;
    }

    NSString *deviceTokenString = [ALTUtil convertDeviceToken:deviceToken];

    if (deviceTokenString == nil) {
        return;
    }

    if ([deviceTokenString isEqualToString:selfI.activityState.deviceToken]) {
        return;
    }

    // save new push token
    [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                    block:^{
        selfI.activityState.deviceToken = deviceTokenString;
    }];
    [selfI writeActivityStateI:selfI];

    // send info package
    double now = [NSDate.date timeIntervalSince1970];
    ALTPackageBuilder *infoBuilder = [[ALTPackageBuilder alloc]
                                      initWithPackageParams:selfI.packageParams
                                                activityState:selfI.activityState
                                                config:selfI.alltrackConfig
                                                sessionParameters:selfI.sessionParameters
                                                trackingStatusManager:self.trackingStatusManager
                                                createdAt:now];

    ALTActivityPackage *infoPackage = [infoBuilder buildInfoPackage:@"push"];

    [selfI.packageHandler addPackage:infoPackage];

    // if push token was cached, remove it
    [ALTUserDefaults removePushToken];

    if (selfI.alltrackConfig.eventBufferingEnabled) {
        [selfI.logger info:@"Buffered info %@", infoPackage.suffix];
    } else {
        [selfI.packageHandler sendFirstPackage];
    }
}

- (void)setPushTokenI:(ALTActivityHandler *)selfI
            pushToken:(NSString *)pushToken {
    if (![selfI isEnabledI:selfI]) {
        return;
    }
    if (!selfI.activityState) {
        return;
    }
    if (selfI.activityState.isGdprForgotten) {
        return;
    }
    if (pushToken == nil) {
        return;
    }
    if ([pushToken isEqualToString:selfI.activityState.deviceToken]) {
        return;
    }

    // save new push token
    [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                    block:^{
        selfI.activityState.deviceToken = pushToken;
    }];
    [selfI writeActivityStateI:selfI];

    // send info package
    double now = [NSDate.date timeIntervalSince1970];
    ALTPackageBuilder *infoBuilder = [[ALTPackageBuilder alloc]
                                      initWithPackageParams:selfI.packageParams
                                                activityState:selfI.activityState
                                                config:selfI.alltrackConfig
                                                sessionParameters:selfI.sessionParameters
                                                trackingStatusManager:self.trackingStatusManager
                                                createdAt:now];

    ALTActivityPackage *infoPackage = [infoBuilder buildInfoPackage:@"push"];
    [selfI.packageHandler addPackage:infoPackage];

    // if push token was cached, remove it
    [ALTUserDefaults removePushToken];

    if (selfI.alltrackConfig.eventBufferingEnabled) {
        [selfI.logger info:@"Buffered info %@", infoPackage.suffix];
    } else {
        [selfI.packageHandler sendFirstPackage];
    }
}

- (void)setGdprForgetMeI:(ALTActivityHandler *)selfI {
    if (![selfI isEnabledI:selfI]) {
        return;
    }
    if (!selfI.activityState) {
        return;
    }
    if (selfI.activityState.isGdprForgotten == YES) {
        [ALTUserDefaults removeGdprForgetMe];
        return;
    }

    [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                    block:^{
        selfI.activityState.isGdprForgotten = YES;
    }];
    [selfI writeActivityStateI:selfI];

    // Send GDPR package
    double now = [NSDate.date timeIntervalSince1970];
    ALTPackageBuilder *gdprBuilder = [[ALTPackageBuilder alloc]
                                      initWithPackageParams:selfI.packageParams
                                            activityState:selfI.activityState
                                            config:selfI.alltrackConfig
                                            sessionParameters:selfI.sessionParameters
                                            trackingStatusManager:self.trackingStatusManager
                                            createdAt:now];

    ALTActivityPackage *gdprPackage = [gdprBuilder buildGdprPackage];
    [selfI.packageHandler addPackage:gdprPackage];

    [ALTUserDefaults removeGdprForgetMe];

    if (selfI.alltrackConfig.eventBufferingEnabled) {
        [selfI.logger info:@"Buffered gdpr %@", gdprPackage.suffix];
    } else {
        [selfI.packageHandler sendFirstPackage];
    }
}

- (void)setTrackingStateOptedOutI:(ALTActivityHandler *)selfI {
    // In case of web opt out, once response from backend arrives isGdprForgotten field in this moment defaults to NO.
    // Set it to YES regardless of state, since at this moment it should be YES.
    [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                    block:^{
        selfI.activityState.isGdprForgotten = YES;
    }];
    [selfI writeActivityStateI:selfI];

    [selfI setEnabled:NO];
    [selfI.packageHandler flush];
}

- (void)checkLinkMeI:(ALTActivityHandler *)selfI {
#if TARGET_OS_IOS
    if (@available(iOS 15.0, *)) {
        if (selfI.alltrackConfig.linkMeEnabled == NO) {
            [self.logger debug:@"LinkMe not allowed by client"];
            return;
        }
        if ([ALTUserDefaults getLinkMeChecked] == YES) {
            [self.logger debug:@"LinkMe already checked"];
            return;
        }
        if (selfI.internalState.isFirstLaunch == NO) {
            [self.logger debug:@"LinkMe only valid for install"];
            return;
        }
        if ([ALTUserDefaults getGdprForgetMe]) {
            [self.logger debug:@"LinkMe not happening for GDPR forgotten user"];
            return;
        }
        
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        if ([pasteboard hasURLs] == NO) {
            [self.logger debug:@"LinkMe general board not found"];
            return;
        }
        
        NSURL *pasteboardUrl = [pasteboard URL];
        if (pasteboardUrl == nil) {
            [self.logger debug:@"LinkMe content not found"];
            return;
        }
        
        NSString *pasteboardUrlString = [pasteboardUrl absoluteString];
        if (pasteboardUrlString == nil) {
            [self.logger debug:@"LinkMe content could not be converted to string"];
            return;
        }
        
        // send sdk_click
        double now = [NSDate.date timeIntervalSince1970];
        ALTPackageBuilder *clickBuilder = [[ALTPackageBuilder alloc] initWithPackageParams:selfI.packageParams
                                                                             activityState:selfI.activityState
                                                                                    config:selfI.alltrackConfig
                                                                         sessionParameters:selfI.sessionParameters
                                                                     trackingStatusManager:self.trackingStatusManager
                                                                                 createdAt:now];
        clickBuilder.clickTime = [NSDate dateWithTimeIntervalSince1970:now];
        ALTActivityPackage *clickPackage = [clickBuilder buildClickPackage:@"linkme" linkMeUrl:pasteboardUrlString];
        [selfI.sdkClickHandler sendSdkClick:clickPackage];
        
        [ALTUserDefaults setLinkMeChecked];
    } else {
        [self.logger warn:@"LinkMe feature is supported on iOS 15.0 and above"];
    }
#endif
}

#pragma mark - private

- (BOOL)isEnabledI:(ALTActivityHandler *)selfI {
    if (selfI.activityState != nil) {
        return selfI.activityState.enabled;
    } else {
        return [selfI.internalState isEnabled];
    }
}

- (BOOL)isGdprForgottenI:(ALTActivityHandler *)selfI {
    if (selfI.activityState != nil) {
        return selfI.activityState.isGdprForgotten;
    } else {
        return NO;
    }
}

- (BOOL)itHasToUpdatePackagesI:(ALTActivityHandler *)selfI {
    if (selfI.activityState != nil) {
        return selfI.activityState.updatePackages;
    } else {
        return [selfI.internalState itHasToUpdatePackages];
    }
}

// returns whether or not the activity state should be written
- (BOOL)updateActivityStateI:(ALTActivityHandler *)selfI
                         now:(double)now {
    if (![selfI checkActivityStateI:selfI]) return NO;

    double lastInterval = now - selfI.activityState.lastActivity;

    // ignore late updates
    if (lastInterval > kSessionInterval) return NO;

    [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                    block:^{
        selfI.activityState.lastActivity = now;
    }];

    if (lastInterval < 0) {
        [selfI.logger error:@"Time travel!"];
        return YES;
    } else {
        [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                        block:^{
            selfI.activityState.sessionLength += lastInterval;
            selfI.activityState.timeSpent += lastInterval;
        }];
    }

    return YES;
}

- (void)writeActivityStateI:(ALTActivityHandler *)selfI
{
    [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                    block:^{
        if (selfI.activityState == nil) {
            return;
        }
        [ALTUtil writeObject:selfI.activityState
                    fileName:kActivityStateFilename
                  objectName:@"Activity state"
                  syncObject:[ALTActivityState class]];
    }];
}

- (void)teardownActivityStateS
{
    @synchronized ([ALTActivityState class]) {
        if (self.activityState == nil) {
            return;
        }
        self.activityState = nil;
    }
}

- (void)writeAttributionI:(ALTActivityHandler *)selfI {
    @synchronized ([ALTAttribution class]) {
        if (selfI.attribution == nil) {
            return;
        }
        [ALTUtil writeObject:selfI.attribution
                    fileName:kAttributionFilename
                  objectName:@"Attribution"
                  syncObject:[ALTAttribution class]];
    }
}

- (void)teardownAttributionS
{
    @synchronized ([ALTAttribution class]) {
        if (self.attribution == nil) {
            return;
        }
        self.attribution = nil;
    }
}

- (void)readActivityState {
    [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                    block:^{
        [NSKeyedUnarchiver setClass:[ALTActivityState class] forClassName:@"AIActivityState"];
        self.activityState = [ALTUtil readObject:kActivityStateFilename
                                      objectName:@"Activity state"
                                           class:[ALTActivityState class]
                                      syncObject:[ALTActivityState class]];
    }];
}

- (void)readAttribution {
    self.attribution = [ALTUtil readObject:kAttributionFilename
                                objectName:@"Attribution"
                                     class:[ALTAttribution class]
                                syncObject:[ALTAttribution class]];
}

- (void)writeSessionCallbackParametersI:(ALTActivityHandler *)selfI {
    @synchronized ([ALTSessionParameters class]) {
        if (selfI.sessionParameters == nil) {
            return;
        }
        [ALTUtil writeObject:selfI.sessionParameters.callbackParameters
                    fileName:kSessionCallbackParametersFilename
                  objectName:@"Session Callback parameters"
                  syncObject:[ALTSessionParameters class]];
    }
}

- (void)writeSessionPartnerParametersI:(ALTActivityHandler *)selfI {
    @synchronized ([ALTSessionParameters class]) {
        if (selfI.sessionParameters == nil) {
            return;
        }
        [ALTUtil writeObject:selfI.sessionParameters.partnerParameters
                    fileName:kSessionPartnerParametersFilename
                  objectName:@"Session Partner parameters"
                  syncObject:[ALTSessionParameters class]];
    }
}

- (void)teardownAllSessionParametersS {
    @synchronized ([ALTSessionParameters class]) {
        if (self.sessionParameters == nil) {
            return;
        }
        [self.sessionParameters.callbackParameters removeAllObjects];
        [self.sessionParameters.partnerParameters removeAllObjects];
        self.sessionParameters = nil;
    }
}

- (void)readSessionCallbackParametersI:(ALTActivityHandler *)selfI {
    selfI.sessionParameters.callbackParameters = [ALTUtil readObject:kSessionCallbackParametersFilename
                                                         objectName:@"Session Callback parameters"
                                                              class:[NSDictionary class]
                                                         syncObject:[ALTSessionParameters class]];
}

- (void)readSessionPartnerParametersI:(ALTActivityHandler *)selfI {
    selfI.sessionParameters.partnerParameters = [ALTUtil readObject:kSessionPartnerParametersFilename
                                                        objectName:@"Session Partner parameters"
                                                             class:[NSDictionary class]
                                                        syncObject:[ALTSessionParameters class]];
}

# pragma mark - handlers status
- (void)updateHandlersStatusAndSendI:(ALTActivityHandler *)selfI {
    // check if it should stop sending
    if (![selfI toSendI:selfI]) {
        [selfI pauseSendingI:selfI];
        return;
    }

    [selfI resumeSendingI:selfI];

    // try to send if it's the first launch and it hasn't received the session response
    //  even if event buffering is enabled
    if ([selfI.internalState isFirstLaunch] &&
        [selfI.internalState hasSessionResponseNotBeenProcessed])
    {
        [selfI.packageHandler sendFirstPackage];
    }

    // try to send
    if (!selfI.alltrackConfig.eventBufferingEnabled) {
        [selfI.packageHandler sendFirstPackage];
    }
}

- (void)pauseSendingI:(ALTActivityHandler *)selfI {
    [selfI.attributionHandler pauseSending];
    [selfI.packageHandler pauseSending];
    // the conditions to pause the sdk click handler are less restrictive
    // it's possible for the sdk click handler to be active while others are paused
    if (![selfI toSendI:selfI sdkClickHandlerOnly:YES]) {
        [selfI.sdkClickHandler pauseSending];
    } else {
        [selfI.sdkClickHandler resumeSending];
    }
}

- (void)resumeSendingI:(ALTActivityHandler *)selfI {
    [selfI.attributionHandler resumeSending];
    [selfI.packageHandler resumeSending];
    [selfI.sdkClickHandler resumeSending];
}

- (BOOL)pausedI:(ALTActivityHandler *)selfI {
    return [selfI pausedI:selfI sdkClickHandlerOnly:NO];
}

- (BOOL)pausedI:(ALTActivityHandler *)selfI
sdkClickHandlerOnly:(BOOL)sdkClickHandlerOnly
{
    if (sdkClickHandlerOnly) {
        // sdk click handler is paused if either:
        return [selfI.internalState isOffline] ||    // it's offline
         ![selfI isEnabledI:selfI];                  // is disabled
    }
    // other handlers are paused if either:
    return [selfI.internalState isOffline] ||        // it's offline
            ![selfI isEnabledI:selfI] ||             // is disabled
            [selfI.internalState isInDelayedStart];      // is in delayed start
}

- (BOOL)toSendI:(ALTActivityHandler *)selfI {
    return [selfI toSendI:selfI sdkClickHandlerOnly:NO];
}

- (BOOL)toSendI:(ALTActivityHandler *)selfI
sdkClickHandlerOnly:(BOOL)sdkClickHandlerOnly
{
    // don't send when it's paused
    if ([selfI pausedI:selfI sdkClickHandlerOnly:sdkClickHandlerOnly]) {
        return NO;
    }

    // has the option to send in the background -> is to send
    if (selfI.alltrackConfig.sendInBackground) {
        return YES;
    }

    // doesn't have the option -> depends on being on the background/foreground
    return [selfI.internalState isInForeground];
}

- (void)setAskingAttributionI:(ALTActivityHandler *)selfI
            askingAttribution:(BOOL)askingAttribution
{
    [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                    block:^{
        selfI.activityState.askingAttribution = askingAttribution;
    }];
    [selfI writeActivityStateI:selfI];
}

# pragma mark - timer
- (void)startForegroundTimerI:(ALTActivityHandler *)selfI {
    // don't start the timer when it's disabled
    if (![selfI isEnabledI:selfI]) {
        return;
    }

    [selfI.foregroundTimer resume];
}

- (void)stopForegroundTimerI:(ALTActivityHandler *)selfI {
    [selfI.foregroundTimer suspend];
}

- (void)foregroundTimerFiredI:(ALTActivityHandler *)selfI {
    // stop the timer cycle when it's disabled
    if (![selfI isEnabledI:selfI]) {
        [selfI stopForegroundTimerI:selfI];
        return;
    }

    if ([selfI toSendI:selfI]) {
        [selfI.packageHandler sendFirstPackage];
    }

    double now = [NSDate.date timeIntervalSince1970];
    if ([selfI updateActivityStateI:selfI now:now]) {
        [selfI writeActivityStateI:selfI];
    }

    [selfI.trackingStatusManager checkForNewAttStatus];
}

- (void)startBackgroundTimerI:(ALTActivityHandler *)selfI {
    if (selfI.backgroundTimer == nil) {
        return;
    }

    // check if it can send in the background
    if (![selfI toSendI:selfI]) {
        return;
    }

    // background timer already started
    if ([selfI.backgroundTimer fireIn] > 0) {
        return;
    }

    [selfI.backgroundTimer startIn:kBackgroundTimerInterval];
}

- (void)stopBackgroundTimerI:(ALTActivityHandler *)selfI {
    if (selfI.backgroundTimer == nil) {
        return;
    }

    [selfI.backgroundTimer cancel];
}

- (void)backgroundTimerFiredI:(ALTActivityHandler *)selfI {
    if ([selfI toSendI:selfI]) {
        [selfI.packageHandler sendFirstPackage];
    }
}

#pragma mark - delay
- (void)delayStartI:(ALTActivityHandler *)selfI {
    // it's not configured to start delayed or already finished
    if ([selfI.internalState isNotInDelayedStart]) {
        return;
    }

    // the delay has already started
    if ([selfI itHasToUpdatePackagesI:selfI]) {
        return;
    }

    // check against max start delay
    double delayStart = selfI.alltrackConfig.delayStart;
    double maxDelayStart = [ALTAlltrackFactory maxDelayStart];

    if (delayStart > maxDelayStart) {
        NSString * delayStartFormatted = [ALTUtil secondsNumberFormat:delayStart];
        NSString * maxDelayStartFormatted = [ALTUtil secondsNumberFormat:maxDelayStart];

        [selfI.logger warn:@"Delay start of %@ seconds bigger than max allowed value of %@ seconds", delayStartFormatted, maxDelayStartFormatted];
        delayStart = maxDelayStart;
    }

    NSString * delayStartFormatted = [ALTUtil secondsNumberFormat:delayStart];
    [selfI.logger info:@"Waiting %@ seconds before starting first session", delayStartFormatted];

    [selfI.delayStartTimer startIn:delayStart];

    selfI.internalState.updatePackages = YES;

    if (selfI.activityState != nil) {
        [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                        block:^{
            selfI.activityState.updatePackages = YES;
        }];
        [selfI writeActivityStateI:selfI];
    }
}

- (void)sendFirstPackagesI:(ALTActivityHandler *)selfI {
    if ([selfI.internalState isNotInDelayedStart]) {
        [selfI.logger info:@"Start delay expired or never configured"];
        return;
    }
    // update packages in queue
    [selfI updatePackagesI:selfI];
    // no longer is in delay start
    selfI.internalState.delayStart = NO;
    // cancel possible still running timer if it was called by user
    [selfI.delayStartTimer cancel];
    // and release timer
    selfI.delayStartTimer = nil;
    // update the status and try to send first package
    [selfI updateHandlersStatusAndSendI:selfI];
}

- (void)updatePackagesI:(ALTActivityHandler *)selfI {
    // update activity packages
    [selfI.packageHandler updatePackages:selfI.sessionParameters];
    // no longer needs to update packages
    selfI.internalState.updatePackages = NO;
    if (selfI.activityState != nil) {
        [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                        block:^{
            selfI.activityState.updatePackages = NO;
        }];
        [selfI writeActivityStateI:selfI];
    }
}

#pragma mark - session parameters
- (void)addSessionCallbackParameterI:(ALTActivityHandler *)selfI
                                 key:(NSString *)key
                              value:(NSString *)value
{
    if (![ALTUtil isValidParameter:key
                  attributeType:@"key"
                  parameterName:@"Session Callback"]) return;

    if (![ALTUtil isValidParameter:value
                  attributeType:@"value"
                  parameterName:@"Session Callback"]) return;

    if (selfI.sessionParameters.callbackParameters == nil) {
        selfI.sessionParameters.callbackParameters = [NSMutableDictionary dictionary];
    }

    NSString * oldValue = [selfI.sessionParameters.callbackParameters objectForKey:key];

    if (oldValue != nil) {
        if ([oldValue isEqualToString:value]) {
            [selfI.logger verbose:@"Key %@ already present with the same value", key];
            return;
        }
        [selfI.logger warn:@"Key %@ will be overwritten", key];
    }

    [selfI.sessionParameters.callbackParameters setObject:value forKey:key];

    [selfI writeSessionCallbackParametersI:selfI];
}

- (void)addSessionPartnerParameterI:(ALTActivityHandler *)selfI
                               key:(NSString *)key
                             value:(NSString *)value
{
    if (![ALTUtil isValidParameter:key
                     attributeType:@"key"
                     parameterName:@"Session Partner"]) return;

    if (![ALTUtil isValidParameter:value
                     attributeType:@"value"
                     parameterName:@"Session Partner"]) return;

    if (selfI.sessionParameters.partnerParameters == nil) {
        selfI.sessionParameters.partnerParameters = [NSMutableDictionary dictionary];
    }

    NSString * oldValue = [selfI.sessionParameters.partnerParameters objectForKey:key];

    if (oldValue != nil) {
        if ([oldValue isEqualToString:value]) {
            [selfI.logger verbose:@"Key %@ already present with the same value", key];
            return;
        }
        [selfI.logger warn:@"Key %@ will be overwritten", key];
    }


    [selfI.sessionParameters.partnerParameters setObject:value forKey:key];

    [selfI writeSessionPartnerParametersI:selfI];
}

- (void)removeSessionCallbackParameterI:(ALTActivityHandler *)selfI
                                    key:(NSString *)key {
    if (![ALTUtil isValidParameter:key
                     attributeType:@"key"
                     parameterName:@"Session Callback"]) return;

    if (selfI.sessionParameters.callbackParameters == nil) {
        [selfI.logger warn:@"Session Callback parameters are not set"];
        return;
    }

    NSString * oldValue = [selfI.sessionParameters.callbackParameters objectForKey:key];
    if (oldValue == nil) {
        [selfI.logger warn:@"Key %@ does not exist", key];
        return;
    }

    [selfI.logger debug:@"Key %@ will be removed", key];
    [selfI.sessionParameters.callbackParameters removeObjectForKey:key];
    [selfI writeSessionCallbackParametersI:selfI];
}

- (void)removeSessionPartnerParameterI:(ALTActivityHandler *)selfI
                                   key:(NSString *)key {
    if (![ALTUtil isValidParameter:key
                     attributeType:@"key"
                     parameterName:@"Session Partner"]) return;

    if (selfI.sessionParameters.partnerParameters == nil) {
        [selfI.logger warn:@"Session Partner parameters are not set"];
        return;
    }

    NSString * oldValue = [selfI.sessionParameters.partnerParameters objectForKey:key];
    if (oldValue == nil) {
        [selfI.logger warn:@"Key %@ does not exist", key];
        return;
    }

    [selfI.logger debug:@"Key %@ will be removed", key];
    [selfI.sessionParameters.partnerParameters removeObjectForKey:key];
    [selfI writeSessionPartnerParametersI:selfI];
}

- (void)resetSessionCallbackParametersI:(ALTActivityHandler *)selfI {
    if (selfI.sessionParameters.callbackParameters == nil) {
        [selfI.logger warn:@"Session Callback parameters are not set"];
        return;
    }
    selfI.sessionParameters.callbackParameters = nil;
    [selfI writeSessionCallbackParametersI:selfI];
}

- (void)resetSessionPartnerParametersI:(ALTActivityHandler *)selfI {
    if (selfI.sessionParameters.partnerParameters == nil) {
        [selfI.logger warn:@"Session Partner parameters are not set"];
        return;
    }
    selfI.sessionParameters.partnerParameters = nil;
    [selfI writeSessionPartnerParametersI:selfI];
}

- (void)preLaunchActionsI:(ALTActivityHandler *)selfI
    preLaunchActionsArray:(NSArray*)preLaunchActionsArray
{
    if (preLaunchActionsArray == nil) {
        return;
    }
    for (activityHandlerBlockI activityHandlerActionI in preLaunchActionsArray) {
        activityHandlerActionI(selfI);
    }
}

#pragma mark - notifications
- (void)addNotificationObserver {
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;

    [center removeObserver:self];
    [center addObserver:self
               selector:@selector(applicationDidBecomeActive)
                   name:UIApplicationDidBecomeActiveNotification
                 object:nil];

    [center addObserver:self
               selector:@selector(applicationWillResignActive)
                   name:UIApplicationWillResignActiveNotification
                 object:nil];

    [center addObserver:self
               selector:@selector(removeNotificationObserver)
                   name:UIApplicationWillTerminateNotification
                 object:nil];
}

- (void)removeNotificationObserver {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - checks

- (BOOL)checkTransactionIdI:(ALTActivityHandler *)selfI
              transactionId:(NSString *)transactionId {
    if (transactionId == nil || transactionId.length == 0) {
        return YES; // no transaction ID given
    }

    if ([selfI.activityState findTransactionId:transactionId]) {
        [selfI.logger info:@"Skipping duplicate transaction ID '%@'", transactionId];
        [selfI.logger verbose:@"Found transaction ID in %@", selfI.activityState.transactionIds];
        return NO; // transaction ID found -> used already
    }
    
    [selfI.activityState addTransactionId:transactionId];
    [selfI.logger verbose:@"Added transaction ID %@", selfI.activityState.transactionIds];
    // activity state will get written by caller
    return YES;
}

- (BOOL)checkEventI:(ALTActivityHandler *)selfI
              event:(ALTEvent *)event {
    if (event == nil) {
        [selfI.logger error:@"Event missing"];
        return NO;
    }

    if (![event isValid]) {
        [selfI.logger error:@"Event not initialized correctly"];
        return NO;
    }

    return YES;
}

- (BOOL)checkActivityStateI:(ALTActivityHandler *)selfI {
    if (selfI.activityState == nil) {
        [selfI.logger error:@"Missing activity state"];
        return NO;
    }
    return YES;
}

- (BOOL)checkAdRevenueI:(ALTActivityHandler *)selfI
              adRevenue:(ALTAdRevenue *)adRevenue {
    if (adRevenue == nil) {
        [selfI.logger error:@"Ad revenue missing"];
        return NO;
    }

    if (![adRevenue isValid]) {
        [selfI.logger error:@"Ad revenue not initialized correctly"];
        return NO;
    }

    return YES;
}

- (void)checkConversionValue:(ALTResponseData *)responseData {
    if (!self.alltrackConfig.isSKAdNetworkHandlingActive) {
        return;
    }
    if (responseData.jsonResponse == nil) {
        return;
    }

    NSNumber *conversionValue = [responseData.jsonResponse objectForKey:@"skadn_conv_value"];
    if (!conversionValue) {
        return;
    }

    NSString *coarseValue = [responseData.jsonResponse objectForKey:@"skadn_coarse_value"];
    NSNumber *lockWindow = [responseData.jsonResponse objectForKey:@"skadn_lock_window"];

    [[ALTSKAdNetwork getInstance] altUpdateConversionValue:[conversionValue intValue]
                                               coarseValue:coarseValue
                                                lockWindow:lockWindow
                                         completionHandler:^(NSError *error) {
        if (error) {
            // handle error
        } else {
            // ping old callback if implemented
            if ([self.alltrackDelegate respondsToSelector:@selector(alltrackConversionValueUpdated:)]) {
                [self.logger debug:@"Launching alltrackConversionValueUpdated: delegate"];
                [ALTUtil launchInMainThread:self.alltrackDelegate
                                   selector:@selector(alltrackConversionValueUpdated:)
                                 withObject:conversionValue];
            }
            // ping new callback if implemented
            if ([self.alltrackDelegate respondsToSelector:@selector(alltrackConversionValueUpdated:coarseValue:lockWindow:)]) {
                [self.logger debug:@"Launching alltrackConversionValueUpdated:coarseValue:lockWindow: delegate"];
                [ALTUtil launchInMainThread:^{
                    [self.alltrackDelegate alltrackConversionValueUpdated:conversionValue
                                                          coarseValue:coarseValue
                                                           lockWindow:lockWindow];
                }];
            }
        }
    }];
}

- (void)updateAttStatusFromUserCallback:(int)newAttStatusFromUser {
    [self.trackingStatusManager updateAttStatusFromUserCallback:newAttStatusFromUser];
}

- (void)processCoppaComplianceI:(ALTActivityHandler *)selfI {
    if (!selfI.alltrackConfig.coppaCompliantEnabled) {
        [self resetThirdPartySharingCoppaActivityStateI:selfI];
        return;
    }
    
    [self disableThirdPartySharingForCoppaEnabledI:selfI];
}

- (void)disableThirdPartySharingForCoppaEnabledI:(ALTActivityHandler *)selfI {
    if (![selfI shouldDisableThirdPartySharingWhenCoppaEnabled:selfI]) {
        return;
    }
    
    [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                    block:^{
        selfI.activityState.isThirdPartySharingDisabledForCoppa = YES;
    }];
    [selfI writeActivityStateI:selfI];
    
    ALTThirdPartySharing *thirdPartySharing = [[ALTThirdPartySharing alloc] initWithIsEnabledNumberBool:[NSNumber numberWithBool:NO]];
    
    double now = [NSDate.date timeIntervalSince1970];
    
    // build package
    ALTPackageBuilder *tpsBuilder = [[ALTPackageBuilder alloc]
                                     initWithPackageParams:selfI.packageParams
                                     activityState:selfI.activityState
                                     config:selfI.alltrackConfig
                                     sessionParameters:selfI.sessionParameters
                                     trackingStatusManager:self.trackingStatusManager
                                     createdAt:now];
    
    ALTActivityPackage *dtpsPackage = [tpsBuilder buildThirdPartySharingPackage:thirdPartySharing];
    
    [selfI.packageHandler addPackage:dtpsPackage];
    
    if (selfI.alltrackConfig.eventBufferingEnabled) {
        [selfI.logger info:@"Buffered event %@", dtpsPackage.suffix];
    } else {
        [selfI.packageHandler sendFirstPackage];
    }
}

- (void)resetThirdPartySharingCoppaActivityStateI:(ALTActivityHandler *)selfI {
    if (selfI.activityState == nil) {
        return;
    }
    
    if(selfI.activityState.isThirdPartySharingDisabledForCoppa) {
        [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                        block:^{
            selfI.activityState.isThirdPartySharingDisabledForCoppa = NO;
        }];
        [selfI writeActivityStateI:selfI];
    }
}

- (BOOL)shouldDisableThirdPartySharingWhenCoppaEnabled:(ALTActivityHandler *)selfI {
    if (selfI.activityState == nil) {
        return NO;
    }
    if (![selfI isEnabledI:selfI]) {
        return NO;
    }
    if (selfI.activityState.isGdprForgotten) {
        return NO;
    }
    
    return !selfI.activityState.isThirdPartySharingDisabledForCoppa;
}

@end

@interface ALTTrackingStatusManager ()

@property (nonatomic, readonly, weak) ALTActivityHandler *activityHandler;

@end

@implementation ALTTrackingStatusManager
// constructors
- (instancetype)initWithActivityHandler:(ALTActivityHandler *)activityHandler {
    self = [super init];

    _activityHandler = activityHandler;

    return self;
}
// public api
- (BOOL)canGetAttStatus {
    if (@available(iOS 14.0, tvOS 14.0, *)) {
        return YES;
    }
    return NO;
}

- (BOOL)trackingEnabled {
    return [ALTUtil trackingEnabled];
}

- (int)attStatus {
    int readAttStatus = [ALTUtil attStatus];
    [self updateAttStatus:readAttStatus];
    return readAttStatus;
}

- (void)checkForNewAttStatus {
    int readAttStatus = [ALTUtil attStatus];
    BOOL didUpdateAttStatus = [self updateAttStatus:readAttStatus];
    if (!didUpdateAttStatus) {
        return;
    }
    [self.activityHandler trackAttStatusUpdate];
}
- (void)updateAttStatusFromUserCallback:(int)newAttStatusFromUser {
    BOOL didUpdateAttStatus = [self updateAttStatus:newAttStatusFromUser];
    if (!didUpdateAttStatus) {
        return;
    }
    [self.activityHandler trackAttStatusUpdate];
}

// internal methods
- (BOOL)updateAttStatus:(int)readAttStatus {
    if (readAttStatus < 0) {
        return NO;
    }

    if (self.activityHandler == nil || self.activityHandler.activityState == nil) {
        return NO;
    }

    if (readAttStatus == self.activityHandler.activityState.trackingManagerAuthorizationStatus) {
        return NO;
    }

    [ALTUtil launchSynchronisedWithObject:[ALTActivityState class]
                                    block:^{
        self.activityHandler.activityState.trackingManagerAuthorizationStatus = readAttStatus;
    }];
    [self.activityHandler writeActivityState];

    return YES;
}

@end
