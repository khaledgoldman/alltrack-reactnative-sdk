#import "Alltrack.h"
#import "ALTUtil.h"
#import "ALTLogger.h"
#import "ALTUserDefaults.h"
#import "ALTAlltrackFactory.h"
#import "ALTActivityHandler.h"
#import "ALTSKAdNetwork.h"

#if !__has_feature(objc_arc)
#error Alltrack requires ARC
// See README for details: https://github.com/alltrack/ios_sdk/blob/master/README.md
#endif

NSString * const ALTEnvironmentSandbox = @"sandbox";
NSString * const ALTEnvironmentProduction = @"production";

NSString * const ALTAdRevenueSourceAppLovinMAX = @"applovin_max_sdk";
NSString * const ALTAdRevenueSourceMopub = @"mopub";
NSString * const ALTAdRevenueSourceAdMob = @"admob_sdk";
NSString * const ALTAdRevenueSourceIronSource = @"ironsource_sdk";
NSString * const ALTAdRevenueSourceAdMost = @"admost_sdk";
NSString * const ALTAdRevenueSourceUnity = @"unity_sdk";
NSString * const ALTAdRevenueSourceHeliumChartboost = @"helium_chartboost_sdk";
NSString * const ALTAdRevenueSourcePublisher = @"publisher_sdk";

NSString * const ALTUrlStrategyIndia = @"UrlStrategyIndia";
NSString * const ALTUrlStrategyChina = @"UrlStrategyChina";
NSString * const ALTUrlStrategyCn = @"UrlStrategyCn";

NSString * const ALTDataResidencyEU = @"DataResidencyEU";
NSString * const ALTDataResidencyTR = @"DataResidencyTR";
NSString * const ALTDataResidencyUS = @"DataResidencyUS";

@implementation AlltrackTestOptions
@end

@interface Alltrack()

@property (nonatomic, weak) id<ALTLogger> logger;

@property (nonatomic, strong) id<ALTActivityHandler> activityHandler;

@property (nonatomic, strong) ALTSavedPreLaunch *savedPreLaunch;

@end

@implementation Alltrack

#pragma mark - Object lifecycle methods

static Alltrack *defaultInstance = nil;
static dispatch_once_t onceToken = 0;

+ (instancetype)getInstance {
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

    self.activityHandler = nil;
    self.logger = [ALTAlltrackFactory logger];
    self.savedPreLaunch = [[ALTSavedPreLaunch alloc] init];
    return self;
}

#pragma mark - Public static methods

+ (void)appDidLaunch:(ALTConfig *)alltrackConfig {
    @synchronized (self) {
        [[Alltrack getInstance] appDidLaunch:alltrackConfig];
    }
}

+ (void)trackEvent:(ALTEvent *)event {
    @synchronized (self) {
        [[Alltrack getInstance] trackEvent:event];
    }
}

+ (void)trackSubsessionStart {
    @synchronized (self) {
        [[Alltrack getInstance] trackSubsessionStart];
    }
}

+ (void)trackSubsessionEnd {
    @synchronized (self) {
        [[Alltrack getInstance] trackSubsessionEnd];
    }
}

+ (void)setEnabled:(BOOL)enabled {
    @synchronized (self) {
        Alltrack *instance = [Alltrack getInstance];
        [instance setEnabled:enabled];
    }
}

+ (BOOL)isEnabled {
    @synchronized (self) {
        return [[Alltrack getInstance] isEnabled];
    }
}

+ (void)appWillOpenUrl:(NSURL *)url {
    @synchronized (self) {
        [[Alltrack getInstance] appWillOpenUrl:[url copy]];
    }
}

+ (void)setDeviceToken:(NSData *)deviceToken {
    @synchronized (self) {
        [[Alltrack getInstance] setDeviceToken:[deviceToken copy]];
    }
}

+ (void)setPushToken:(NSString *)pushToken {
    @synchronized (self) {
        [[Alltrack getInstance] setPushToken:[pushToken copy]];
    }
}

+ (void)setOfflineMode:(BOOL)enabled {
    @synchronized (self) {
        [[Alltrack getInstance] setOfflineMode:enabled];
    }
}

+ (void)sendAdWordsRequest {
    [[ALTAlltrackFactory logger] warn:@"Send AdWords Request functionality removed"];
}

