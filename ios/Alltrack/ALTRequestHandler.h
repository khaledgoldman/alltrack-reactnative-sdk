#import <Foundation/Foundation.h>
#import "ALTActivityPackage.h"
#import "ALTUrlStrategy.h"

@protocol ALTResponseCallback <NSObject>
- (void)responseCallback:(ALTResponseData *)responseData;
@end

@interface ALTRequestHandler : NSObject

- (id)initWithResponseCallback:(id<ALTResponseCallback>)responseCallback
                   urlStrategy:(ALTUrlStrategy *)urlStrategy
                     userAgent:(NSString *)userAgent
                requestTimeout:(double)requestTimeout;

- (void)sendPackageByPOST:(ALTActivityPackage *)activityPackage
        sendingParameters:(NSDictionary *)sendingParameters;

- (void)sendPackageByGET:(ALTActivityPackage *)activityPackage
        sendingParameters:(NSDictionary *)sendingParameters;

@end
