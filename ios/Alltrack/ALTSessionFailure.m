#import "ALTSessionFailure.h"

@implementation ALTSessionFailure

#pragma mark - Object lifecycle methods

- (id)init {
    self = [super init];

    if (self == nil) {
        return nil;
    }

    return self;
}

+ (ALTSessionFailure *)sessionFailureResponseData {
    return [[ALTSessionFailure alloc] init];
}

#pragma mark - NSCopying protocol methods

- (id)copyWithZone:(NSZone *)zone {
    ALTSessionFailure *copy = [[[self class] allocWithZone:zone] init];

    if (copy) {
        copy.message = [self.message copyWithZone:zone];
        copy.timeStamp = [self.timeStamp copyWithZone:zone];
        copy.adid = [self.adid copyWithZone:zone];
        copy.willRetry = self.willRetry;
        copy.jsonResponse = [self.jsonResponse copyWithZone:zone];
    }

    return copy;
}

#pragma mark - NSObject protocol methods

- (NSString *)description {
    return [NSString stringWithFormat: @"Session Failure msg:%@ time:%@ adid:%@ retry:%@ json:%@",
            self.message,
            self.timeStamp,
            self.adid,
            self.willRetry ? @"YES" : @"NO",
            self.jsonResponse];
}

@end
