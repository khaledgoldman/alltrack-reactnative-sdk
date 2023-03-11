#import "ALTConfig.h"
#import "ALTAlltrackFactory.h"
#import "ALTLogger.h"
#import "ALTUtil.h"
#import "Alltrack.h"

@interface ALTConfig()

@property (nonatomic, weak) id<ALTLogger> logger;

@end

@implementation ALTConfig

+ (ALTConfig *)configWithAppToken:(NSString *)appToken
                      environment:(NSString *)environment {
    return [[ALTConfig alloc] initWithAppToken:appToken environment:environment];
}

+ (ALTConfig *)configWithAppToken:(NSString *)appToken
                      environment:(NSString *)environment
             allowSuppressLogLevel:(BOOL)allowSuppressLogLevel {
    return [[ALTConfig alloc] initWithAppToken:appToken environment:environment allowSuppressLogLevel:allowSuppressLogLevel];
}

- (id)initWithAppToken:(NSString *)appToken
           environment:(NSString *)environment {
    return [self initWithAppToken:appToken
                      environment:environment
             allowSuppressLogLevel:NO];
}

- (id)initWithAppToken:(NSString *)appToken
           environment:(NSString *)environment
  allowSuppressLogLevel:(BOOL)allowSuppressLogLevel {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    self.logger = ALTAlltrackFactory.logger;

    if (allowSuppressLogLevel && [ALTEnvironmentProduction isEqualToString:environment]) {
        [self setLogLevel:ALTLogLevelSuppress environment:environment];
    } else {
        [self setLogLevel:ALTLogLevelInfo environment:environment];
    }

    if (![self checkEnvironment:environment]) {
        return self;
    }
    if (![self checkAppToken:appToken]) {
        return self;
    }

    _appToken = appToken;
    _environment = environment;
    
    // default values
    self.sendInBackground = NO;
    self.eventBufferingEnabled = NO;
    self.coppaCompliantEnabled = NO;
    self.allowIdfaReading = YES;
    self.allowiAdInfoReading = YES;
    self.allowAdServicesInfoReading = YES;
    self.linkMeEnabled = NO;
    _isSKAdNetworkHandlingActive = YES;

    return self;
}

- (void)setLogLevel:(ALTLogLevel)logLevel {
    [self setLogLevel:logLevel environment:self.environment];
}

- (void)setLogLevel:(ALTLogLevel)logLevel
        environment:(NSString *)environment {
    [self.logger setLogLevel:logLevel
     isProductionEnvironment:[ALTEnvironmentProduction isEqualToString:environment]];
}

- (void)deactivateSKAdNetworkHandling {
    _isSKAdNetworkHandlingActive = NO;
}

- (void)setDelegate:(NSObject<AlltrackDelegate> *)delegate {
    BOOL hasResponseDelegate = NO;
    BOOL implementsDeeplinkCallback = NO;

    if ([ALTUtil isNull:delegate]) {
        [self.logger warn:@"Delegate is nil"];
        _delegate = nil;
        return;
    }

    if ([delegate respondsToSelector:@selector(alltrackAttributionChanged:)]) {
        [self.logger debug:@"Delegate implements alltrackAttributionChanged:"];
        hasResponseDelegate = YES;
    }

    if ([delegate respondsToSelector:@selector(alltrackEventTrackingSucceeded:)]) {
        [self.logger debug:@"Delegate implements alltrackEventTrackingSucceeded:"];
        hasResponseDelegate = YES;
    }

    if ([delegate respondsToSelector:@selector(alltrackEventTrackingFailed:)]) {
        [self.logger debug:@"Delegate implements alltrackEventTrackingFailed:"];
        hasResponseDelegate = YES;
    }

    if ([delegate respondsToSelector:@selector(alltrackSessionTrackingSucceeded:)]) {
        [self.logger debug:@"Delegate implements alltrackSessionTrackingSucceeded:"];
        hasResponseDelegate = YES;
    }

    if ([delegate respondsToSelector:@selector(alltrackSessionTrackingFailed:)]) {
        [self.logger debug:@"Delegate implements alltrackSessionTrackingFailed:"];
        hasResponseDelegate = YES;
    }

    if ([delegate respondsToSelector:@selector(alltrackDeeplinkResponse:)]) {
        [self.logger debug:@"Delegate implements alltrackDeeplinkResponse:"];
        // does not enable hasDelegate flag
        implementsDeeplinkCallback = YES;
    }
    
    if ([delegate respondsToSelector:@selector(alltrackConversionValueUpdated:)]) {
        [self.logger debug:@"Delegate implements alltrackConversionValueUpdated:"];
        hasResponseDelegate = YES;
    }

    if (!(hasResponseDelegate || implementsDeeplinkCallback)) {
        [self.logger error:@"Delegate does not implement any optional method"];
        _delegate = nil;
        return;
    }

    _delegate = delegate;
}

