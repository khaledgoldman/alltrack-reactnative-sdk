#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, ALTBackoffStrategyType) {
    ALTLongWait = 0,
    ALTShortWait = 1,
    ALTTestWait = 2,
    ALTNoWait = 3,
    ALTNoRetry = 4
};

@interface ALTBackoffStrategy : NSObject

@property (nonatomic, assign) double minRange;

@property (nonatomic, assign) double maxRange;

@property (nonatomic, assign) NSInteger minRetries;

@property (nonatomic, assign) NSTimeInterval maxWait;

@property (nonatomic, assign) NSTimeInterval secondMultiplier;

- (id) initWithType:(ALTBackoffStrategyType)strategyType;

+ (ALTBackoffStrategy *)backoffStrategyWithType:(ALTBackoffStrategyType)strategyType;

@end
