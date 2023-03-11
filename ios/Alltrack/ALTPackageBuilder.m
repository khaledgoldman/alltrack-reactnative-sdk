#include <string.h>

#import "ALTUtil.h"
#import "ALTAttribution.h"
#import "ALTAlltrackFactory.h"
#import "ALTPackageBuilder.h"
#import "ALTActivityPackage.h"
#import "NSData+ALTAdditions.h"
#import "ALTUserDefaults.h"

NSString * const ALTAttributionTokenParameter = @"attribution_token";

@interface ALTPackageBuilder()

@property (nonatomic, assign) double createdAt;

@property (nonatomic, weak) ALTConfig *alltrackConfig;

@property (nonatomic, weak) ALTPackageParams *packageParams;

@property (nonatomic, copy) ALTActivityState *activityState;

@property (nonatomic, weak) ALTSessionParameters *sessionParameters;

@property (nonatomic, weak) ALTTrackingStatusManager *trackingStatusManager;

@end

@implementation ALTPackageBuilder

#pragma mark - Object lifecycle methods

- (id)initWithPackageParams:(ALTPackageParams * _Nullable)packageParams
              activityState:(ALTActivityState * _Nullable)activityState
                     config:(ALTConfig * _Nullable)alltrackConfig
          sessionParameters:(ALTSessionParameters * _Nullable)sessionParameters
      trackingStatusManager:(ALTTrackingStatusManager * _Nullable)trackingStatusManager
                  createdAt:(double)createdAt
{
    self = [super init];
    if (self == nil) {
        return nil;
    }

    self.createdAt = createdAt;
    self.packageParams = packageParams;
    self.alltrackConfig = alltrackConfig;
    self.activityState = activityState;
    self.sessionParameters = sessionParameters;
    self.trackingStatusManager = trackingStatusManager;

    return self;
}

#pragma mark - Public methods

- (ALTActivityPackage *)buildSessionPackage:(BOOL)isInDelay {
    NSMutableDictionary *parameters = [self getSessionParameters:isInDelay];
    ALTActivityPackage *sessionPackage = [self defaultActivityPackage];
    sessionPackage.path = @"/session";
    sessionPackage.activityKind = ALTActivityKindSession;
    sessionPackage.suffix = @"";
    sessionPackage.parameters = parameters;

    [self signWithSigV2Plugin:sessionPackage];

    return sessionPackage;
}

- (ALTActivityPackage *)buildEventPackage:(ALTEvent *)event
                                isInDelay:(BOOL)isInDelay {
    NSMutableDictionary *parameters = [self getEventParameters:isInDelay forEventPackage:event];
    ALTActivityPackage *eventPackage = [self defaultActivityPackage];
    eventPackage.path = @"/event";
    eventPackage.activityKind = ALTActivityKindEvent;
    eventPackage.suffix = [self eventSuffix:event];
    eventPackage.parameters = parameters;

    if (isInDelay) {
        eventPackage.callbackParameters = event.callbackParameters;
        eventPackage.partnerParameters = event.partnerParameters;
    }

    [self signWithSigV2Plugin:eventPackage];

    return eventPackage;
}

- (ALTActivityPackage *)buildInfoPackage:(NSString *)infoSource
{
    NSMutableDictionary *parameters = [self getInfoParameters:infoSource];

    ALTActivityPackage *infoPackage = [self defaultActivityPackage];
    infoPackage.path = @"/sdk_info";
    infoPackage.activityKind = ALTActivityKindInfo;
    infoPackage.suffix = @"";
    infoPackage.parameters = parameters;

    [self signWithSigV2Plugin:infoPackage];

    return infoPackage;
}

- (ALTActivityPackage *)buildAdRevenuePackage:(NSString *)source payload:(NSData *)payload {
    NSMutableDictionary *parameters = [self getAdRevenueParameters:source payload:payload];
    ALTActivityPackage *adRevenuePackage = [self defaultActivityPackage];
    adRevenuePackage.path = @"/ad_revenue";
    adRevenuePackage.activityKind = ALTActivityKindAdRevenue;
    adRevenuePackage.suffix = @"";
    adRevenuePackage.parameters = parameters;

    [self signWithSigV2Plugin:adRevenuePackage];

    return adRevenuePackage;
}

- (ALTActivityPackage *)buildAdRevenuePackage:(ALTAdRevenue *)adRevenue isInDelay:(BOOL)isInDelay {
    NSMutableDictionary *parameters = [self getAdRevenueParameters:adRevenue isInDelay:isInDelay];
    ALTActivityPackage *adRevenuePackage = [self defaultActivityPackage];
    adRevenuePackage.path = @"/ad_revenue";
    adRevenuePackage.activityKind = ALTActivityKindAdRevenue;
    adRevenuePackage.suffix = @"";
    adRevenuePackage.parameters = parameters;

    [self signWithSigV2Plugin:adRevenuePackage];

    return adRevenuePackage;
}

- (ALTActivityPackage *)buildClickPackage:(NSString *)clickSource {
    return [self buildClickPackage:clickSource extraParameters:nil];
}

- (ALTActivityPackage *)buildClickPackage:(NSString *)clickSource
                                    token:(NSString *)token
                          errorCodeNumber:(NSNumber *)errorCodeNumber {

    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    
    if (token != nil) {
        [ALTPackageBuilder parameters:parameters
                            setString:token
                               forKey:ALTAttributionTokenParameter];
    }
    if (errorCodeNumber != nil) {
        [ALTPackageBuilder parameters:parameters
                               setInt:errorCodeNumber.intValue
                               forKey:@"error_code"];
    }
    
    return [self buildClickPackage:clickSource extraParameters:parameters];
}

- (ALTActivityPackage *)buildClickPackage:(NSString *)clickSource
                                linkMeUrl:(NSString * _Nullable)linkMeUrl {

    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    
    if (linkMeUrl != nil) {
        [ALTPackageBuilder parameters:parameters
                            setString:linkMeUrl
                               forKey:@"content"];
    }

    return [self buildClickPackage:clickSource extraParameters:parameters];
}

- (ALTActivityPackage *)buildClickPackage:(NSString *)clickSource extraParameters:(NSDictionary *)extraParameters {
    NSMutableDictionary *parameters = [self getClickParameters:clickSource];
    if (extraParameters != nil) {
        [parameters addEntriesFromDictionary:extraParameters];
    }
    
    if ([clickSource isEqualToString:ALTiAdPackageKey]) {
        // send iAd errors in the parameters
        NSDictionary<NSString *, NSNumber *> *iAdErrors = [ALTUserDefaults getiAdErrors];
        if (iAdErrors) {
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:iAdErrors options:0 error:nil];
            NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            parameters[@"iad_errors"] = jsonStr;
        }
    }
    
    ALTActivityPackage *clickPackage = [self defaultActivityPackage];
    clickPackage.path = @"/sdk_click";
    clickPackage.activityKind = ALTActivityKindClick;
    clickPackage.suffix = @"";
    clickPackage.parameters = parameters;

    [self signWithSigV2Plugin:clickPackage];

    return clickPackage;
}

- (ALTActivityPackage *)buildAttributionPackage:(NSString *)initiatedBy {
    NSMutableDictionary *parameters = [self getAttributionParameters:initiatedBy];
    ALTActivityPackage *attributionPackage = [self defaultActivityPackage];
    attributionPackage.path = @"/attribution";
    attributionPackage.activityKind = ALTActivityKindAttribution;
    attributionPackage.suffix = @"";
    attributionPackage.parameters = parameters;

    [self signWithSigV2Plugin:attributionPackage];

    return attributionPackage;
}

