#import "ALTAlltrackFactory.h"
#import "ALTActivityHandler.h"
#import "ALTPackageHandler.h"

static id<ALTLogger> internalLogger = nil;

static double internalSessionInterval    = -1;
static double intervalSubsessionInterval = -1;
static double internalRequestTimeout = -1;
static NSTimeInterval internalTimerInterval = -1;
static NSTimeInterval intervalTimerStart = -1;
static ALTBackoffStrategy * packageHandlerBackoffStrategy = nil;
static ALTBackoffStrategy * sdkClickHandlerBackoffStrategy = nil;
static ALTBackoffStrategy * installSessionBackoffStrategy = nil;
static BOOL internalTesting = NO;
static NSTimeInterval internalMaxDelayStart = -1;
static BOOL internaliAdFrameworkEnabled = YES;
static BOOL internalAdServicesFrameworkEnabled = YES;

static NSString * internalBaseUrl = nil;
static NSString * internalGdprUrl = nil;
static NSString * internalSubscriptionUrl = nil;

@implementation ALTAlltrackFactory

+ (id<ALTLogger>)logger {
    if (internalLogger == nil) {
        //  same instance of logger
        internalLogger = [[ALTLogger alloc] init];
    }
    return internalLogger;
}

+ (double)sessionInterval {
    if (internalSessionInterval < 0) {
        return 30 * 60;           // 30 minutes
    }
    return internalSessionInterval;
}

+ (double)subsessionInterval {
    if (intervalSubsessionInterval == -1) {
        return 1;                 // 1 second
    }
    return intervalSubsessionInterval;
}

+ (double)requestTimeout {
    if (internalRequestTimeout == -1) {
        return 60;                 // 60 second
    }
    return internalRequestTimeout;
}

+ (NSTimeInterval)timerInterval {
    if (internalTimerInterval < 0) {
        return 60;                // 1 minute
    }
    return internalTimerInterval;
}

+ (NSTimeInterval)timerStart {
    if (intervalTimerStart < 0) {
        return 60;                 // 1 minute
    }
    return intervalTimerStart;
}

+ (ALTBackoffStrategy *)packageHandlerBackoffStrategy {
    if (packageHandlerBackoffStrategy == nil) {
        return [ALTBackoffStrategy backoffStrategyWithType:ALTLongWait];
    }
    return packageHandlerBackoffStrategy;
}

+ (ALTBackoffStrategy *)sdkClickHandlerBackoffStrategy {
    if (sdkClickHandlerBackoffStrategy == nil) {
        return [ALTBackoffStrategy backoffStrategyWithType:ALTShortWait];
    }
    return sdkClickHandlerBackoffStrategy;
}

+ (ALTBackoffStrategy *)installSessionBackoffStrategy {
    if (installSessionBackoffStrategy == nil) {
        return [ALTBackoffStrategy backoffStrategyWithType:ALTShortWait];
    }
    return installSessionBackoffStrategy;
}

+ (BOOL)testing {
    return internalTesting;
}

+ (BOOL)iAdFrameworkEnabled {
    return internaliAdFrameworkEnabled;
}

+ (BOOL)adServicesFrameworkEnabled {
    return internalAdServicesFrameworkEnabled;
}

+ (NSTimeInterval)maxDelayStart {
    if (internalMaxDelayStart < 0) {
        return 10.0;               // 10 seconds
    }
    return internalMaxDelayStart;
}

+ (NSString *)baseUrl {
    return internalBaseUrl;
}

+ (NSString *)gdprUrl {
    return internalGdprUrl;
}

+ (NSString *)subscriptionUrl {
    return internalSubscriptionUrl;
}

+ (void)setLogger:(id<ALTLogger>)logger {
    internalLogger = logger;
}

+ (void)setSessionInterval:(double)sessionInterval {
    internalSessionInterval = sessionInterval;
}

+ (void)setSubsessionInterval:(double)subsessionInterval {
    intervalSubsessionInterval = subsessionInterval;
}

+ (void)setRequestTimeout:(double)requestTimeout {
    internalRequestTimeout = requestTimeout;
}

+ (void)setTimerInterval:(NSTimeInterval)timerInterval {
    internalTimerInterval = timerInterval;
}

+ (void)setTimerStart:(NSTimeInterval)timerStart {
    intervalTimerStart = timerStart;
}

+ (void)setPackageHandlerBackoffStrategy:(ALTBackoffStrategy *)backoffStrategy {
    packageHandlerBackoffStrategy = backoffStrategy;
}

+ (void)setSdkClickHandlerBackoffStrategy:(ALTBackoffStrategy *)backoffStrategy {
    sdkClickHandlerBackoffStrategy = backoffStrategy;
}

+ (void)setTesting:(BOOL)testing {
    internalTesting = testing;
}

+ (void)setiAdFrameworkEnabled:(BOOL)iAdFrameworkEnabled {
    internaliAdFrameworkEnabled = iAdFrameworkEnabled;
}

+ (void)setAdServicesFrameworkEnabled:(BOOL)adServicesFrameworkEnabled {
    internalAdServicesFrameworkEnabled = adServicesFrameworkEnabled;
}

+ (void)setMaxDelayStart:(NSTimeInterval)maxDelayStart {
    internalMaxDelayStart = maxDelayStart;
}

+ (void)setBaseUrl:(NSString *)baseUrl {
    internalBaseUrl = baseUrl;
}

+ (void)setGdprUrl:(NSString *)gdprUrl {
    internalGdprUrl = gdprUrl;
}

+ (void)setSubscriptionUrl:(NSString *)subscriptionUrl {
    internalSubscriptionUrl = subscriptionUrl;
}

+ (void)enableSigning {
    Class signerClass = NSClassFromString(@"ALTSigner");
    if (signerClass == nil) {
        return;
    }

    SEL enabledSEL = NSSelectorFromString(@"enableSigning");
    if (![signerClass respondsToSelector:enabledSEL]) {
        return;
    }

    IMP enableIMP = [signerClass methodForSelector:enabledSEL];
    if (!enableIMP) {
        return;
    }

    void (*enableFunc)(id, SEL) = (void *)enableIMP;

    enableFunc(signerClass, enabledSEL);
}

+ (void)disableSigning {
    Class signerClass = NSClassFromString(@"ALTSigner");
    if (signerClass == nil) {
        return;
    }

    SEL disableSEL = NSSelectorFromString(@"disableSigning");
    if (![signerClass respondsToSelector:disableSEL]) {
        return;
    }

    IMP disableIMP = [signerClass methodForSelector:disableSEL];
    if (!disableIMP) {
        return;
    }

    void (*disableFunc)(id, SEL) = (void *)disableIMP;

    disableFunc(signerClass, disableSEL);
}

+ (void)teardown:(BOOL)deleteState {
    if (deleteState) {
        [ALTActivityHandler deleteState];
        [ALTPackageHandler deleteState];
    }
    internalLogger = nil;

    internalSessionInterval = -1;
    intervalSubsessionInterval = -1;
    internalTimerInterval = -1;
    intervalTimerStart = -1;
    internalRequestTimeout = -1;
    packageHandlerBackoffStrategy = nil;
    sdkClickHandlerBackoffStrategy = nil;
    installSessionBackoffStrategy = nil;
    internalTesting = NO;
    internalMaxDelayStart = -1;
    internalBaseUrl = nil;
    internalGdprUrl = nil;
    internalSubscriptionUrl = nil;
    internaliAdFrameworkEnabled = YES;
    internalAdServicesFrameworkEnabled = YES;
}
@end
