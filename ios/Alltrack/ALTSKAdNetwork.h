#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ALTSKAdNetwork : NSObject

+ (nullable instancetype)getInstance;

- (void)registerAppForAdNetworkAttribution;

- (void)updateConversionValue:(NSInteger)conversionValue;

- (void)updatePostbackConversionValue:(NSInteger)conversionValue
                    completionHandler:(void (^)(NSError *error))completion;

- (void)updatePostbackConversionValue:(NSInteger)fineValue
                          coarseValue:(NSString *)coarseValue
                    completionHandler:(void (^)(NSError *error))completion;

- (void)updatePostbackConversionValue:(NSInteger)fineValue
                          coarseValue:(NSString *)coarseValue
                           lockWindow:(BOOL)lockWindow
                    completionHandler:(void (^)(NSError *error))completion;

- (void)altRegisterWithCompletionHandler:(void (^)(NSError *error))callback;

- (void)altUpdateConversionValue:(NSInteger)conversionValue
                     coarseValue:(NSString *)coarseValue
                      lockWindow:(NSNumber *)lockWindow
               completionHandler:(void (^)(NSError *error))callback;

@end

NS_ASSUME_NONNULL_END