- (ALTActivityPackage *)buildGdprPackage {
    NSMutableDictionary *parameters = [self getGdprParameters];
    ALTActivityPackage *gdprPackage = [self defaultActivityPackage];
    gdprPackage.path = @"/gdpr_forget_device";
    gdprPackage.activityKind = ALTActivityKindGdpr;
    gdprPackage.suffix = @"";
    gdprPackage.parameters = parameters;

    [self signWithSigV2Plugin:gdprPackage];

    return gdprPackage;
}

- (ALTActivityPackage *)buildDisableThirdPartySharingPackage {
    NSMutableDictionary *parameters = [self getDisableThirdPartySharingParameters];
    ALTActivityPackage *dtpsPackage = [self defaultActivityPackage];
    dtpsPackage.path = @"/disable_third_party_sharing";
    dtpsPackage.activityKind = ALTActivityKindDisableThirdPartySharing;
    dtpsPackage.suffix = @"";
    dtpsPackage.parameters = parameters;

    [self signWithSigV2Plugin:dtpsPackage];

    return dtpsPackage;
}


- (ALTActivityPackage *)buildThirdPartySharingPackage:(nonnull ALTThirdPartySharing *)thirdPartySharing {
    NSMutableDictionary *parameters = [self getThirdPartySharingParameters:thirdPartySharing];
    ALTActivityPackage *tpsPackage = [self defaultActivityPackage];
    tpsPackage.path = @"/third_party_sharing";
    tpsPackage.activityKind = ALTActivityKindThirdPartySharing;
    tpsPackage.suffix = @"";
    tpsPackage.parameters = parameters;

    [self signWithSigV2Plugin:tpsPackage];

    return tpsPackage;
}

- (ALTActivityPackage *)buildMeasurementConsentPackage:(BOOL)enabled {
    NSMutableDictionary *parameters = [self getMeasurementConsentParameters:enabled];
    ALTActivityPackage *mcPackage = [self defaultActivityPackage];
    mcPackage.path = @"/measurement_consent";
    mcPackage.activityKind = ALTActivityKindMeasurementConsent;
    mcPackage.suffix = @"";
    mcPackage.parameters = parameters;

    [self signWithSigV2Plugin:mcPackage];

    return mcPackage;
}

- (ALTActivityPackage *)buildSubscriptionPackage:(ALTSubscription *)subscription
                                       isInDelay:(BOOL)isInDelay {
    NSMutableDictionary *parameters = [self getSubscriptionParameters:isInDelay forSubscriptionPackage:subscription];
    ALTActivityPackage *subscriptionPackage = [self defaultActivityPackage];
    subscriptionPackage.path = @"/v2/purchase";
    subscriptionPackage.activityKind = ALTActivityKindSubscription;
    subscriptionPackage.suffix = @"";
    subscriptionPackage.parameters = parameters;

    if (isInDelay) {
        subscriptionPackage.callbackParameters = subscription.callbackParameters;
        subscriptionPackage.partnerParameters = subscription.partnerParameters;
    }

    [self signWithSigV2Plugin:subscriptionPackage];

    return subscriptionPackage;
}

+ (void)parameters:(NSMutableDictionary *)parameters setDictionary:(NSDictionary *)dictionary forKey:(NSString *)key {
    if (dictionary == nil) {
        return;
    }
    if (dictionary.count == 0) {
        return;
    }

    NSDictionary *convertedDictionary = [ALTUtil convertDictionaryValues:dictionary];
    [ALTPackageBuilder parameters:parameters setDictionaryJson:convertedDictionary forKey:key];
}

+ (void)parameters:(NSMutableDictionary *)parameters setString:(NSString *)value forKey:(NSString *)key {
    if (value == nil || [value isEqualToString:@""]) {
        return;
    }
    [parameters setObject:value forKey:key];
}

#pragma mark - Private & helper methods

- (void)signWithSigV2Plugin:(ALTActivityPackage *)activityPackage {
    Class signerClass = NSClassFromString(@"ALTSigner");
    if (signerClass == nil) {
        return;
    }
    SEL signSEL = NSSelectorFromString(@"sign:withActivityKind:withSdkVersion:");
    if (![signerClass respondsToSelector:signSEL]) {
        return;
    }

    NSMutableDictionary *parameters = activityPackage.parameters;
    const char *activityKindChar = [[ALTActivityKindUtil activityKindToString:activityPackage.activityKind] UTF8String];
    const char *sdkVersionChar = [activityPackage.clientSdk UTF8String];

    // Stack allocated strings to ensure their lifetime stays until the next iteration
    static char activityKind[64], sdkVersion[64];
    strncpy(activityKind, activityKindChar, strlen(activityKindChar) + 1);
    strncpy(sdkVersion, sdkVersionChar, strlen(sdkVersionChar) + 1);

    // NSInvocation setArgument requires lvalue references with exact matching types to the executed function signature.
    // With this usage we ensure that the lifetime of the object remains until the next iteration, as it points to the
    // stack allocated string where we copied the buffer.
    const char *lvalActivityKind = activityKind;
    const char *lvalSdkVersion = sdkVersion;

    /*
     [ALTSigner sign:parameters
    withActivityKind:activityKindChar
      withSdkVersion:sdkVersionChar];
     */

    NSMethodSignature *signMethodSignature = [signerClass methodSignatureForSelector:signSEL];
    NSInvocation *signInvocation = [NSInvocation invocationWithMethodSignature:signMethodSignature];
    [signInvocation setSelector:signSEL];
    [signInvocation setTarget:signerClass];

    [signInvocation setArgument:&parameters atIndex:2];
    [signInvocation setArgument:&lvalActivityKind atIndex:3];
    [signInvocation setArgument:&lvalSdkVersion atIndex:4];

    [signInvocation invoke];

    SEL getVersionSEL = NSSelectorFromString(@"getVersion");
    if (![signerClass respondsToSelector:getVersionSEL]) {
        return;
    }
    /*
     NSString *signerVersion = [ALTSigner getVersion];
     */
    IMP getVersionIMP = [signerClass methodForSelector:getVersionSEL];
    if (!getVersionIMP) {
        return;
    }
    id (*getVersionFunc)(id, SEL) = (void *)getVersionIMP;
    id signerVersion = getVersionFunc(signerClass, getVersionSEL);
    if (![signerVersion isKindOfClass:[NSString class]]) {
        return;
    }

    NSString *signerVersionString = (NSString *)signerVersion;
    [ALTPackageBuilder parameters:parameters
                           setString:signerVersionString
                           forKey:@"native_version"];
}

