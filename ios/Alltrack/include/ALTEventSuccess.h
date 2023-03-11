#import <Foundation/Foundation.h>

@interface ALTEventSuccess : NSObject

/**
 * @brief Message from the alltrack backend.
 */
@property (nonatomic, copy) NSString *message;

/**
 * @brief Timestamp from the alltrack backend.
 */
@property (nonatomic, copy) NSString *timeStamp;

/**
 * @brief Alltrack identifier of the device.
 */
@property (nonatomic, copy) NSString *adid;

/**
 * @brief Event token value.
 */
@property (nonatomic, copy) NSString *eventToken;

/**
 * @brief Event callback ID.
 */
@property (nonatomic, copy) NSString *callbackId;

/**
 * @brief Backend response in JSON format.
 */
@property (nonatomic, strong) NSDictionary *jsonResponse;

/**
 * @brief Initialisation method.
 *
 * @return ALTEventSuccess instance.
 */
+ (ALTEventSuccess *)eventSuccessResponseData;

@end
