#import <Foundation/Foundation.h>

#import "ALTActivityPackage.h"
#import "ALTPackageHandler.h"
#import "ALTActivityHandler.h"
#import "ALTResponseData.h"
#import "ALTSessionParameters.h"
#import "ALTRequestHandler.h"
#import "ALTUrlStrategy.h"

@interface ALTPackageHandler : NSObject <ALTResponseCallback>

- (id)initWithActivityHandler:(id<ALTActivityHandler>)activityHandler
                startsSending:(BOOL)startsSending
                    userAgent:(NSString *)userAgent
                  urlStrategy:(ALTUrlStrategy *)urlStrategy;
                    //extraPath:(NSString *)extraPath;

- (void)addPackage:(ALTActivityPackage *)package;
- (void)sendFirstPackage;
- (void)pauseSending;
- (void)resumeSending;
- (void)updatePackages:(ALTSessionParameters *)sessionParameters;
- (void)flush;

- (void)teardown;
+ (void)deleteState;

@end