+ (NSString *)idfa {
    @synchronized (self) {
        return [[Alltrack getInstance] idfa];
    }
}

+ (NSString *)sdkVersion {
    @synchronized (self) {
        return [[Alltrack getInstance] sdkVersion];
    }
}

+ (NSURL *)convertUniversalLink:(NSURL *)url scheme:(NSString *)scheme {
    @synchronized (self) {
        return [[Alltrack getInstance] convertUniversalLink:[url copy] scheme:[scheme copy]];
    }
}

+ (void)sendFirstPackages {
    @synchronized (self) {
        [[Alltrack getInstance] sendFirstPackages];
    }
}

+ (void)addSessionCallbackParameter:(NSString *)key value:(NSString *)value {
    @synchronized (self) {
        [[Alltrack getInstance] addSessionCallbackParameter:[key copy] value:[value copy]];
    }
}

+ (void)addSessionPartnerParameter:(NSString *)key value:(NSString *)value {
    @synchronized (self) {
        [[Alltrack getInstance] addSessionPartnerParameter:[key copy] value:[value copy]];
    }
}

+ (void)removeSessionCallbackParameter:(NSString *)key {
    @synchronized (self) {
        [[Alltrack getInstance] removeSessionCallbackParameter:[key copy]];
    }
}

+ (void)removeSessionPartnerParameter:(NSString *)key {
    @synchronized (self) {
        [[Alltrack getInstance] removeSessionPartnerParameter:[key copy]];
    }
}

+ (void)resetSessionCallbackParameters {
    @synchronized (self) {
        [[Alltrack getInstance] resetSessionCallbackParameters];
    }
}

+ (void)resetSessionPartnerParameters {
    @synchronized (self) {
        [[Alltrack getInstance] resetSessionPartnerParameters];
    }
}

+ (void)gdprForgetMe {
    @synchronized (self) {
        [[Alltrack getInstance] gdprForgetMe];
    }
}

+ (void)trackAdRevenue:(nonnull NSString *)source payload:(nonnull NSData *)payload {
    @synchronized (self) {
        [[Alltrack getInstance] trackAdRevenue:[source copy] payload:[payload copy]];
    }
}

+ (void)disableThirdPartySharing {
    @synchronized (self) {
        [[Alltrack getInstance] disableThirdPartySharing];
    }
}

+ (void)trackThirdPartySharing:(nonnull ALTThirdPartySharing *)thirdPartySharing {
    @synchronized (self) {
        [[Alltrack getInstance] trackThirdPartySharing:thirdPartySharing];
    }
}

+ (void)trackMeasurementConsent:(BOOL)enabled {
    @synchronized (self) {
        [[Alltrack getInstance] trackMeasurementConsent:enabled];
    }
}

+ (void)trackSubscription:(nonnull ALTSubscription *)subscription {
    @synchronized (self) {
        [[Alltrack getInstance] trackSubscription:subscription];
    }
}

+ (void)requestTrackingAuthorizationWithCompletionHandler:(void (^_Nullable)(NSUInteger status))completion {
    @synchronized (self) {
        [[Alltrack getInstance] requestTrackingAuthorizationWithCompletionHandler:completion];
    }
}

+ (int)appTrackingAuthorizationStatus {
    @synchronized (self) {
        return [[Alltrack getInstance] appTrackingAuthorizationStatus];
    }
}

+ (void)updateConversionValue:(NSInteger)conversionValue {
    @synchronized (self) {
        [[Alltrack getInstance] updateConversionValue:conversionValue];
    }
}

+ (void)updatePostbackConversionValue:(NSInteger)conversionValue
                    completionHandler:(void (^_Nullable)(NSError *_Nullable error))completion {
    @synchronized (self) {
        [[Alltrack getInstance] updatePostbackConversionValue:conversionValue
                                          completionHandler:completion];
    }
}

+ (void)updatePostbackConversionValue:(NSInteger)fineValue
                          coarseValue:(nonnull NSString *)coarseValue
                    completionHandler:(void (^_Nullable)(NSError *_Nullable error))completion {
    @synchronized (self) {
        [[Alltrack getInstance] updatePostbackConversionValue:fineValue
                                                coarseValue:coarseValue
                                          completionHandler:completion];
    }
}

