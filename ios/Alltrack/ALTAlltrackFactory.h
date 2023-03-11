#import <Foundation/Foundation.h>

#import "ALTLogger.h"
#import "ALTActivityPackage.h"
#import "ALTBackoffStrategy.h"
#import "ALTSdkClickHandler.h"

@interface ALTAlltrackFactory : NSObject

+ (id<ALTLogger>)logger;
+ (double)sessionInterval;
+ (double)subsessionInterval;
+ (double)requestTimeout;
+ (NSTimeInterval)timerInterval;
+ (NSTimeInterval)timerStart;
+ (ALTBackoffStrategy *)packageHandlerBackoffStrategy;
+ (ALTBackoffStrategy *)sdkClickHandlerBackoffStrategy;
+ (ALTBackoffStrategy *)installSessionBackoffStrategy;

+ (BOOL)testing;
+ (NSTimeInterval)maxDelayStart;
+ (NSString *)baseUrl;
+ (NSString *)gdprUrl;
+ (NSString *)subscriptionUrl;
+ (BOOL)iAdFrameworkEnabled;
+ (BOOL)adServicesFrameworkEnabled;

+ (void)setLogger:(id<ALTLogger>)logger;
+ (void)setSessionInterval:(double)sessionInterval;
+ (void)setSubsessionInterval:(double)subsessionInterval;
+ (void)setRequestTimeout:(double)requestTimeout;
+ (void)setTimerInterval:(NSTimeInterval)timerInterval;
+ (void)setTimerStart:(NSTimeInterval)timerStart;
+ (void)setPackageHandlerBackoffStrategy:(ALTBackoffStrategy *)backoffStrategy;
+ (void)setSdkClickHandlerBackoffStrategy:(ALTBackoffStrategy *)backoffStrategy;
+ (void)setTesting:(BOOL)testing;
+ (void)setiAdFrameworkEnabled:(BOOL)iAdFrameworkEnabled;
+ (void)setAdServicesFrameworkEnabled:(BOOL)adServicesFrameworkEnabled;
+ (void)setMaxDelayStart:(NSTimeInterval)maxDelayStart;
+ (void)setBaseUrl:(NSString *)baseUrl;
+ (void)setGdprUrl:(NSString *)gdprUrl;
+ (void)setSubscriptionUrl:(NSString *)subscriptionUrl;

+ (void)enableSigning;
+ (void)disableSigning;

+ (void)teardown:(BOOL)deleteState;
@end
