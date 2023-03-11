#import "ALTEvent.h"
#import "ALTConfig.h"
#import "ALTPackageParams.h"
#import "ALTActivityState.h"
#import "ALTActivityPackage.h"
#import "ALTSessionParameters.h"
#import <Foundation/Foundation.h>
#import "ALTActivityHandler.h"
#import "ALTThirdPartySharing.h"

@interface ALTPackageBuilder : NSObject

@property (nonatomic, copy) NSString * _Nullable deeplink;

@property (nonatomic, copy) NSString * _Nullable reftag;

@property (nonatomic, copy) NSDate * _Nullable clickTime;

@property (nonatomic, copy) NSDate * _Nullable purchaseTime;

@property (nonatomic, strong) NSDictionary * _Nullable attributionDetails;

@property (nonatomic, strong) NSDictionary * _Nullable deeplinkParameters;

@property (nonatomic, copy) ALTAttribution * _Nullable attribution;

- (id _Nullable)initWithPackageParams:(ALTPackageParams * _Nullable)packageParams
                        activityState:(ALTActivityState * _Nullable)activityState
                               config:(ALTConfig * _Nullable)alltrackConfig
                    sessionParameters:(ALTSessionParameters * _Nullable)sessionParameters
                trackingStatusManager:(ALTTrackingStatusManager * _Nullable)trackingStatusManager
                            createdAt:(double)createdAt;

- (ALTActivityPackage * _Nullable)buildSessionPackage:(BOOL)isInDelay;

- (ALTActivityPackage * _Nullable)buildEventPackage:(ALTEvent * _Nullable)event
                                isInDelay:(BOOL)isInDelay;

- (ALTActivityPackage * _Nullable)buildInfoPackage:(NSString * _Nullable)infoSource;

- (ALTActivityPackage * _Nullable)buildAdRevenuePackage:(NSString * _Nullable)source
                                                payload:(NSData * _Nullable)payload;

- (ALTActivityPackage * _Nullable)buildClickPackage:(NSString * _Nullable)clickSource;

- (ALTActivityPackage * _Nullable)buildClickPackage:(NSString * _Nullable)clickSource
                                              token:(NSString * _Nullable)token
                                    errorCodeNumber:(NSNumber * _Nullable)errorCodeNumber;

- (ALTActivityPackage * _Nullable)buildClickPackage:(NSString * _Nullable)clickSource
                                          linkMeUrl:(NSString * _Nullable)linkMeUrl;

- (ALTActivityPackage * _Nullable)buildAttributionPackage:(NSString * _Nullable)initiatedBy;

- (ALTActivityPackage * _Nullable)buildGdprPackage;

- (ALTActivityPackage * _Nullable)buildDisableThirdPartySharingPackage;

- (ALTActivityPackage * _Nullable)buildThirdPartySharingPackage:(nonnull ALTThirdPartySharing *)thirdPartySharing;

- (ALTActivityPackage * _Nullable)buildMeasurementConsentPackage:(BOOL)enabled;

- (ALTActivityPackage * _Nullable)buildSubscriptionPackage:( ALTSubscription * _Nullable)subscription
                                                 isInDelay:(BOOL)isInDelay;

- (ALTActivityPackage * _Nullable)buildAdRevenuePackage:(ALTAdRevenue * _Nullable)adRevenue
                                              isInDelay:(BOOL)isInDelay;

+ (void)parameters:(NSMutableDictionary * _Nullable)parameters
     setDictionary:(NSDictionary * _Nullable)dictionary
            forKey:(NSString * _Nullable)key;

+ (void)parameters:(NSMutableDictionary * _Nullable)parameters
         setString:(NSString * _Nullable)value
            forKey:(NSString * _Nullable)key;

+ (void)parameters:(NSMutableDictionary * _Nullable)parameters
            setInt:(int)value
            forKey:(NSString * _Nullable)key;

+ (void)parameters:(NSMutableDictionary * _Nullable)parameters
       setDate1970:(double)value
            forKey:(NSString * _Nullable)key;

+ (BOOL)isAdServicesPackage:(ALTActivityPackage * _Nullable)activityPackage;

@end
// TODO change to ALT...
extern NSString * _Nullable const ALTAttributionTokenParameter;