+ (void)updatePostbackConversionValue:(NSInteger)fineValue
                          coarseValue:(nonnull NSString *)coarseValue
                           lockWindow:(BOOL)lockWindow
                    completionHandler:(void (^_Nullable)(NSError *_Nullable error))completion {
    @synchronized (self) {
        [[Alltrack getInstance] updatePostbackConversionValue:fineValue
                                                coarseValue:coarseValue
                                                 lockWindow:lockWindow
                                          completionHandler:completion];
    }
}

+ (void)trackAdRevenue:(ALTAdRevenue *)adRevenue {
    @synchronized (self) {
        [[Alltrack getInstance] trackAdRevenue:adRevenue];
    }
}

+ (ALTAttribution *)attribution {
    @synchronized (self) {
        return [[Alltrack getInstance] attribution];
    }
}

+ (NSString *)adid {
    @synchronized (self) {
        return [[Alltrack getInstance] adid];
    }
}

+ (void)checkForNewAttStatus {
    @synchronized (self) {
        [[Alltrack getInstance] checkForNewAttStatus];
    }
}

+ (NSURL *)lastDeeplink {
    @synchronized (self) {
        return [[Alltrack getInstance] lastDeeplink];
    }
}

+ (void)setTestOptions:(AlltrackTestOptions *)testOptions {
    @synchronized (self) {
        if (testOptions.teardown) {
            if (defaultInstance != nil) {
                [defaultInstance teardown];
            }
            defaultInstance = nil;
            onceToken = 0;
            [ALTAlltrackFactory teardown:testOptions.deleteState];
        }
        [[Alltrack getInstance] setTestOptions:(AlltrackTestOptions *)testOptions];
    }
}

#pragma mark - Public instance methods

- (void)appDidLaunch:(ALTConfig *)alltrackConfig {
    if (self.activityHandler != nil) {
        [self.logger error:@"Alltrack already initialized"];
        return;
    }
    self.activityHandler = [[ALTActivityHandler alloc]
                                initWithConfig:alltrackConfig
                                savedPreLaunch:self.savedPreLaunch];
}

- (void)trackEvent:(ALTEvent *)event {
    if (![self checkActivityHandler]) {
        return;
    }
    [self.activityHandler trackEvent:event];
}

- (void)trackSubsessionStart {
    if (![self checkActivityHandler]) {
        return;
    }
    [self.activityHandler applicationDidBecomeActive];
}

- (void)trackSubsessionEnd {
    if (![self checkActivityHandler]) {
        return;
    }
    [self.activityHandler applicationWillResignActive];
}

- (void)setEnabled:(BOOL)enabled {
    self.savedPreLaunch.enabled = [NSNumber numberWithBool:enabled];

    if ([self checkActivityHandler:enabled
                       trueMessage:@"enabled mode"
                      falseMessage:@"disabled mode"]) {
        [self.activityHandler setEnabled:enabled];
    }
}

- (BOOL)isEnabled {
    if (![self checkActivityHandler]) {
        return [self isInstanceEnabled];
    }
    return [self.activityHandler isEnabled];
}

- (void)appWillOpenUrl:(NSURL *)url {
    [ALTUserDefaults cacheDeeplinkUrl:url];
    NSDate *clickTime = [NSDate date];
    if (![self checkActivityHandler]) {
        [ALTUserDefaults saveDeeplinkUrl:url andClickTime:clickTime];
        return;
    }
    [self.activityHandler appWillOpenUrl:url withClickTime:clickTime];
}

- (void)setDeviceToken:(NSData *)deviceToken {
    [ALTUserDefaults savePushTokenData:deviceToken];

    if ([self checkActivityHandler:@"device token"]) {
        if (self.activityHandler.isEnabled) {
            [self.activityHandler setDeviceToken:deviceToken];
        }
    }
}

- (void)setPushToken:(NSString *)pushToken {
    [ALTUserDefaults savePushTokenString:pushToken];

    if ([self checkActivityHandler:@"device token"]) {
        if (self.activityHandler.isEnabled) {
            [self.activityHandler setPushToken:pushToken];
        }
    }
}

