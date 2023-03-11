#import "ALTLogger.h"

static NSString * const kLogTag = @"Alltrack";

@interface ALTLogger()

@property (nonatomic, assign) ALTLogLevel loglevel;
@property (nonatomic, assign) BOOL logLevelLocked;
@property (nonatomic, assign) BOOL isProductionEnvironment;

@end

#pragma mark -
@implementation ALTLogger

- (id)init {
    self = [super init];
    if (self == nil) return nil;

    //default values
    _loglevel = ALTLogLevelInfo;
    self.logLevelLocked = NO;
    self.isProductionEnvironment = NO;

    return self;
}

- (void)setLogLevel:(ALTLogLevel)logLevel
isProductionEnvironment:(BOOL)isProductionEnvironment
{
    if (self.logLevelLocked) {
        return;
    }
    _loglevel = logLevel;
    self.isProductionEnvironment = isProductionEnvironment;
}

- (void)lockLogLevel {
    self.logLevelLocked = YES;
}

- (void)verbose:(NSString *)format, ... {
    if (self.isProductionEnvironment) return;
    if (self.loglevel > ALTLogLevelVerbose) return;
    va_list parameters; va_start(parameters, format);
    [self logLevel:@"v" format:format parameters:parameters];
}

- (void)debug:(NSString *)format, ... {
    if (self.isProductionEnvironment) return;
    if (self.loglevel > ALTLogLevelDebug) return;
    va_list parameters; va_start(parameters, format);
    [self logLevel:@"d" format:format parameters:parameters];
}

- (void)info:(NSString *)format, ... {
    if (self.isProductionEnvironment) return;
    if (self.loglevel > ALTLogLevelInfo) return;
    va_list parameters; va_start(parameters, format);
    [self logLevel:@"i" format:format parameters:parameters];
}

- (void)warn:(NSString *)format, ... {
    if (self.isProductionEnvironment) return;
    if (self.loglevel > ALTLogLevelWarn) return;
    va_list parameters; va_start(parameters, format);
    [self logLevel:@"w" format:format parameters:parameters];
}
- (void)warnInProduction:(nonnull NSString *)format, ... {
    if (self.loglevel > ALTLogLevelWarn) return;
    va_list parameters; va_start(parameters, format);
    [self logLevel:@"w" format:format parameters:parameters];
}

- (void)error:(NSString *)format, ... {
    if (self.isProductionEnvironment) return;
    if (self.loglevel > ALTLogLevelError) return;
    va_list parameters; va_start(parameters, format);
    [self logLevel:@"e" format:format parameters:parameters];
}

- (void)assert:(NSString *)format, ... {
    if (self.isProductionEnvironment) return;
    if (self.loglevel > ALTLogLevelAssert) return;
    va_list parameters; va_start(parameters, format);
    [self logLevel:@"a" format:format parameters:parameters];
}

// private implementation
- (void)logLevel:(NSString *)logLevel format:(NSString *)format parameters:(va_list)parameters {
    NSString *string = [[NSString alloc] initWithFormat:format arguments:parameters];
    va_end(parameters);

    NSArray *lines = [string componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        NSLog(@"\t[%@]%@: %@", kLogTag, logLevel, line);
    }
}

+ (ALTLogLevel)logLevelFromString:(NSString *)logLevelString {
    if ([logLevelString isEqualToString:@"verbose"])
        return ALTLogLevelVerbose;

    if ([logLevelString isEqualToString:@"debug"])
        return ALTLogLevelDebug;

    if ([logLevelString isEqualToString:@"info"])
        return ALTLogLevelInfo;

    if ([logLevelString isEqualToString:@"warn"])
        return ALTLogLevelWarn;

    if ([logLevelString isEqualToString:@"error"])
        return ALTLogLevelError;

    if ([logLevelString isEqualToString:@"assert"])
        return ALTLogLevelAssert;

    if ([logLevelString isEqualToString:@"suppress"])
        return ALTLogLevelSuppress;

    // default value if string does not match
    return ALTLogLevelInfo;
}

@end
