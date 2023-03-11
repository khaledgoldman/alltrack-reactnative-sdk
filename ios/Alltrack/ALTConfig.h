#import <Foundation/Foundation.h>

#import "ALTLogger.h"
#import "ALTAttribution.h"
#import "ALTEventSuccess.h"
#import "ALTEventFailure.h"
#import "ALTSessionSuccess.h"
#import "ALTSessionFailure.h"

/**
 * @brief Optional delegate that will get informed about tracking results.
 */
@protocol AlltrackDelegate

@optional

/**
 * @brief Optional delegate method that gets called when the attribution information changed.
 *
 * @param attribution The attribution information.
 *
 * @note See ALTAttribution for details.
 */
- (void)alltrackAttributionChanged:(nullable ALTAttribution *)attribution;

/**
 * @brief Optional delegate method that gets called when an event is tracked with success.
 *
 * @param eventSuccessResponseData The response information from tracking with success
 *
 * @note See ALTEventSuccess for details.
 */
- (void)alltrackEventTrackingSucceeded:(nullable ALTEventSuccess *)eventSuccessResponseData;

/**
 * @brief Optional delegate method that gets called when an event is tracked with failure.
 *
 * @param eventFailureResponseData The response information from tracking with failure
 *
 * @note See ALTEventFailure for details.
 */
- (void)alltrackEventTrackingFailed:(nullable ALTEventFailure *)eventFailureResponseData;

/**
 * @brief Optional delegate method that gets called when an session is tracked with success.
 *
 * @param sessionSuccessResponseData The response information from tracking with success
 *
 * @note See ALTSessionSuccess for details.
 */
- (void)alltrackSessionTrackingSucceeded:(nullable ALTSessionSuccess *)sessionSuccessResponseData;

/**
 * @brief Optional delegate method that gets called when an session is tracked with failure.
 *
 * @param sessionFailureResponseData The response information from tracking with failure
 *
 * @note See ALTSessionFailure for details.
 */
- (void)alltrackSessionTrackingFailed:(nullable ALTSessionFailure *)sessionFailureResponseData;

/**
 * @brief Optional delegate method that gets called when a deferred deep link is about to be opened by the alltrack SDK.
 *
 * @param deeplink The deep link url that was received by the alltrack SDK to be opened.
 *
 * @return Boolean that indicates whether the deep link should be opened by the alltrack SDK or not.
 */
- (BOOL)alltrackDeeplinkResponse:(nullable NSURL *)deeplink;

/**
 * @brief Optional SKAdNetwork pre 4.0 style delegate method that gets called when Alltrack SDK sets conversion value for the user.
 *
 * @param conversionValue Conversion value used by Alltrack SDK to invoke updateConversionValue: API.
 */
- (void)alltrackConversionValueUpdated:(nullable NSNumber *)conversionValue;

/**
 * @brief Optional SKAdNetwork 4.0 style delegate method that gets called when Alltrack SDK sets conversion value for the user.
 *        You can use this callback even with using pre 4.0 SKAdNetwork.
 *        In that case you can expect coarseValue and lockWindow values to be nil.
 *
 * @param fineValue Conversion value set by Alltrack SDK.
 * @param coarseValue Coarse value set by Alltrack SDK.
 * @param lockWindow Lock window set by Alltrack SDK.
 */
- (void)alltrackConversionValueUpdated:(nullable NSNumber *)fineValue
                         coarseValue:(nullable NSString *)coarseValue
                          lockWindow:(nullable NSNumber *)lockWindow;

@end

/**
 * @brief Alltrack configuration object class.
 */
@interface ALTConfig : NSObject<NSCopying>

/**
 * @brief SDK prefix.
 *
 * @note Not to be used by users, intended for non-native alltrack SDKs only.
 */
@property (nonatomic, copy, nullable) NSString *sdkPrefix;

/**
 * @brief Default tracker to attribute organic installs to (optional).
 */
@property (nonatomic, copy, nullable) NSString *defaultTracker;

@property (nonatomic, copy, nullable) NSString *externalDeviceId;

/**
 * @brief Alltrack app token.
 */
@property (nonatomic, copy, readonly, nonnull) NSString *appToken;

/**
 * @brief Alltrack environment variable.
 */
@property (nonatomic, copy, readonly, nonnull) NSString *environment;

/**
 * @brief Change the verbosity of Alltrack's logs.
 *
 * @note You can increase or reduce the amount of logs from Alltrack by passing
 *       one of the following parameters. Use ALTLogLevelSuppress to disable all logging.
 *       The desired minimum log level (default: info)
 *       Must be one of the following:
 *         - ALTLogLevelVerbose    (enable all logging)
 *         - ALTLogLevelDebug      (enable more logging)
 *         - ALTLogLevelInfo       (the default)
 *         - ALTLogLevelWarn       (disable info logging)
 *         - ALTLogLevelError      (disable warnings as well)
 *         - ALTLogLevelAssert     (disable errors as well)
 *         - ALTLogLevelSuppress   (suppress all logging)
 */