- (void)setOfflineMode:(BOOL)enabled {
    if (![self checkActivityHandler:enabled
                        trueMessage:@"offline mode"
                       falseMessage:@"online mode"]) {
        self.savedPreLaunch.offline = enabled;
    } else {
        [self.activityHandler setOfflineMode:enabled];
    }
}

- (NSString *)idfa {
    return [ALTUtil idfa];
}

- (NSURL *)convertUniversalLink:(NSURL *)url scheme:(NSString *)scheme {
    return [ALTUtil convertUniversalLink:url scheme:scheme];
}

- (void)sendFirstPackages {
    if (![self checkActivityHandler]) {
        return;
    }
    [self.activityHandler sendFirstPackages];
}

- (void)addSessionCallbackParameter:(NSString *)key value:(NSString *)value {
    if ([self checkActivityHandler:@"adding session callback parameter"]) {
        [self.activityHandler addSessionCallbackParameter:key value:value];
        return;
    }
    if (self.savedPreLaunch.preLaunchActionsArray == nil) {
        self.savedPreLaunch.preLaunchActionsArray = [[NSMutableArray alloc] init];
    }
    [self.savedPreLaunch.preLaunchActionsArray addObject:^(ALTActivityHandler *activityHandler) {
        [activityHandler addSessionCallbackParameterI:activityHandler key:key value:value];
    }];
}

- (void)addSessionPartnerParameter:(NSString *)key value:(NSString *)value {
    if ([self checkActivityHandler:@"adding session partner parameter"]) {
        [self.activityHandler addSessionPartnerParameter:key value:value];
        return;
    }
    if (self.savedPreLaunch.preLaunchActionsArray == nil) {
        self.savedPreLaunch.preLaunchActionsArray = [[NSMutableArray alloc] init];
    }
    [self.savedPreLaunch.preLaunchActionsArray addObject:^(ALTActivityHandler *activityHandler) {
        [activityHandler addSessionPartnerParameterI:activityHandler key:key value:value];
    }];
}

- (void)removeSessionCallbackParameter:(NSString *)key {
    if ([self checkActivityHandler:@"removing session callback parameter"]) {
        [self.activityHandler removeSessionCallbackParameter:key];
        return;
    }
    if (self.savedPreLaunch.preLaunchActionsArray == nil) {
        self.savedPreLaunch.preLaunchActionsArray = [[NSMutableArray alloc] init];
    }
    [self.savedPreLaunch.preLaunchActionsArray addObject:^(ALTActivityHandler *activityHandler) {
        [activityHandler removeSessionCallbackParameterI:activityHandler key:key];
    }];
}

- (void)removeSessionPartnerParameter:(NSString *)key {
    if ([self checkActivityHandler:@"removing session partner parameter"]) {
        [self.activityHandler removeSessionPartnerParameter:key];
        return;
    }
    if (self.savedPreLaunch.preLaunchActionsArray == nil) {
        self.savedPreLaunch.preLaunchActionsArray = [[NSMutableArray alloc] init];
    }
    [self.savedPreLaunch.preLaunchActionsArray addObject:^(ALTActivityHandler *activityHandler) {
        [activityHandler removeSessionPartnerParameterI:activityHandler key:key];
    }];
}

- (void)resetSessionCallbackParameters {
    if ([self checkActivityHandler:@"resetting session callback parameters"]) {
        [self.activityHandler resetSessionCallbackParameters];
        return;
    }
    if (self.savedPreLaunch.preLaunchActionsArray == nil) {
        self.savedPreLaunch.preLaunchActionsArray = [[NSMutableArray alloc] init];
    }
    [self.savedPreLaunch.preLaunchActionsArray addObject:^(ALTActivityHandler *activityHandler) {
        [activityHandler resetSessionCallbackParametersI:activityHandler];
    }];
}

- (void)resetSessionPartnerParameters {
    if ([self checkActivityHandler:@"resetting session partner parameters"]) {
        [self.activityHandler resetSessionPartnerParameters];
        return;
    }
    if (self.savedPreLaunch.preLaunchActionsArray == nil) {
        self.savedPreLaunch.preLaunchActionsArray = [[NSMutableArray alloc] init];
    }
    [self.savedPreLaunch.preLaunchActionsArray addObject:^(ALTActivityHandler *activityHandler) {
        [activityHandler resetSessionPartnerParametersI:activityHandler];
    }];
}

