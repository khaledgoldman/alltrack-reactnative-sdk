#import <Foundation/Foundation.h>

typedef enum {
    ALTLogLevelVerbose  = 1,
    ALTLogLevelDebug    = 2,
    ALTLogLevelInfo     = 3,
    ALTLogLevelWarn     = 4,
    ALTLogLevelError    = 5,
    ALTLogLevelAssert   = 6,
    ALTLogLevelSuppress = 7
} ALTLogLevel;

/**
 * @brief Alltrack logger protocol.
 */
@protocol ALTLogger

/**
 * @brief Set the log level of the SDK.
 *
 * @param logLevel Level of the logs to be displayed.
 */
- (void)setLogLevel:(ALTLogLevel)logLevel isProductionEnvironment:(BOOL)isProductionEnvironment;

/**
 * @brief Prevent log level changes.
 */
- (void)lockLogLevel;

/**
 * @brief Print verbose logs.
 */
- (void)verbose:(nonnull NSString *)message, ...;

/**
 * @brief Print debug logs.
 */
- (void)debug:(nonnull NSString *)message, ...;

/**
 * @brief Print info logs.
 */
- (void)info:(nonnull NSString *)message, ...;

/**
 * @brief Print warn logs.
 */
- (void)warn:(nonnull NSString *)message, ...;
- (void)warnInProduction:(nonnull NSString *)message, ...;

/**
 * @brief Print error logs.
 */
- (void)error:(nonnull NSString *)message, ...;

/**
 * @brief Print assert logs.
 */
- (void)assert:(nonnull NSString *)message, ...;

@end

/**
 * @brief Alltrack logger class.
 */
@interface ALTLogger : NSObject<ALTLogger>

/**
 * @brief Convert log level string to ALTLogLevel enumeration.
 *
 * @param logLevelString Log level as string.
 *
 * @return Log level as ALTLogLevel enumeration.
 */
+ (ALTLogLevel)logLevelFromString:(nonnull NSString *)logLevelString;

@end