- (NSMutableDictionary *)getSessionParameters:(BOOL)isInDelay {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appSecret forKey:@"app_secret"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appToken forKey:@"app_token"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.buildNumber forKey:@"app_version"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.versionNumber forKey:@"app_version_short"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"attribution_deeplink"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.bundleIdentifier forKey:@"bundle_id"];
    [ALTPackageBuilder parameters:parameters setDate1970:self.createdAt forKey:@"created_at"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.defaultTracker forKey:@"default_tracker"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceName forKey:@"device_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceType forKey:@"device_type"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.environment forKey:@"environment"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.externalDeviceId forKey:@"external_device_id"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.fbAnonymousId forKey:@"fb_anon_id"];
    [self addIdfaIfPossibleToParameters:parameters];
    [self addIdfvIfPossibleToParameters:parameters];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.installedAt forKey:@"installed_at"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"needs_response_details"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osName forKey:@"os_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osVersion forKey:@"os_version"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.secretId forKey:@"secret_id"];
    [ALTPackageBuilder parameters:parameters setDate:[ALTUserDefaults getSkadRegisterCallTimestamp] forKey:@"skadn_registered_at"];
    [ALTPackageBuilder parameters:parameters setDate1970:(double)self.packageParams.startedAt forKey:@"started_at"];

    if ([self.trackingStatusManager canGetAttStatus]) {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.attStatus
                               forKey:@"att_status"];
    } else {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.trackingEnabled
                               forKey:@"tracking_enabled"];
    }

    if (self.alltrackConfig.isDeviceKnown) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.isDeviceKnown forKey:@"device_known"];
    }
    if (self.alltrackConfig.needsCost) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.needsCost forKey:@"needs_cost"];
    }

    if (self.activityState != nil) {
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.lastInterval forKey:@"last_interval"];
        [ALTPackageBuilder parameters:parameters setString:self.activityState.deviceToken forKey:@"push_token"];
        [ALTPackageBuilder parameters:parameters setInt:self.activityState.sessionCount forKey:@"session_count"];
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.sessionLength forKey:@"session_length"];
        [ALTPackageBuilder parameters:parameters setInt:self.activityState.subsessionCount forKey:@"subsession_count"];
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.timeSpent forKey:@"time_spent"];
        if (self.activityState.isPersisted) {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"primary_dedupe_token"];
        } else {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"secondary_dedupe_token"];
        }
    }

    if (!isInDelay) {
        [ALTPackageBuilder parameters:parameters setDictionary:[self.sessionParameters.callbackParameters copy] forKey:@"callback_params"];
        [ALTPackageBuilder parameters:parameters setDictionary:[self.sessionParameters.partnerParameters copy] forKey:@"partner_params"];
    }

    [self injectFeatureFlagsWithParameters:parameters];

    return parameters;
}

- (NSMutableDictionary *)getEventParameters:(BOOL)isInDelay forEventPackage:(ALTEvent *)event {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appSecret forKey:@"app_secret"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appToken forKey:@"app_token"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.buildNumber forKey:@"app_version"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.versionNumber forKey:@"app_version_short"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"attribution_deeplink"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.bundleIdentifier forKey:@"bundle_id"];
    [ALTPackageBuilder parameters:parameters setDate1970:self.createdAt forKey:@"created_at"];
    [ALTPackageBuilder parameters:parameters setString:event.currency forKey:@"currency"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceName forKey:@"device_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceType forKey:@"device_type"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.environment forKey:@"environment"];
    [ALTPackageBuilder parameters:parameters setString:event.callbackId forKey:@"event_callback_id"];
    [ALTPackageBuilder parameters:parameters setString:event.eventToken forKey:@"event_token"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.externalDeviceId forKey:@"external_device_id"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.fbAnonymousId forKey:@"fb_anon_id"];
    [self addIdfaIfPossibleToParameters:parameters];
    [self addIdfvIfPossibleToParameters:parameters];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.installedAt forKey:@"installed_at"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"needs_response_details"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osName forKey:@"os_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osVersion forKey:@"os_version"];
    [ALTPackageBuilder parameters:parameters setNumber:event.revenue forKey:@"revenue"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.secretId forKey:@"secret_id"];
    [ALTPackageBuilder parameters:parameters setDate:[ALTUserDefaults getSkadRegisterCallTimestamp] forKey:@"skadn_registered_at"];
    [ALTPackageBuilder parameters:parameters setDate1970:(double)self.packageParams.startedAt forKey:@"started_at"];
    
    if (event.transactionId) {
        [ALTPackageBuilder parameters:parameters setString:event.transactionId forKey:@"deduplication_id"];
    }
    
    if ([self.trackingStatusManager canGetAttStatus]) {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.attStatus
                               forKey:@"att_status"];
    } else {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.trackingEnabled
                               forKey:@"tracking_enabled"];
    }

    if (self.alltrackConfig.isDeviceKnown) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.isDeviceKnown forKey:@"device_known"];
    }
    if (self.alltrackConfig.needsCost) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.needsCost forKey:@"needs_cost"];
    }

    if (self.activityState != nil) {
        [ALTPackageBuilder parameters:parameters setInt:self.activityState.eventCount forKey:@"event_count"];
        [ALTPackageBuilder parameters:parameters setString:self.activityState.deviceToken forKey:@"push_token"];
        [ALTPackageBuilder parameters:parameters setInt:self.activityState.sessionCount forKey:@"session_count"];
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.sessionLength forKey:@"session_length"];
        [ALTPackageBuilder parameters:parameters setInt:self.activityState.subsessionCount forKey:@"subsession_count"];
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.timeSpent forKey:@"time_spent"];
        if (self.activityState.isPersisted) {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"primary_dedupe_token"];
        } else {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"secondary_dedupe_token"];
        }
    }

    if (!isInDelay) {
        NSDictionary *mergedCallbackParameters = [ALTUtil mergeParameters:[self.sessionParameters.callbackParameters copy]
                                                                   source:[event.callbackParameters copy]
                                                            parameterName:@"Callback"];
        NSDictionary *mergedPartnerParameters = [ALTUtil mergeParameters:[self.sessionParameters.partnerParameters copy]
                                                                  source:[event.partnerParameters copy]
                                                           parameterName:@"Partner"];

        [ALTPackageBuilder parameters:parameters setDictionary:mergedCallbackParameters forKey:@"callback_params"];
        [ALTPackageBuilder parameters:parameters setDictionary:mergedPartnerParameters forKey:@"partner_params"];
    }

    if (event.emptyReceipt) {
        NSString *emptyReceipt = @"empty";
        [ALTPackageBuilder parameters:parameters setString:emptyReceipt forKey:@"receipt"];
        [ALTPackageBuilder parameters:parameters setString:event.transactionId forKey:@"transaction_id"];
    } else if (event.receipt != nil) {
        NSString *receiptBase64 = [event.receipt altEncodeBase64];
        [ALTPackageBuilder parameters:parameters setString:receiptBase64 forKey:@"receipt"];
        [ALTPackageBuilder parameters:parameters setString:event.transactionId forKey:@"transaction_id"];
    }

    [self injectFeatureFlagsWithParameters:parameters];

    return parameters;
}

