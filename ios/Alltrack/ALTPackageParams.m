#import <UIKit/UIKit.h>

#import "ALTPackageParams.h"
#import "ALTUtil.h"

@implementation ALTPackageParams

+ (ALTPackageParams *) packageParamsWithSdkPrefix:(NSString *)sdkPrefix {
    return [[ALTPackageParams alloc] initWithSdkPrefix:sdkPrefix];
}

- (id)initWithSdkPrefix:(NSString *)sdkPrefix {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    self.osName = @"ios";
    self.idfv = [ALTUtil idfv];
    self.fbAnonymousId = [ALTUtil fbAnonymousId];
    self.bundleIdentifier = [ALTUtil bundleIdentifier];
    self.buildNumber = [ALTUtil buildNumber];
    self.versionNumber = [ALTUtil versionNumber];
    self.deviceType = [ALTUtil deviceType];
    self.deviceName = [ALTUtil deviceName];
    self.osVersion = [ALTUtil osVersion];
    self.installedAt = [ALTUtil installedAt];
    self.startedAt = [ALTUtil startedAt];
    if (sdkPrefix == nil) {
        self.clientSdk = ALTUtil.clientSdk;
    } else {
        self.clientSdk = [NSString stringWithFormat:@"%@@%@", sdkPrefix, ALTUtil.clientSdk];
    }

    return self;
}

@end