- (void)gdprForgetMe {
    [ALTUserDefaults setGdprForgetMe];
    if ([self checkActivityHandler:@"GDPR forget me"]) {
        if (self.activityHandler.isEnabled) {
            [self.activityHandler setGdprForgetMe];
        }
    }
}

- (void)trackAdRevenue:(NSString *)source payload:(NSData *)payload {
    if (![self checkActivityHandler]) {
        return;
    }
    [self.activityHandler trackAdRevenue:source payload:payload];
}

- (void)disableThirdPartySharing {
    if (![self checkActivityHandler:@"disable third party sharing"]) {
        [ALTUserDefaults setDisableThirdPartySharing];
        return;
    }
    [self.activityHandler disableThirdPartySharing];
}

- (void)trackThirdPartySharing:(nonnull ALTThirdPartySharing *)thirdPartySharing {
    if (![self checkActivityHandler]) {
        if (self.savedPreLaunch.preLaunchAlltrackThirdPartySharingArray == nil) {
            self.savedPreLaunch.preLaunchAlltrackThirdPartySharingArray =
                [[NSMutableArray alloc] init];
        }
        [self.savedPreLaunch.preLaunchAlltrackThirdPartySharingArray addObject:thirdPartySharing];
        return;
    }
    [self.activityHandler trackThirdPartySharing:thirdPartySharing];
}

- (void)trackMeasurementConsent:(BOOL)enabled {
    if (![self checkActivityHandler]) {
        self.savedPreLaunch.lastMeasurementConsentTracked = [NSNumber numberWithBool:enabled];
        return;
    }
    [self.activityHandler trackMeasurementConsent:enabled];
}

- (void)trackSubscription:(ALTSubscription *)subscription {
    if (![self checkActivityHandler]) {
        return;
    }
    [self.activityHandler trackSubscription:subscription];
}

- (void)requestTrackingAuthorizationWithCompletionHandler:(void (^_Nullable)(NSUInteger status))completion {
    [ALTUtil requestTrackingAuthorizationWithCompletionHandler:^(NSUInteger status) {
        if (completion) {
            completion(status);
        }
        if (![self checkActivityHandler:@"request Tracking Authorization"]) {
            return;
        }
        [self.activityHandler updateAttStatusFromUserCallback:(int)status];
    }];
}

- (int)appTrackingAuthorizationStatus {
    return [ALTUtil attStatus];
}

- (void)updateConversionValue:(NSInteger)conversionValue {
    [[ALTSKAdNetwork getInstance] updateConversionValue:conversionValue];
}

- (void)updatePostbackConversionValue:(NSInteger)conversionValue
                    completionHandler:(void (^_Nullable)(NSError *_Nullable error))completion {
    [[ALTSKAdNetwork getInstance] updatePostbackConversionValue:conversionValue
                                              completionHandler:completion];
}

- (void)updatePostbackConversionValue:(NSInteger)fineValue
                          coarseValue:(nonnull NSString *)coarseValue
                    completionHandler:(void (^_Nullable)(NSError *_Nullable error))completion {
    [[ALTSKAdNetwork getInstance] updatePostbackConversionValue:fineValue
                                                    coarseValue:coarseValue
                                              completionHandler:completion];
}

- (void)updatePostbackConversionValue:(NSInteger)fineValue
                          coarseValue:(nonnull NSString *)coarseValue
                           lockWindow:(BOOL)lockWindow
                    completionHandler:(void (^_Nullable)(NSError *_Nullable error))completion {
    [[ALTSKAdNetwork getInstance] updatePostbackConversionValue:fineValue
                                                    coarseValue:coarseValue
                                                     lockWindow:lockWindow
                                              completionHandler:completion];
}

- (void)trackAdRevenue:(ALTAdRevenue *)adRevenue {
    if (![self checkActivityHandler]) {
        return;
    }
    [self.activityHandler trackAdRevenue:adRevenue];
}

- (ALTAttribution *)attribution {
    if (![self checkActivityHandler]) {
        return nil;
    }
    return [self.activityHandler attribution];
}

- (NSString *)adid {
    if (![self checkActivityHandler]) {
        return nil;
    }
    return [self.activityHandler adid];
}

- (NSString *)sdkVersion {
    return [ALTUtil sdkVersion];
}

