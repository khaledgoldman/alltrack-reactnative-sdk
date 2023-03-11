#import <Foundation/Foundation.h>

@interface NSString(ALTAdditions)

- (NSString *)altSha256;
- (NSString *)altTrim;
- (NSString *)altUrlEncode;
- (NSString *)altUrlDecode;

+ (NSString *)altJoin:(NSString *)strings, ...;
+ (BOOL) altIsEqual:(NSString *)first toString:(NSString *)second;

@end