- (NSMutableDictionary *)getInfoParameters:(NSString *)source {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appSecret forKey:@"app_secret"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appToken forKey:@"app_token"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.buildNumber forKey:@"app_version"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.versionNumber forKey:@"app_version_short"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"attribution_deeplink"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.bundleIdentifier forKey:@"bundle_id"];
    [ALTPackageBuilder parameters:parameters setDictionary:[self.sessionParameters.callbackParameters copy] forKey:@"callback_params"];
    [ALTPackageBuilder parameters:parameters setDate:self.clickTime forKey:@"click_time"];
    [ALTPackageBuilder parameters:parameters setDate1970:self.createdAt forKey:@"created_at"];
    [ALTPackageBuilder parameters:parameters setString:self.deeplink forKey:@"deeplink"];
    [ALTPackageBuilder parameters:parameters setString:self.reftag forKey:@"reftag"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.defaultTracker forKey:@"default_tracker"];
    [ALTPackageBuilder parameters:parameters setDictionary:self.attributionDetails forKey:@"details"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceName forKey:@"device_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceType forKey:@"device_type"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.environment forKey:@"environment"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.externalDeviceId forKey:@"external_device_id"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.fbAnonymousId forKey:@"fb_anon_id"];
    [self addIdfaIfPossibleToParameters:parameters];
    [self addIdfvIfPossibleToParameters:parameters];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.installedAt forKey:@"installed_at"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"needs_response_details"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osName forKey:@"os_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osVersion forKey:@"os_version"];
    [ALTPackageBuilder parameters:parameters setDictionary:self.deeplinkParameters forKey:@"params"];
    [ALTPackageBuilder parameters:parameters setDictionary:[self.sessionParameters.partnerParameters copy] forKey:@"partner_params"];
    [ALTPackageBuilder parameters:parameters setDate:self.purchaseTime forKey:@"purchase_time"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.secretId forKey:@"secret_id"];
    [ALTPackageBuilder parameters:parameters setDate:[ALTUserDefaults getSkadRegisterCallTimestamp] forKey:@"skadn_registered_at"];
    [ALTPackageBuilder parameters:parameters setDate1970:(double)self.packageParams.startedAt forKey:@"started_at"];
    [ALTPackageBuilder parameters:parameters setString:source forKey:@"source"];
    
    if ([self.trackingStatusManager canGetAttStatus]) {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.attStatus
                               forKey:@"att_status"];
    } else {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.trackingEnabled
                               forKey:@"tracking_enabled"];
    }

    if (self.alltrackConfig.isDeviceKnown) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.isDeviceKnown forKey:@"device_known"];
    }
    if (self.alltrackConfig.needsCost) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.needsCost forKey:@"needs_cost"];
    }

    if (self.activityState != nil) {
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.lastInterval forKey:@"last_interval"];
        [ALTPackageBuilder parameters:parameters setString:self.activityState.deviceToken forKey:@"push_token"];
        [ALTPackageBuilder parameters:parameters setInt:self.activityState.sessionCount forKey:@"session_count"];
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.sessionLength forKey:@"session_length"];
        [ALTPackageBuilder parameters:parameters setInt:self.activityState.subsessionCount forKey:@"subsession_count"];
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.timeSpent forKey:@"time_spent"];
        if (self.activityState.isPersisted) {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"primary_dedupe_token"];
        } else {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"secondary_dedupe_token"];
        }
    }

    if (self.attribution != nil) {
        [ALTPackageBuilder parameters:parameters setString:self.attribution.adgroup forKey:@"adgroup"];
        [ALTPackageBuilder parameters:parameters setString:self.attribution.campaign forKey:@"campaign"];
        [ALTPackageBuilder parameters:parameters setString:self.attribution.creative forKey:@"creative"];
        [ALTPackageBuilder parameters:parameters setString:self.attribution.trackerName forKey:@"tracker"];
    }

    [self injectFeatureFlagsWithParameters:parameters];

    return parameters;
}

- (NSMutableDictionary *)getAdRevenueParameters:(NSString *)source payload:(NSData *)payload {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appSecret forKey:@"app_secret"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appToken forKey:@"app_token"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.buildNumber forKey:@"app_version"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.versionNumber forKey:@"app_version_short"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"attribution_deeplink"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.bundleIdentifier forKey:@"bundle_id"];
    [ALTPackageBuilder parameters:parameters setDate1970:self.createdAt forKey:@"created_at"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.defaultTracker forKey:@"default_tracker"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceName forKey:@"device_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceType forKey:@"device_type"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.environment forKey:@"environment"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.externalDeviceId forKey:@"external_device_id"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.fbAnonymousId forKey:@"fb_anon_id"];
    [self addIdfaIfPossibleToParameters:parameters];
    [self addIdfvIfPossibleToParameters:parameters];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.installedAt forKey:@"installed_at"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"needs_response_details"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osName forKey:@"os_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osVersion forKey:@"os_version"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.secretId forKey:@"secret_id"];
    [ALTPackageBuilder parameters:parameters setDate:[ALTUserDefaults getSkadRegisterCallTimestamp] forKey:@"skadn_registered_at"];
    [ALTPackageBuilder parameters:parameters setDate1970:(double)self.packageParams.startedAt forKey:@"started_at"];
    [ALTPackageBuilder parameters:parameters setString:source forKey:@"source"];
    [ALTPackageBuilder parameters:parameters setData:payload forKey:@"payload"];
    
    if ([self.trackingStatusManager canGetAttStatus]) {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.attStatus
                               forKey:@"att_status"];
    } else {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.trackingEnabled
                               forKey:@"tracking_enabled"];
    }

    if (self.alltrackConfig.isDeviceKnown) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.isDeviceKnown forKey:@"device_known"];
    }
    if (self.alltrackConfig.needsCost) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.needsCost forKey:@"needs_cost"];
    }

    if (self.activityState != nil) {
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.lastInterval forKey:@"last_interval"];
        [ALTPackageBuilder parameters:parameters setString:self.activityState.deviceToken forKey:@"push_token"];
        [ALTPackageBuilder parameters:parameters setInt:self.activityState.sessionCount forKey:@"session_count"];
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.sessionLength forKey:@"session_length"];
        [ALTPackageBuilder parameters:parameters setInt:self.activityState.subsessionCount forKey:@"subsession_count"];
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.timeSpent forKey:@"time_spent"];
        if (self.activityState.isPersisted) {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"primary_dedupe_token"];
        } else {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"secondary_dedupe_token"];
        }
    }

    [self injectFeatureFlagsWithParameters:parameters];

    return parameters;
}

- (NSMutableDictionary *)getAdRevenueParameters:(ALTAdRevenue *)adRevenue isInDelay:(BOOL)isInDelay {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appSecret forKey:@"app_secret"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appToken forKey:@"app_token"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.buildNumber forKey:@"app_version"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.versionNumber forKey:@"app_version_short"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"attribution_deeplink"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.bundleIdentifier forKey:@"bundle_id"];
    [ALTPackageBuilder parameters:parameters setDate1970:self.createdAt forKey:@"created_at"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.defaultTracker forKey:@"default_tracker"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceName forKey:@"device_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceType forKey:@"device_type"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.environment forKey:@"environment"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.externalDeviceId forKey:@"external_device_id"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.fbAnonymousId forKey:@"fb_anon_id"];
    [self addIdfaIfPossibleToParameters:parameters];
    [self addIdfvIfPossibleToParameters:parameters];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.installedAt forKey:@"installed_at"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"needs_response_details"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osName forKey:@"os_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osVersion forKey:@"os_version"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.secretId forKey:@"secret_id"];
    [ALTPackageBuilder parameters:parameters setDate:[ALTUserDefaults getSkadRegisterCallTimestamp] forKey:@"skadn_registered_at"];
    [ALTPackageBuilder parameters:parameters setDate1970:(double)self.packageParams.startedAt forKey:@"started_at"];
    
    [ALTPackageBuilder parameters:parameters setString:adRevenue.source forKey:@"source"];
    [ALTPackageBuilder parameters:parameters setNumberWithoutRounding:adRevenue.revenue forKey:@"revenue"];
    [ALTPackageBuilder parameters:parameters setString:adRevenue.currency forKey:@"currency"];
    [ALTPackageBuilder parameters:parameters setNumberInt:adRevenue.adImpressionsCount forKey:@"ad_impressions_count"];
    [ALTPackageBuilder parameters:parameters setString:adRevenue.adRevenueNetwork forKey:@"ad_revenue_network"];
    [ALTPackageBuilder parameters:parameters setString:adRevenue.adRevenueUnit forKey:@"ad_revenue_unit"];
    [ALTPackageBuilder parameters:parameters setString:adRevenue.adRevenuePlacement forKey:@"ad_revenue_placement"];
    
    if ([self.trackingStatusManager canGetAttStatus]) {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.attStatus
                               forKey:@"att_status"];
    } else {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.trackingEnabled
                               forKey:@"tracking_enabled"];
    }

    if (self.alltrackConfig.isDeviceKnown) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.isDeviceKnown forKey:@"device_known"];
    }
    if (self.alltrackConfig.needsCost) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.needsCost forKey:@"needs_cost"];
    }
    
    if (!isInDelay) {
        NSDictionary *mergedCallbackParameters = [ALTUtil mergeParameters:[self.sessionParameters.callbackParameters copy]
                                                                   source:[adRevenue.callbackParameters copy]
                                                            parameterName:@"Callback"];
        NSDictionary *mergedPartnerParameters = [ALTUtil mergeParameters:[self.sessionParameters.partnerParameters copy]
                                                                  source:[adRevenue.partnerParameters copy]
                                                           parameterName:@"Partner"];

        [ALTPackageBuilder parameters:parameters setDictionary:mergedCallbackParameters forKey:@"callback_params"];
        [ALTPackageBuilder parameters:parameters setDictionary:mergedPartnerParameters forKey:@"partner_params"];
    }

    if (self.activityState != nil) {
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.lastInterval forKey:@"last_interval"];
        [ALTPackageBuilder parameters:parameters setString:self.activityState.deviceToken forKey:@"push_token"];
        [ALTPackageBuilder parameters:parameters setInt:self.activityState.sessionCount forKey:@"session_count"];
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.sessionLength forKey:@"session_length"];
        [ALTPackageBuilder parameters:parameters setInt:self.activityState.subsessionCount forKey:@"subsession_count"];
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.timeSpent forKey:@"time_spent"];
        if (self.activityState.isPersisted) {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"primary_dedupe_token"];
        } else {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"secondary_dedupe_token"];
        }
    }

    [self injectFeatureFlagsWithParameters:parameters];

    return parameters;
}