- (BOOL)checkEnvironment:(NSString *)environment {
    if ([ALTUtil isNull:environment]) {
        [self.logger error:@"Missing environment"];
        return NO;
    }
    if ([environment isEqualToString:ALTEnvironmentSandbox]) {
        [self.logger warnInProduction:@"SANDBOX: Alltrack is running in Sandbox mode. Use this setting for testing. Don't forget to set the environment to `production` before publishing"];
        return YES;
    } else if ([environment isEqualToString:ALTEnvironmentProduction]) {
        [self.logger warnInProduction:@"PRODUCTION: Alltrack is running in Production mode. Use this setting only for the build that you want to publish. Set the environment to `sandbox` if you want to test your app!"];
        return YES;
    }
    [self.logger error:@"Unknown environment '%@'", environment];
    return NO;
}

- (BOOL)checkAppToken:(NSString *)appToken {
    if ([ALTUtil isNull:appToken]) {
        [self.logger error:@"Missing App Token"];
        return NO;
    }
    if (appToken.length != 12) {
        [self.logger error:@"Malformed App Token '%@'", appToken];
        return NO;
    }
    return YES;
}

- (BOOL)isValid {
    return self.appToken != nil;
}

- (void)setAppSecret:(NSUInteger)secretId
               info1:(NSUInteger)info1
               info2:(NSUInteger)info2
               info3:(NSUInteger)info3
               info4:(NSUInteger)info4 {
    _secretId = [NSString stringWithFormat:@"%lu", (unsigned long)secretId];
    _appSecret = [NSString stringWithFormat:@"%lu%lu%lu%lu",
                   (unsigned long)info1,
                   (unsigned long)info2,
                   (unsigned long)info3,
                   (unsigned long)info4];
}

- (id)copyWithZone:(NSZone *)zone {
    ALTConfig *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        copy->_appToken = [self.appToken copyWithZone:zone];
        copy->_environment = [self.environment copyWithZone:zone];
        copy.logLevel = self.logLevel;
        copy.sdkPrefix = [self.sdkPrefix copyWithZone:zone];
        copy.defaultTracker = [self.defaultTracker copyWithZone:zone];
        copy.eventBufferingEnabled = self.eventBufferingEnabled;
        copy.sendInBackground = self.sendInBackground;
        copy.allowIdfaReading = self.allowIdfaReading;
        copy.allowiAdInfoReading = self.allowiAdInfoReading;
        copy.allowAdServicesInfoReading = self.allowAdServicesInfoReading;
        copy.delayStart = self.delayStart;
        copy.coppaCompliantEnabled = self.coppaCompliantEnabled;
        copy.userAgent = [self.userAgent copyWithZone:zone];
        copy.externalDeviceId = [self.externalDeviceId copyWithZone:zone];
        copy.isDeviceKnown = self.isDeviceKnown;
        copy.needsCost = self.needsCost;
        copy->_secretId = [self.secretId copyWithZone:zone];
        copy->_appSecret = [self.appSecret copyWithZone:zone];
        copy->_isSKAdNetworkHandlingActive = self.isSKAdNetworkHandlingActive;
        copy->_urlStrategy = [self.urlStrategy copyWithZone:zone];
        copy.linkMeEnabled = self.linkMeEnabled;
        // alltrack delegate not copied
    }

    return copy;
}

@end
