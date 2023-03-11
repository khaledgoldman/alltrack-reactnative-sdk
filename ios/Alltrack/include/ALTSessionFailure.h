#import <Foundation/Foundation.h>

@interface ALTSessionFailure : NSObject <NSCopying>

/**
 * @brief Message from the alltrack backend.
 */
@property (nonatomic, copy, nullable) NSString *message;

/**
 * @brief Timestamp from the alltrack backend.
 */
@property (nonatomic, copy, nullable) NSString *timeStamp;

/**
 * @brief Alltrack identifier of the device.
 */
@property (nonatomic, copy, nullable) NSString *adid;

/**
 * @brief Information whether sending of the package will be retried or not.
 */
@property (nonatomic, assign) BOOL willRetry;

/**
 * @brief Backend response in JSON format.
 */
@property (nonatomic, strong, nullable) NSDictionary *jsonResponse;

/**
 * @brief Initialisation method.
 *
 * @return ALTSessionFailure instance.
 */
+ (nullable ALTSessionFailure *)sessionFailureResponseData;

@end