- (NSMutableDictionary *)getClickParameters:(NSString *)source {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appSecret forKey:@"app_secret"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appToken forKey:@"app_token"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.buildNumber forKey:@"app_version"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.versionNumber forKey:@"app_version_short"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"attribution_deeplink"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.bundleIdentifier forKey:@"bundle_id"];
    [ALTPackageBuilder parameters:parameters setDictionary:[self.sessionParameters.callbackParameters copy] forKey:@"callback_params"];
    [ALTPackageBuilder parameters:parameters setDate:self.clickTime forKey:@"click_time"];
    [ALTPackageBuilder parameters:parameters setDate1970:self.createdAt forKey:@"created_at"];
    [ALTPackageBuilder parameters:parameters setString:self.deeplink forKey:@"deeplink"];
    [ALTPackageBuilder parameters:parameters setString:self.reftag forKey:@"reftag"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.defaultTracker forKey:@"default_tracker"];
    [ALTPackageBuilder parameters:parameters setDictionary:self.attributionDetails forKey:@"details"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceName forKey:@"device_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceType forKey:@"device_type"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.environment forKey:@"environment"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.externalDeviceId forKey:@"external_device_id"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.fbAnonymousId forKey:@"fb_anon_id"];
    [self addIdfaIfPossibleToParameters:parameters];
    [self addIdfvIfPossibleToParameters:parameters];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.installedAt forKey:@"installed_at"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"needs_response_details"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osName forKey:@"os_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osVersion forKey:@"os_version"];
    [ALTPackageBuilder parameters:parameters setDictionary:self.deeplinkParameters forKey:@"params"];
    [ALTPackageBuilder parameters:parameters setDictionary:[self.sessionParameters.partnerParameters copy] forKey:@"partner_params"];
    [ALTPackageBuilder parameters:parameters setDate:self.purchaseTime forKey:@"purchase_time"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.secretId forKey:@"secret_id"];
    [ALTPackageBuilder parameters:parameters setDate:[ALTUserDefaults getSkadRegisterCallTimestamp] forKey:@"skadn_registered_at"];
    [ALTPackageBuilder parameters:parameters setDate1970:(double)self.packageParams.startedAt forKey:@"started_at"];
    [ALTPackageBuilder parameters:parameters setString:source forKey:@"source"];
    
    if ([self.trackingStatusManager canGetAttStatus]) {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.attStatus
                               forKey:@"att_status"];
    } else {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.trackingEnabled
                               forKey:@"tracking_enabled"];
    }

    if (self.alltrackConfig.isDeviceKnown) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.isDeviceKnown forKey:@"device_known"];
    }
    if (self.alltrackConfig.needsCost) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.needsCost forKey:@"needs_cost"];
    }

    if (self.activityState != nil) {
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.lastInterval forKey:@"last_interval"];
        [ALTPackageBuilder parameters:parameters setString:self.activityState.deviceToken forKey:@"push_token"];
        [ALTPackageBuilder parameters:parameters setInt:self.activityState.sessionCount forKey:@"session_count"];
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.sessionLength forKey:@"session_length"];
        [ALTPackageBuilder parameters:parameters setInt:self.activityState.subsessionCount forKey:@"subsession_count"];
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.timeSpent forKey:@"time_spent"];
        if (self.activityState.isPersisted) {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"primary_dedupe_token"];
        } else {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"secondary_dedupe_token"];
        }
    }

    if (self.attribution != nil) {
        [ALTPackageBuilder parameters:parameters setString:self.attribution.adgroup forKey:@"adgroup"];
        [ALTPackageBuilder parameters:parameters setString:self.attribution.campaign forKey:@"campaign"];
        [ALTPackageBuilder parameters:parameters setString:self.attribution.creative forKey:@"creative"];
        [ALTPackageBuilder parameters:parameters setString:self.attribution.trackerName forKey:@"tracker"];
    }

    [self injectFeatureFlagsWithParameters:parameters];

    return parameters;
}

- (NSMutableDictionary *)getAttributionParameters:(NSString *)initiatedBy {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appToken forKey:@"app_token"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appSecret forKey:@"app_secret"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.buildNumber forKey:@"app_version"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.versionNumber forKey:@"app_version_short"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"attribution_deeplink"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.bundleIdentifier forKey:@"bundle_id"];
    [ALTPackageBuilder parameters:parameters setDate1970:self.createdAt forKey:@"created_at"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceName forKey:@"device_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceType forKey:@"device_type"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.environment forKey:@"environment"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.externalDeviceId forKey:@"external_device_id"];
    [self addIdfaIfPossibleToParameters:parameters];
    [self addIdfvIfPossibleToParameters:parameters];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.installedAt forKey:@"installed_at"];
    [ALTPackageBuilder parameters:parameters setString:initiatedBy forKey:@"initiated_by"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"needs_response_details"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osName forKey:@"os_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osVersion forKey:@"os_version"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.secretId forKey:@"secret_id"];
    [ALTPackageBuilder parameters:parameters setDate:[ALTUserDefaults getSkadRegisterCallTimestamp] forKey:@"skadn_registered_at"];
    [ALTPackageBuilder parameters:parameters setDate1970:(double)self.packageParams.startedAt forKey:@"started_at"];

    if (self.alltrackConfig.isDeviceKnown) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.isDeviceKnown forKey:@"device_known"];
    }
    if (self.alltrackConfig.needsCost) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.needsCost forKey:@"needs_cost"];
    }
    
    if ([self.trackingStatusManager canGetAttStatus]) {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.attStatus
                               forKey:@"att_status"];
    } else {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.trackingEnabled
                               forKey:@"tracking_enabled"];
    }

    if (self.activityState != nil) {
        if (self.activityState.isPersisted) {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"primary_dedupe_token"];
        } else {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"secondary_dedupe_token"];
        }
    }

    [self injectFeatureFlagsWithParameters:parameters];

    return parameters;
}

