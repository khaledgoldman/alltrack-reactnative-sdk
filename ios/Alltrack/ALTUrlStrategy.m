#import "ALTUrlStrategy.h"
#import "Alltrack.h"
#import "ALTAlltrackFactory.h"

static NSString * const baseUrl = @"https://app.alltrack.com";
static NSString * const gdprUrl = @"https://gdpr.alltrack.com";
static NSString * const subscriptionUrl = @"https://subscription.alltrack.com";

static NSString * const baseUrlIndia = @"https://app.alltrack.net.in";
static NSString * const gdprUrlIndia = @"https://gdpr.alltrack.net.in";
static NSString * const subscriptionUrlIndia = @"https://subscription.alltrack.net.in";

static NSString * const baseUrlChina = @"https://app.alltrack.world";
static NSString * const gdprUrlChina = @"https://gdpr.alltrack.world";
static NSString * const subscriptionUrlChina = @"https://subscription.alltrack.world";

static NSString * const baseUrlCn = @"https://app.alltrack.cn";
static NSString * const gdprUrlCn = @"https://gdpr.alltrack.com";
static NSString * const subscriptionUrlCn = @"https://subscription.alltrack.com";

static NSString * const baseUrlEU = @"https://app.eu.alltrack.com";
static NSString * const gdprUrlEU = @"https://gdpr.eu.alltrack.com";
static NSString * const subscriptionUrlEU = @"https://subscription.eu.alltrack.com";

static NSString * const baseUrlTR = @"https://app.tr.alltrack.com";
static NSString * const gdprUrlTR = @"https://gdpr.tr.alltrack.com";
static NSString * const subscriptionUrlTR = @"https://subscription.tr.alltrack.com";

static NSString * const baseUrlUS = @"https://app.us.alltrack.com";
static NSString * const gdprUrlUS = @"https://gdpr.us.alltrack.com";
static NSString * const subscriptionUrlUS = @"https://subscription.us.alltrack.com";

@interface ALTUrlStrategy ()

@property (nonatomic, copy) NSArray<NSString *> *baseUrlChoicesArray;
@property (nonatomic, copy) NSArray<NSString *> *gdprUrlChoicesArray;
@property (nonatomic, copy) NSArray<NSString *> *subscriptionUrlChoicesArray;

@property (nonatomic, copy) NSString *overridenBaseUrl;
@property (nonatomic, copy) NSString *overridenGdprUrl;
@property (nonatomic, copy) NSString *overridenSubscriptionUrl;

@property (nonatomic, assign) BOOL wasLastAttemptSuccess;

@property (nonatomic, assign) NSUInteger choiceIndex;
@property (nonatomic, assign) NSUInteger startingChoiceIndex;

@end

@implementation ALTUrlStrategy

- (instancetype)initWithUrlStrategyInfo:(NSString *)urlStrategyInfo
                              extraPath:(NSString *)extraPath
{
    self = [super init];

    _extraPath = extraPath ?: @"";

    _baseUrlChoicesArray = [ALTUrlStrategy baseUrlChoicesWithUrlStrategyInfo:urlStrategyInfo];
    _gdprUrlChoicesArray = [ALTUrlStrategy gdprUrlChoicesWithUrlStrategyInfo:urlStrategyInfo];
    _subscriptionUrlChoicesArray = [ALTUrlStrategy
                                    subscriptionUrlChoicesWithUrlStrategyInfo:urlStrategyInfo];

    _overridenBaseUrl = [ALTAlltrackFactory baseUrl];
    _overridenGdprUrl = [ALTAlltrackFactory gdprUrl];
    _overridenSubscriptionUrl = [ALTAlltrackFactory subscriptionUrl];

    _wasLastAttemptSuccess = NO;

    _choiceIndex = 0;
    _startingChoiceIndex = 0;

    return self;
}

+ (NSArray<NSString *> *)baseUrlChoicesWithUrlStrategyInfo:(NSString *)urlStrategyInfo {
    if ([urlStrategyInfo isEqualToString:ALTUrlStrategyIndia]) {
        return @[baseUrlIndia, baseUrl];
    } else if ([urlStrategyInfo isEqualToString:ALTUrlStrategyChina]) {
        return @[baseUrlChina, baseUrl];
    } else if ([urlStrategyInfo isEqualToString:ALTUrlStrategyCn]) {
        return @[baseUrlCn, baseUrl];
    } else if ([urlStrategyInfo isEqualToString:ALTDataResidencyEU]) {
        return @[baseUrlEU];
    } else if ([urlStrategyInfo isEqualToString:ALTDataResidencyTR]) {
        return @[baseUrlTR];
    } else if ([urlStrategyInfo isEqualToString:ALTDataResidencyUS]) {
        return @[baseUrlUS];
    } else {
        return @[baseUrl, baseUrlIndia, baseUrlChina];
    }
}

