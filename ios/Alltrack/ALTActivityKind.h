#import <Foundation/Foundation.h>

#ifndef NS_ENUM
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#endif

typedef NS_ENUM(int, ALTActivityKind) {
    ALTActivityKindUnknown = 0,
    ALTActivityKindSession = 1,
    ALTActivityKindEvent = 2,
    // ALTActivityKindRevenue = 3,
    ALTActivityKindClick = 4,
    ALTActivityKindAttribution = 5,
    ALTActivityKindInfo = 6,
    ALTActivityKindGdpr = 7,
    ALTActivityKindAdRevenue = 8,
    ALTActivityKindDisableThirdPartySharing = 9,
    ALTActivityKindSubscription = 10,
    ALTActivityKindThirdPartySharing = 11,
    ALTActivityKindMeasurementConsent = 12
};

@interface ALTActivityKindUtil : NSObject

+ (NSString *)activityKindToString:(ALTActivityKind)activityKind;

+ (ALTActivityKind)activityKindFromString:(NSString *)activityKindString;

@end