- (NSMutableDictionary *)getGdprParameters {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appToken forKey:@"app_token"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appSecret forKey:@"app_secret"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.buildNumber forKey:@"app_version"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.versionNumber forKey:@"app_version_short"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"attribution_deeplink"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.bundleIdentifier forKey:@"bundle_id"];
    [ALTPackageBuilder parameters:parameters setDate1970:self.createdAt forKey:@"created_at"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceName forKey:@"device_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceType forKey:@"device_type"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.environment forKey:@"environment"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.externalDeviceId forKey:@"external_device_id"];
    [self addIdfaIfPossibleToParameters:parameters];
    [self addIdfvIfPossibleToParameters:parameters];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.installedAt forKey:@"installed_at"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"needs_response_details"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osName forKey:@"os_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osVersion forKey:@"os_version"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.secretId forKey:@"secret_id"];
    [ALTPackageBuilder parameters:parameters setDate:[ALTUserDefaults getSkadRegisterCallTimestamp] forKey:@"skadn_registered_at"];
    [ALTPackageBuilder parameters:parameters setDate1970:(double)self.packageParams.startedAt forKey:@"started_at"];

    if (self.alltrackConfig.isDeviceKnown) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.isDeviceKnown forKey:@"device_known"];
    }
    if (self.alltrackConfig.needsCost) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.needsCost forKey:@"needs_cost"];
    }
    
    if ([self.trackingStatusManager canGetAttStatus]) {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.attStatus
                               forKey:@"att_status"];
    } else {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.trackingEnabled
                               forKey:@"tracking_enabled"];
    }

    if (self.activityState != nil) {
        if (self.activityState.isPersisted) {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"primary_dedupe_token"];
        } else {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"secondary_dedupe_token"];
        }
    }

    [self injectFeatureFlagsWithParameters:parameters];

    return parameters;
}

- (NSMutableDictionary *)getDisableThirdPartySharingParameters {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appSecret forKey:@"app_secret"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appToken forKey:@"app_token"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.buildNumber forKey:@"app_version"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.versionNumber forKey:@"app_version_short"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"attribution_deeplink"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.bundleIdentifier forKey:@"bundle_id"];
    [ALTPackageBuilder parameters:parameters setDictionary:[self.sessionParameters.callbackParameters copy] forKey:@"callback_params"];
    [ALTPackageBuilder parameters:parameters setDate:self.clickTime forKey:@"click_time"];
    [ALTPackageBuilder parameters:parameters setDate1970:self.createdAt forKey:@"created_at"];
    [ALTPackageBuilder parameters:parameters setString:self.deeplink forKey:@"deeplink"];
    [ALTPackageBuilder parameters:parameters setString:self.reftag forKey:@"reftag"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.defaultTracker forKey:@"default_tracker"];
    [ALTPackageBuilder parameters:parameters setDictionary:self.attributionDetails forKey:@"details"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceName forKey:@"device_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceType forKey:@"device_type"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.environment forKey:@"environment"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.externalDeviceId forKey:@"external_device_id"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.fbAnonymousId forKey:@"fb_anon_id"];
    [self addIdfaIfPossibleToParameters:parameters];
    [self addIdfvIfPossibleToParameters:parameters];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.installedAt forKey:@"installed_at"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"needs_response_details"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osName forKey:@"os_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osVersion forKey:@"os_version"];
    [ALTPackageBuilder parameters:parameters setDictionary:self.deeplinkParameters forKey:@"params"];
    [ALTPackageBuilder parameters:parameters setDictionary:[self.sessionParameters.partnerParameters copy] forKey:@"partner_params"];
    [ALTPackageBuilder parameters:parameters setDate:self.purchaseTime forKey:@"purchase_time"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.secretId forKey:@"secret_id"];
    [ALTPackageBuilder parameters:parameters setDate:[ALTUserDefaults getSkadRegisterCallTimestamp] forKey:@"skadn_registered_at"];
    [ALTPackageBuilder parameters:parameters setDate1970:(double)self.packageParams.startedAt forKey:@"started_at"];
    
    if ([self.trackingStatusManager canGetAttStatus]) {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.attStatus
                               forKey:@"att_status"];
    } else {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.trackingEnabled
                               forKey:@"tracking_enabled"];
    }

    if (self.alltrackConfig.isDeviceKnown) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.isDeviceKnown forKey:@"device_known"];
    }
    if (self.alltrackConfig.needsCost) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.needsCost forKey:@"needs_cost"];
    }
    
    if (self.activityState != nil) {
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.lastInterval forKey:@"last_interval"];
        [ALTPackageBuilder parameters:parameters setString:self.activityState.deviceToken forKey:@"push_token"];
        [ALTPackageBuilder parameters:parameters setInt:self.activityState.sessionCount forKey:@"session_count"];
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.sessionLength forKey:@"session_length"];
        [ALTPackageBuilder parameters:parameters setInt:self.activityState.subsessionCount forKey:@"subsession_count"];
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.timeSpent forKey:@"time_spent"];
        if (self.activityState.isPersisted) {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"primary_dedupe_token"];
        } else {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"secondary_dedupe_token"];
        }
    }

    [self injectFeatureFlagsWithParameters:parameters];

    return parameters;
}

- (NSMutableDictionary *)getThirdPartySharingParameters:(nonnull ALTThirdPartySharing *)thirdPartySharing {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appSecret forKey:@"app_secret"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appToken forKey:@"app_token"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.buildNumber forKey:@"app_version"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.versionNumber forKey:@"app_version_short"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"attribution_deeplink"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.bundleIdentifier forKey:@"bundle_id"];
    [ALTPackageBuilder parameters:parameters setDictionary:[self.sessionParameters.callbackParameters copy] forKey:@"callback_params"];
    [ALTPackageBuilder parameters:parameters setDate:self.clickTime forKey:@"click_time"];
    [ALTPackageBuilder parameters:parameters setDate1970:self.createdAt forKey:@"created_at"];
    [ALTPackageBuilder parameters:parameters setString:self.deeplink forKey:@"deeplink"];
    [ALTPackageBuilder parameters:parameters setString:self.reftag forKey:@"reftag"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.defaultTracker forKey:@"default_tracker"];
    [ALTPackageBuilder parameters:parameters setDictionary:self.attributionDetails forKey:@"details"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceName forKey:@"device_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceType forKey:@"device_type"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.environment forKey:@"environment"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.externalDeviceId forKey:@"external_device_id"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.fbAnonymousId forKey:@"fb_anon_id"];
    [self addIdfaIfPossibleToParameters:parameters];
    [self addIdfvIfPossibleToParameters:parameters];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.installedAt forKey:@"installed_at"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"needs_response_details"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osName forKey:@"os_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osVersion forKey:@"os_version"];
    [ALTPackageBuilder parameters:parameters setDictionary:self.deeplinkParameters forKey:@"params"];
    [ALTPackageBuilder parameters:parameters setDictionary:[self.sessionParameters.partnerParameters copy] forKey:@"partner_params"];
    [ALTPackageBuilder parameters:parameters setDate:self.purchaseTime forKey:@"purchase_time"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.secretId forKey:@"secret_id"];
    [ALTPackageBuilder parameters:parameters setDate:[ALTUserDefaults getSkadRegisterCallTimestamp] forKey:@"skadn_registered_at"];
    [ALTPackageBuilder parameters:parameters setDate1970:(double)self.packageParams.startedAt forKey:@"started_at"];

    // Third Party Sharing
    if (thirdPartySharing.enabled != nil) {
        NSString *enableValue = thirdPartySharing.enabled.boolValue ? @"enable" : @"disable";
        [ALTPackageBuilder parameters:parameters setString:enableValue forKey:@"sharing"];
    }
    [ALTPackageBuilder parameters:parameters
                setDictionaryJson:thirdPartySharing.granularOptions
                           forKey:@"granular_third_party_sharing_options"];
    [ALTPackageBuilder parameters:parameters
                setDictionaryJson:thirdPartySharing.partnerSharingSettings
                           forKey:@"partner_sharing_settings"];

    if ([self.trackingStatusManager canGetAttStatus]) {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.attStatus
                               forKey:@"att_status"];
    } else {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.trackingEnabled
                               forKey:@"tracking_enabled"];
    }

    if (self.alltrackConfig.isDeviceKnown) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.isDeviceKnown forKey:@"device_known"];
    }

    if (self.activityState != nil) {
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.lastInterval forKey:@"last_interval"];
        [ALTPackageBuilder parameters:parameters setString:self.activityState.deviceToken forKey:@"push_token"];
        [ALTPackageBuilder parameters:parameters setInt:self.activityState.sessionCount forKey:@"session_count"];
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.sessionLength forKey:@"session_length"];
        [ALTPackageBuilder parameters:parameters setInt:self.activityState.subsessionCount forKey:@"subsession_count"];
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.timeSpent forKey:@"time_spent"];
        if (self.activityState.isPersisted) {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"primary_dedupe_token"];
        } else {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"secondary_dedupe_token"];
        }
    }

    [self injectFeatureFlagsWithParameters:parameters];

    return parameters;
}

