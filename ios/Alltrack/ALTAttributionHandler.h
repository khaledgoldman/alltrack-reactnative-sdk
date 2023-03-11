#import <Foundation/Foundation.h>
#import "ALTActivityHandler.h"
#import "ALTActivityPackage.h"
#import "ALTRequestHandler.h"
#import "ALTUrlStrategy.h"

@interface ALTAttributionHandler : NSObject <ALTResponseCallback>

- (id)initWithActivityHandler:(id<ALTActivityHandler>) activityHandler
                startsSending:(BOOL)startsSending
                    userAgent:(NSString *)userAgent
                  urlStrategy:(ALTUrlStrategy *)urlStrategy;

- (void)checkSessionResponse:(ALTSessionResponseData *)sessionResponseData;

- (void)checkSdkClickResponse:(ALTSdkClickResponseData *)sdkClickResponseData;

- (void)checkAttributionResponse:(ALTAttributionResponseData *)attributionResponseData;

- (void)getAttribution;

- (void)pauseSending;

- (void)resumeSending;

- (void)teardown;

@end
