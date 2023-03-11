#import "ALTActivityKind.h"

@implementation ALTActivityKindUtil

#pragma mark - Public methods

+ (ALTActivityKind)activityKindFromString:(NSString *)activityKindString {
    if ([@"session" isEqualToString:activityKindString]) {
        return ALTActivityKindSession;
    } else if ([@"event" isEqualToString:activityKindString]) {
        return ALTActivityKindEvent;
    } else if ([@"click" isEqualToString:activityKindString]) {
        return ALTActivityKindClick;
    } else if ([@"attribution" isEqualToString:activityKindString]) {
        return ALTActivityKindAttribution;
    } else if ([@"info" isEqualToString:activityKindString]) {
        return ALTActivityKindInfo;
    } else if ([@"gdpr" isEqualToString:activityKindString]) {
        return ALTActivityKindGdpr;
    } else if ([@"ad_revenue" isEqualToString:activityKindString]) {
        return ALTActivityKindAdRevenue;
    } else if ([@"disable_third_party_sharing" isEqualToString:activityKindString]) {
        return ALTActivityKindDisableThirdPartySharing;
    } else if ([@"subscription" isEqualToString:activityKindString]) {
        return ALTActivityKindSubscription;
    } else if ([@"third_party_sharing" isEqualToString:activityKindString]) {
        return ALTActivityKindThirdPartySharing;
    } else if ([@"measurement_consent" isEqualToString:activityKindString]) {
        return ALTActivityKindMeasurementConsent;
    } else {
        return ALTActivityKindUnknown;
    }
}

+ (NSString *)activityKindToString:(ALTActivityKind)activityKind {
    switch (activityKind) {
        case ALTActivityKindSession:
            return @"session";
        case ALTActivityKindEvent:
            return @"event";
        case ALTActivityKindClick:
            return @"click";
        case ALTActivityKindAttribution:
            return @"attribution";
        case ALTActivityKindInfo:
            return @"info";
        case ALTActivityKindGdpr:
            return @"gdpr";
        case ALTActivityKindAdRevenue:
            return @"ad_revenue";
        case ALTActivityKindDisableThirdPartySharing:
            return @"disable_third_party_sharing";
        case ALTActivityKindSubscription:
            return @"subscription";
        case ALTActivityKindThirdPartySharing:
            return @"third_party_sharing";
        case ALTActivityKindMeasurementConsent:
            return @"measurement_consent";
        default:
            return @"unknown";
    }
}

@end