- (NSMutableDictionary *)getMeasurementConsentParameters:(BOOL)enabled {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appSecret forKey:@"app_secret"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appToken forKey:@"app_token"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.buildNumber forKey:@"app_version"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.versionNumber forKey:@"app_version_short"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"attribution_deeplink"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.bundleIdentifier forKey:@"bundle_id"];
    [ALTPackageBuilder parameters:parameters setDictionary:[self.sessionParameters.callbackParameters copy] forKey:@"callback_params"];
    [ALTPackageBuilder parameters:parameters setDate:self.clickTime forKey:@"click_time"];
    [ALTPackageBuilder parameters:parameters setDate1970:self.createdAt forKey:@"created_at"];
    [ALTPackageBuilder parameters:parameters setString:self.deeplink forKey:@"deeplink"];
    [ALTPackageBuilder parameters:parameters setString:self.reftag forKey:@"reftag"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.defaultTracker forKey:@"default_tracker"];
    [ALTPackageBuilder parameters:parameters setDictionary:self.attributionDetails forKey:@"details"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceName forKey:@"device_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceType forKey:@"device_type"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.environment forKey:@"environment"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.externalDeviceId forKey:@"external_device_id"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.fbAnonymousId forKey:@"fb_anon_id"];
    [self addIdfaIfPossibleToParameters:parameters];
    [self addIdfvIfPossibleToParameters:parameters];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.installedAt forKey:@"installed_at"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"needs_response_details"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osName forKey:@"os_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osVersion forKey:@"os_version"];
    [ALTPackageBuilder parameters:parameters setDictionary:self.deeplinkParameters forKey:@"params"];
    [ALTPackageBuilder parameters:parameters setDictionary:[self.sessionParameters.partnerParameters copy] forKey:@"partner_params"];
    [ALTPackageBuilder parameters:parameters setDate:self.purchaseTime forKey:@"purchase_time"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.secretId forKey:@"secret_id"];
    [ALTPackageBuilder parameters:parameters setDate:[ALTUserDefaults getSkadRegisterCallTimestamp] forKey:@"skadn_registered_at"];
    [ALTPackageBuilder parameters:parameters setDate1970:(double)self.packageParams.startedAt forKey:@"started_at"];

    // Measurement Consent
    NSString *enableValue = enabled ? @"enable" : @"disable";
    [ALTPackageBuilder parameters:parameters
                        setString:enableValue
                           forKey:@"measurement"];

    if ([self.trackingStatusManager canGetAttStatus]) {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.attStatus
                               forKey:@"att_status"];
    } else {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.trackingEnabled
                               forKey:@"tracking_enabled"];
    }

    if (self.alltrackConfig.isDeviceKnown) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.isDeviceKnown forKey:@"device_known"];
    }

    if (self.activityState != nil) {
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.lastInterval forKey:@"last_interval"];
        [ALTPackageBuilder parameters:parameters setString:self.activityState.deviceToken forKey:@"push_token"];
        [ALTPackageBuilder parameters:parameters setInt:self.activityState.sessionCount forKey:@"session_count"];
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.sessionLength forKey:@"session_length"];
        [ALTPackageBuilder parameters:parameters setInt:self.activityState.subsessionCount forKey:@"subsession_count"];
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.timeSpent forKey:@"time_spent"];
        if (self.activityState.isPersisted) {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"primary_dedupe_token"];
        } else {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"secondary_dedupe_token"];
        }
    }

    [self injectFeatureFlagsWithParameters:parameters];

    return parameters;
}
- (NSMutableDictionary *)getSubscriptionParameters:(BOOL)isInDelay forSubscriptionPackage:(ALTSubscription *)subscription {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appSecret forKey:@"app_secret"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.appToken forKey:@"app_token"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.buildNumber forKey:@"app_version"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.versionNumber forKey:@"app_version_short"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"attribution_deeplink"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.bundleIdentifier forKey:@"bundle_id"];
    [ALTPackageBuilder parameters:parameters setDate1970:self.createdAt forKey:@"created_at"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceName forKey:@"device_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.deviceType forKey:@"device_type"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.environment forKey:@"environment"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.externalDeviceId forKey:@"external_device_id"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.fbAnonymousId forKey:@"fb_anon_id"];
    [self addIdfaIfPossibleToParameters:parameters];
    [self addIdfvIfPossibleToParameters:parameters];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.installedAt forKey:@"installed_at"];
    [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"needs_response_details"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osName forKey:@"os_name"];
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.osVersion forKey:@"os_version"];
    [ALTPackageBuilder parameters:parameters setString:self.alltrackConfig.secretId forKey:@"secret_id"];
    [ALTPackageBuilder parameters:parameters setDate:[ALTUserDefaults getSkadRegisterCallTimestamp] forKey:@"skadn_registered_at"];
    [ALTPackageBuilder parameters:parameters setDate1970:(double)self.packageParams.startedAt forKey:@"started_at"];
    
    if ([self.trackingStatusManager canGetAttStatus]) {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.attStatus
                               forKey:@"att_status"];
    } else {
        [ALTPackageBuilder parameters:parameters setInt:self.trackingStatusManager.trackingEnabled
                               forKey:@"tracking_enabled"];
    }

    if (self.alltrackConfig.isDeviceKnown) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.isDeviceKnown forKey:@"device_known"];
    }
    if (self.alltrackConfig.needsCost) {
        [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.needsCost forKey:@"needs_cost"];
    }

    if (self.activityState != nil) {
        [ALTPackageBuilder parameters:parameters setString:self.activityState.deviceToken forKey:@"push_token"];
        [ALTPackageBuilder parameters:parameters setInt:self.activityState.sessionCount forKey:@"session_count"];
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.sessionLength forKey:@"session_length"];
        [ALTPackageBuilder parameters:parameters setInt:self.activityState.subsessionCount forKey:@"subsession_count"];
        [ALTPackageBuilder parameters:parameters setDuration:self.activityState.timeSpent forKey:@"time_spent"];
        if (self.activityState.isPersisted) {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"primary_dedupe_token"];
        } else {
            [ALTPackageBuilder parameters:parameters setString:self.activityState.dedupeToken forKey:@"secondary_dedupe_token"];
        }
    }

    if (!isInDelay) {
        NSDictionary *mergedCallbackParameters = [ALTUtil mergeParameters:self.sessionParameters.callbackParameters
                                                                   source:subscription.callbackParameters
                                                            parameterName:@"Callback"];
        NSDictionary *mergedPartnerParameters = [ALTUtil mergeParameters:self.sessionParameters.partnerParameters
                                                                  source:subscription.partnerParameters
                                                           parameterName:@"Partner"];

        [ALTPackageBuilder parameters:parameters setDictionary:mergedCallbackParameters forKey:@"callback_params"];
        [ALTPackageBuilder parameters:parameters setDictionary:mergedPartnerParameters forKey:@"partner_params"];
    }
    
    [ALTPackageBuilder parameters:parameters setNumber:subscription.price forKey:@"revenue"];
    [ALTPackageBuilder parameters:parameters setString:subscription.currency forKey:@"currency"];
    [ALTPackageBuilder parameters:parameters setString:subscription.transactionId forKey:@"transaction_id"];
    [ALTPackageBuilder parameters:parameters setString:[subscription.receipt altEncodeBase64] forKey:@"receipt"];
    [ALTPackageBuilder parameters:parameters setString:subscription.billingStore forKey:@"billing_store"];
    [ALTPackageBuilder parameters:parameters setDate:subscription.transactionDate forKey:@"transaction_date"];
    [ALTPackageBuilder parameters:parameters setString:subscription.salesRegion forKey:@"sales_region"];

    [self injectFeatureFlagsWithParameters:parameters];

    return parameters;
}

