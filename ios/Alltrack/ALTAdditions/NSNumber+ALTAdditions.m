#import "NSNumber+ALTAdditions.h"

@implementation NSNumber(ALTAdditions)

+ (BOOL)altIsEqual:(NSNumber *)first toNumber:(NSNumber *)second {
    if (first == nil && second == nil) {
        return YES;
    }
    return [first isEqualToNumber:second];
}

@end