+ (NSArray<NSString *> *)gdprUrlChoicesWithUrlStrategyInfo:(NSString *)urlStrategyInfo {
    if ([urlStrategyInfo isEqualToString:ALTUrlStrategyIndia]) {
        return @[gdprUrlIndia, gdprUrl];
    } else if ([urlStrategyInfo isEqualToString:ALTUrlStrategyChina]) {
        return @[gdprUrlChina, gdprUrl];
    } else if ([urlStrategyInfo isEqualToString:ALTUrlStrategyCn]) {
        return @[gdprUrlCn, gdprUrl];
    } else if ([urlStrategyInfo isEqualToString:ALTDataResidencyEU]) {
        return @[gdprUrlEU];
    } else if ([urlStrategyInfo isEqualToString:ALTDataResidencyTR]) {
        return @[gdprUrlTR];
    } else if ([urlStrategyInfo isEqualToString:ALTDataResidencyUS]) {
        return @[gdprUrlUS];
    } else {
        return @[gdprUrl, gdprUrlIndia, gdprUrlChina];
    }
}

+ (NSArray<NSString *> *)subscriptionUrlChoicesWithUrlStrategyInfo:(NSString *)urlStrategyInfo {
    if ([urlStrategyInfo isEqualToString:ALTUrlStrategyIndia]) {
        return @[subscriptionUrlIndia, subscriptionUrl];
    } else if ([urlStrategyInfo isEqualToString:ALTUrlStrategyChina]) {
        return @[subscriptionUrlChina, subscriptionUrl];
    } else if ([urlStrategyInfo isEqualToString:ALTUrlStrategyCn]) {
        return @[subscriptionUrlCn, subscriptionUrl];
    } else if ([urlStrategyInfo isEqualToString:ALTDataResidencyEU]) {
        return @[subscriptionUrlEU];
    } else if ([urlStrategyInfo isEqualToString:ALTDataResidencyTR]) {
        return @[subscriptionUrlTR];
    } else if ([urlStrategyInfo isEqualToString:ALTDataResidencyUS]) {
        return @[subscriptionUrlUS];
    } else {
        return @[subscriptionUrl, subscriptionUrlIndia, subscriptionUrlChina];
    }
}

- (NSString *)getUrlHostStringByPackageKind:(ALTActivityKind)activityKind {
    if (activityKind == ALTActivityKindGdpr) {
        if (self.overridenGdprUrl != nil) {
            return self.overridenGdprUrl;
        } else {
            return [self.gdprUrlChoicesArray objectAtIndex:self.choiceIndex];
        }
    } else if (activityKind == ALTActivityKindSubscription) {
        if (self.overridenSubscriptionUrl != nil) {
            return self.overridenSubscriptionUrl;
        } else {
            return [self.subscriptionUrlChoicesArray objectAtIndex:self.choiceIndex];
        }
    } else {
        if (self.overridenBaseUrl != nil) {
            return self.overridenBaseUrl;
        } else {
            return [self.baseUrlChoicesArray objectAtIndex:self.choiceIndex];
        }
    }
}

- (void)resetAfterSuccess {
    self.startingChoiceIndex = self.choiceIndex;
    self.wasLastAttemptSuccess = YES;
}

- (BOOL)shouldRetryAfterFailure:(ALTActivityKind)activityKind {
    self.wasLastAttemptSuccess = NO;

    NSUInteger choiceListSize;
    if (activityKind == ALTActivityKindGdpr) {
        choiceListSize = [_gdprUrlChoicesArray count];
    } else if (activityKind == ALTActivityKindSubscription) {
        choiceListSize = [_subscriptionUrlChoicesArray count];
    } else {
        choiceListSize = [_baseUrlChoicesArray count];
    }

    NSUInteger nextChoiceIndex = (self.choiceIndex + 1) % choiceListSize;
    self.choiceIndex = nextChoiceIndex;

    BOOL nextChoiceHasNotReturnedToStartingChoice = self.choiceIndex != self.startingChoiceIndex;
    return nextChoiceHasNotReturnedToStartingChoice;
}

@end