- (void)checkForNewAttStatus {
    if (![self checkActivityHandler]) {
        return;
    }
    
    [self.activityHandler checkForNewAttStatus];
}

- (NSURL *)lastDeeplink {
    return [ALTUserDefaults getCachedDeeplinkUrl];
}

- (void)teardown {
    if (self.activityHandler == nil) {
        [self.logger error:@"Alltrack already down or not initialized"];
        return;
    }
    [self.activityHandler teardown];
    self.activityHandler = nil;
}

- (void)setTestOptions:(AlltrackTestOptions *)testOptions {
    if (testOptions.extraPath != nil) {
        self.savedPreLaunch.extraPath = testOptions.extraPath;
    }
    if (testOptions.baseUrl != nil) {
        [ALTAlltrackFactory setBaseUrl:testOptions.baseUrl];
    }
    if (testOptions.gdprUrl != nil) {
        [ALTAlltrackFactory setGdprUrl:testOptions.gdprUrl];
    }
    if (testOptions.subscriptionUrl != nil) {
        [ALTAlltrackFactory setSubscriptionUrl:testOptions.subscriptionUrl];
    }
    if (testOptions.timerIntervalInMilliseconds != nil) {
        NSTimeInterval timerIntervalInSeconds = [testOptions.timerIntervalInMilliseconds intValue] / 1000.0;
        [ALTAlltrackFactory setTimerInterval:timerIntervalInSeconds];
    }
    if (testOptions.timerStartInMilliseconds != nil) {
        NSTimeInterval timerStartInSeconds = [testOptions.timerStartInMilliseconds intValue] / 1000.0;
        [ALTAlltrackFactory setTimerStart:timerStartInSeconds];
    }
    if (testOptions.sessionIntervalInMilliseconds != nil) {
        NSTimeInterval sessionIntervalInSeconds = [testOptions.sessionIntervalInMilliseconds intValue] / 1000.0;
        [ALTAlltrackFactory setSessionInterval:sessionIntervalInSeconds];
    }
    if (testOptions.subsessionIntervalInMilliseconds != nil) {
        NSTimeInterval subsessionIntervalInSeconds = [testOptions.subsessionIntervalInMilliseconds intValue] / 1000.0;
        [ALTAlltrackFactory setSubsessionInterval:subsessionIntervalInSeconds];
    }
    if (testOptions.noBackoffWait) {
        [ALTAlltrackFactory setSdkClickHandlerBackoffStrategy:[ALTBackoffStrategy backoffStrategyWithType:ALTNoWait]];
        [ALTAlltrackFactory setPackageHandlerBackoffStrategy:[ALTBackoffStrategy backoffStrategyWithType:ALTNoWait]];
    }
    if (testOptions.enableSigning) {
        [ALTAlltrackFactory enableSigning];
    }
    if (testOptions.disableSigning) {
        [ALTAlltrackFactory disableSigning];
    }

    [ALTAlltrackFactory setiAdFrameworkEnabled:testOptions.iAdFrameworkEnabled];
    [ALTAlltrackFactory setAdServicesFrameworkEnabled:testOptions.adServicesFrameworkEnabled];
}

#pragma mark - Private & helper methods

- (BOOL)checkActivityHandler {
    return [self checkActivityHandler:nil];
}

- (BOOL)checkActivityHandler:(BOOL)status
                 trueMessage:(NSString *)trueMessage
                falseMessage:(NSString *)falseMessage {
    if (status) {
        return [self checkActivityHandler:trueMessage];
    } else {
        return [self checkActivityHandler:falseMessage];
    }
}

- (BOOL)checkActivityHandler:(NSString *)savedForLaunchWarningSuffixMessage {
    if (self.activityHandler == nil) {
        if (savedForLaunchWarningSuffixMessage != nil) {
            [self.logger warn:@"Alltrack not initialized, but %@ saved for launch", savedForLaunchWarningSuffixMessage];
        } else {
            [self.logger error:@"Please initialize Alltrack by calling 'appDidLaunch' before"];
        }
        return NO;
    } else {
        return YES;
    }
}

- (BOOL)isInstanceEnabled {
    return self.savedPreLaunch.enabled == nil || self.savedPreLaunch.enabled;
}

@end
