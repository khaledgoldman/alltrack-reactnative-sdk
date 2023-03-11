#import <Foundation/Foundation.h>
#import "ALTActivityKind.h"

@interface ALTUrlStrategy : NSObject

@property (nonatomic, readonly, copy) NSString *extraPath;

- (instancetype)initWithUrlStrategyInfo:(NSString *)urlStrategyInfo
                              extraPath:(NSString *)extraPath;

- (NSString *)getUrlHostStringByPackageKind:(ALTActivityKind)activityKind;

- (void)resetAfterSuccess;
- (BOOL)shouldRetryAfterFailure:(ALTActivityKind)activityKind;

@end