- (void)addIdfaIfPossibleToParameters:(NSMutableDictionary *)parameters {
    id<ALTLogger> logger = [ALTAlltrackFactory logger];

    if (! self.alltrackConfig.allowIdfaReading) {
        return;
    }
    
    if (self.alltrackConfig.coppaCompliantEnabled) {
        [logger info:@"Cannot read IDFA with COPPA enabled"];
        return;
    }
    
    NSString *idfa = [ALTUtil idfa];

    if (idfa == nil
        || idfa.length == 0
        || [idfa isEqualToString:@"00000000-0000-0000-0000-000000000000"])
    {
        return;
    }

    [ALTPackageBuilder parameters:parameters setString:idfa forKey:@"idfa"];
}

- (void)addIdfvIfPossibleToParameters:(NSMutableDictionary *)parameters {
    id<ALTLogger> logger = [ALTAlltrackFactory logger];
    
    if (self.alltrackConfig.coppaCompliantEnabled) {
        [logger info:@"Cannot read IDFV with COPPA enabled"];
        return;
    }
    [ALTPackageBuilder parameters:parameters setString:self.packageParams.idfv forKey:@"idfv"];
}

- (void)injectFeatureFlagsWithParameters:(NSMutableDictionary *)parameters {
    [ALTPackageBuilder parameters:parameters setBool:self.alltrackConfig.eventBufferingEnabled
                           forKey:@"event_buffering_enabled"];
    if (self.alltrackConfig.coppaCompliantEnabled == YES) {
        [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"ff_coppa"];
    }
    if (self.alltrackConfig.isSKAdNetworkHandlingActive == NO) {
        [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"ff_skadn_disabled"];
    }
    if (self.alltrackConfig.allowIdfaReading == NO) {
        [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"ff_idfa_disabled"];
    }
    if (self.alltrackConfig.allowiAdInfoReading == NO) {
        [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"ff_iad_disabled"];
    }
    if (self.alltrackConfig.allowAdServicesInfoReading == NO) {
        [ALTPackageBuilder parameters:parameters setBool:YES forKey:@"ff_adserv_disabled"];
    }
}

- (ALTActivityPackage *)defaultActivityPackage {
    ALTActivityPackage *activityPackage = [[ALTActivityPackage alloc] init];
    activityPackage.clientSdk = self.packageParams.clientSdk;
    return activityPackage;
}

- (NSString *)eventSuffix:(ALTEvent *)event {
    if (event.revenue == nil) {
        return [NSString stringWithFormat:@"'%@'", event.eventToken];
    } else {
        return [NSString stringWithFormat:@"(%.5f %@, '%@')", [event.revenue doubleValue], event.currency, event.eventToken];
    }
}

+ (void)parameters:(NSMutableDictionary *)parameters setInt:(int)value forKey:(NSString *)key {
    if (value < 0) {
        return;
    }
    NSString *valueString = [NSString stringWithFormat:@"%d", value];
    [ALTPackageBuilder parameters:parameters setString:valueString forKey:key];
}

+ (void)parameters:(NSMutableDictionary *)parameters setDate1970:(double)value forKey:(NSString *)key {
    if (value < 0) {
        return;
    }
    NSString *dateString = [ALTUtil formatSeconds1970:value];
    [ALTPackageBuilder parameters:parameters setString:dateString forKey:key];
}

+ (void)parameters:(NSMutableDictionary *)parameters setDate:(NSDate *)value forKey:(NSString *)key {
    if (value == nil) {
        return;
    }
    NSString *dateString = [ALTUtil formatDate:value];
    [ALTPackageBuilder parameters:parameters setString:dateString forKey:key];
}

+ (void)parameters:(NSMutableDictionary *)parameters setDuration:(double)value forKey:(NSString *)key {
    if (value < 0) {
        return;
    }
    int intValue = round(value);
    [ALTPackageBuilder parameters:parameters setInt:intValue forKey:key];
}

+ (void)parameters:(NSMutableDictionary *)parameters setDictionaryJson:(NSDictionary *)dictionary forKey:(NSString *)key {
    if (dictionary == nil) {
        return;
    }
    if (dictionary.count == 0) {
        return;
    }
    if (![NSJSONSerialization isValidJSONObject:dictionary]) {
        return;
    }

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:nil];
    NSString *dictionaryString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [ALTPackageBuilder parameters:parameters setString:dictionaryString forKey:key];
}

+ (void)parameters:(NSMutableDictionary *)parameters setBool:(BOOL)value forKey:(NSString *)key {
    int valueInt = [[NSNumber numberWithBool:value] intValue];
    [ALTPackageBuilder parameters:parameters setInt:valueInt forKey:key];
}

+ (void)parameters:(NSMutableDictionary *)parameters setNumber:(NSNumber *)value forKey:(NSString *)key {
    if (value == nil) {
        return;
    }
    NSString *numberString = [NSString stringWithFormat:@"%.5f", [value doubleValue]];
    [ALTPackageBuilder parameters:parameters setString:numberString forKey:key];
}

+ (void)parameters:(NSMutableDictionary *)parameters setNumberWithoutRounding:(NSNumber *)value forKey:(NSString *)key {
    if (value == nil) {
        return;
    }
    NSString *numberString = [value stringValue];
    [ALTPackageBuilder parameters:parameters setString:numberString forKey:key];
}

+ (void)parameters:(NSMutableDictionary *)parameters setNumberInt:(NSNumber *)value forKey:(NSString *)key {
    if (value == nil) {
        return;
    }
    [ALTPackageBuilder parameters:parameters setInt:[value intValue] forKey:key];
}

+ (void)parameters:(NSMutableDictionary *)parameters setData:(NSData *)value forKey:(NSString *)key {
    if (value == nil) {
        return;
    }
    [ALTPackageBuilder parameters:parameters
                        setString:[[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding]
                           forKey:key];
}

+ (BOOL)isAdServicesPackage:(ALTActivityPackage *)activityPackage {
    NSString *source = activityPackage.parameters[@"source"];
    return ([ALTUtil isNotNull:source] && [source isEqualToString:ALTAdServicesPackageKey]);
}

@end