@property (nonatomic, assign) ALTLogLevel logLevel;

/**
 * @brief Enable event buffering if your app triggers a lot of events.
 *        When enabled, events get buffered and only get tracked each
 *        minute. Buffered events are still persisted, of course.
 */
@property (nonatomic, assign) BOOL eventBufferingEnabled;

/**
 * @brief Set the optional delegate that will inform you about attribution or events.
 *
 * @note See the AlltrackDelegate declaration above for details.
 */
@property (nonatomic, weak, nullable) NSObject<AlltrackDelegate> *delegate;

/**
 * @brief Enables sending in the background.
 */
@property (nonatomic, assign) BOOL sendInBackground;

/**
 * @brief Enables/disables reading of iAd framework data needed for ASA tracking.
 */
@property (nonatomic, assign) BOOL allowiAdInfoReading;

/**
 * @brief Enables/disables reading of AdServices framework data needed for attribution.
 */
@property (nonatomic, assign) BOOL allowAdServicesInfoReading;

/**
 * @brief Enables/disables reading of IDFA parameter.
 */
@property (nonatomic, assign) BOOL allowIdfaReading;

/**
 * @brief Enables delayed start of the SDK.
 */
@property (nonatomic, assign) double delayStart;

/**
 * @brief User agent for the requests.
 */
@property (nonatomic, copy, nullable) NSString *userAgent;

/**
 * @brief Set if the device is known.
 */
@property (nonatomic, assign) BOOL isDeviceKnown;

/**
 * @brief Set if cost data is needed in attribution response.
 */
@property (nonatomic, assign) BOOL needsCost;

/**
 * @brief Alltrack app secret id.
 */
@property (nonatomic, copy, readonly, nullable) NSString *secretId;

/**
 * @brief Alltrack app secret.
 */
@property (nonatomic, copy, readonly, nullable) NSString *appSecret;

/**
 * @brief Alltrack set app secret.
 */
- (void)setAppSecret:(NSUInteger)secretId
               info1:(NSUInteger)info1
               info2:(NSUInteger)info2
               info3:(NSUInteger)info3
               info4:(NSUInteger)info4;


@property (nonatomic, assign, readonly) BOOL isSKAdNetworkHandlingActive;

- (void)deactivateSKAdNetworkHandling;

/**
 * @brief Alltrack url strategy.
 */
@property (nonatomic, copy, readwrite, nullable) NSString *urlStrategy;

/**
 * @brief Enables/disables linkMe
 */
@property (nonatomic, assign) BOOL linkMeEnabled;

/**
 * @brief Get configuration object for the initialization of the Alltrack SDK.
 *
 * @param appToken The App Token of your app. This unique identifier can
 *                 be found it in your dashboard at http://alltrack.com and should always
 *                 be 12 characters long.
 * @param environment The current environment your app. We use this environment to
 *                    distinguish between real traffic and artificial traffic from test devices.
 *                    It is very important that you keep this value meaningful at all times!
 *                    Especially if you are tracking revenue.
 *
 * @returns Alltrack configuration object.
 */
+ (nullable ALTConfig *)configWithAppToken:(nonnull NSString *)appToken
                               environment:(nonnull NSString *)environment;

- (nullable id)initWithAppToken:(nonnull NSString *)appToken
                    environment:(nonnull NSString *)environment;

/**
 * @brief Configuration object for the initialization of the Alltrack SDK.
 *
 * @param appToken The App Token of your app. This unique identifier can
 *                 be found it in your dashboard at http://alltrack.com and should always
 *                 be 12 characters long.
 * @param environment The current environment your app. We use this environment to
 *                    distinguish between real traffic and artificial traffic from test devices.
 *                    It is very important that you keep this value meaningful at all times!
 *                    Especially if you are tracking revenue.
 * @param allowSuppressLogLevel If set to true, it allows usage of ALTLogLevelSuppress
 *                              and replaces the default value for production environment.
 *
 * @returns Alltrack configuration object.
 */
+ (nullable ALTConfig *)configWithAppToken:(nonnull NSString *)appToken
                               environment:(nonnull NSString *)environment
                     allowSuppressLogLevel:(BOOL)allowSuppressLogLevel;

- (nullable id)initWithAppToken:(nonnull NSString *)appToken
                    environment:(nonnull NSString *)environment
          allowSuppressLogLevel:(BOOL)allowSuppressLogLevel;

/**
 * @brief Check if alltrack configuration object is valid.
 *
 * @return Boolean indicating whether alltrack config object is valid or not.
 */
- (BOOL)isValid;
 
/**
 * @brief Enable COPPA (Children's Online Privacy Protection Act) compliant for the application.
 */
@property (nonatomic, assign) BOOL coppaCompliantEnabled;

@end
