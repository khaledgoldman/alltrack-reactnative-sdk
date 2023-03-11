#import "Alltrack.h"
#import "ALTResponseData.h"
#import "ALTActivityState.h"
#import "ALTPackageParams.h"
#import "ALTSessionParameters.h"
#import "ALTThirdPartySharing.h"

@interface ALTInternalState : NSObject

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL offline;
@property (nonatomic, assign) BOOL background;
@property (nonatomic, assign) BOOL delayStart;
@property (nonatomic, assign) BOOL updatePackages;
@property (nonatomic, assign) BOOL firstLaunch;
@property (nonatomic, assign) BOOL sessionResponseProcessed;

- (BOOL)isEnabled;
- (BOOL)isDisabled;
- (BOOL)isOffline;
- (BOOL)isOnline;
- (BOOL)isInBackground;
- (BOOL)isInForeground;
- (BOOL)isInDelayedStart;
- (BOOL)isNotInDelayedStart;
- (BOOL)itHasToUpdatePackages;
- (BOOL)isFirstLaunch;
- (BOOL)hasSessionResponseNotBeenProcessed;

@end

@interface ALTSavedPreLaunch : NSObject

@property (nonatomic, strong) NSMutableArray * _Nullable preLaunchActionsArray;
@property (nonatomic, copy) NSData *_Nullable deviceTokenData;
@property (nonatomic, copy) NSNumber *_Nullable enabled;
@property (nonatomic, assign) BOOL offline;
@property (nonatomic, copy) NSString *_Nullable extraPath;
@property (nonatomic, strong) NSMutableArray *_Nullable preLaunchAlltrackThirdPartySharingArray;
@property (nonatomic, copy) NSNumber *_Nullable lastMeasurementConsentTracked;

- (nonnull id)init;

@end

@class ALTTrackingStatusManager;

@protocol ALTActivityHandler <NSObject>

@property (nonatomic, copy) ALTAttribution * _Nullable attribution;
@property (nonatomic, strong) ALTTrackingStatusManager * _Nullable trackingStatusManager;

- (NSString *_Nullable)adid;

- (id _Nullable)initWithConfig:(ALTConfig *_Nullable)alltrackConfig
                savedPreLaunch:(ALTSavedPreLaunch * _Nullable)savedPreLaunch;

- (void)applicationDidBecomeActive;
- (void)applicationWillResignActive;

- (void)trackEvent:(ALTEvent * _Nullable)event;

- (void)finishedTracking:(ALTResponseData * _Nullable)responseData;
- (void)launchEventResponseTasks:(ALTEventResponseData * _Nullable)eventResponseData;
- (void)launchSessionResponseTasks:(ALTSessionResponseData * _Nullable)sessionResponseData;
- (void)launchSdkClickResponseTasks:(ALTSdkClickResponseData * _Nullable)sdkClickResponseData;
- (void)launchAttributionResponseTasks:(ALTAttributionResponseData * _Nullable)attributionResponseData;
- (void)setEnabled:(BOOL)enabled;
- (BOOL)isEnabled;
- (BOOL)isGdprForgotten;

- (void)appWillOpenUrl:(NSURL * _Nullable)url
         withClickTime:(NSDate * _Nullable)clickTime;
- (void)setDeviceToken:(NSData * _Nullable)deviceToken;
- (void)setPushToken:(NSString * _Nullable)deviceToken;
- (void)setGdprForgetMe;
- (void)setTrackingStateOptedOut;
- (void)setAskingAttribution:(BOOL)askingAttribution;

- (BOOL)updateAttributionI:(id<ALTActivityHandler> _Nullable)selfI
               attribution:(ALTAttribution * _Nullable)attribution;
- (void)setAttributionDetails:(NSDictionary * _Nullable)attributionDetails
                        error:(NSError * _Nullable)error;
- (void)setAdServicesAttributionToken:(NSString * _Nullable)token
                                error:(NSError * _Nullable)error;

- (void)setOfflineMode:(BOOL)offline;
- (void)sendFirstPackages;

- (void)addSessionCallbackParameter:(NSString * _Nullable)key
                              value:(NSString * _Nullable)value;
- (void)addSessionPartnerParameter:(NSString * _Nullable)key
                             value:(NSString * _Nullable)value;
- (void)removeSessionCallbackParameter:(NSString * _Nullable)key;
- (void)removeSessionPartnerParameter:(NSString * _Nullable)key;
- (void)resetSessionCallbackParameters;
- (void)resetSessionPartnerParameters;
- (void)trackAdRevenue:(NSString * _Nullable)soruce
               payload:(NSData * _Nullable)payload;
- (void)disableThirdPartySharing;
- (void)trackThirdPartySharing:(nonnull ALTThirdPartySharing *)thirdPartySharing;
- (void)trackMeasurementConsent:(BOOL)enabled;
- (void)trackSubscription:(ALTSubscription * _Nullable)subscription;
- (void)updateAttStatusFromUserCallback:(int)newAttStatusFromUser;
- (void)trackAdRevenue:(ALTAdRevenue * _Nullable)adRevenue;
- (void)checkForNewAttStatus;

- (ALTPackageParams * _Nullable)packageParams;
- (ALTActivityState * _Nullable)activityState;
- (ALTConfig * _Nullable)alltrackConfig;
- (ALTSessionParameters * _Nullable)sessionParameters;

- (void)teardown;
+ (void)deleteState;
@end

@interface ALTActivityHandler : NSObject <ALTActivityHandler>

- (id _Nullable)initWithConfig:(ALTConfig * _Nullable)alltrackConfig
                savedPreLaunch:(ALTSavedPreLaunch * _Nullable)savedPreLaunch;

- (void)addSessionCallbackParameterI:(ALTActivityHandler * _Nullable)selfI
                                 key:(NSString * _Nullable)key
                               value:(NSString * _Nullable)value;

- (void)addSessionPartnerParameterI:(ALTActivityHandler * _Nullable)selfI
                                key:(NSString * _Nullable)key
                              value:(NSString * _Nullable)value;
- (void)removeSessionCallbackParameterI:(ALTActivityHandler * _Nullable)selfI
                                    key:(NSString * _Nullable)key;
- (void)removeSessionPartnerParameterI:(ALTActivityHandler * _Nullable)selfI
                                   key:(NSString * _Nullable)key;
- (void)resetSessionCallbackParametersI:(ALTActivityHandler * _Nullable)selfI;
- (void)resetSessionPartnerParametersI:(ALTActivityHandler * _Nullable)selfI;

@end

@interface ALTTrackingStatusManager : NSObject

- (instancetype _Nullable)initWithActivityHandler:(ALTActivityHandler * _Nullable)activityHandler;

- (void)checkForNewAttStatus;
- (void)updateAttStatusFromUserCallback:(int)newAttStatusFromUser;

- (BOOL)canGetAttStatus;

@property (nonatomic, readonly, assign) BOOL trackingEnabled;
@property (nonatomic, readonly, assign) int attStatus;

@end

extern NSString * _Nullable const ALTiAdPackageKey;
extern NSString * _Nullable const ALTAdServicesPackageKey;
