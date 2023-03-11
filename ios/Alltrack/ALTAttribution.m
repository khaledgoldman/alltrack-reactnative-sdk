#import "ALTUtil.h"
#import "ALTAttribution.h"
#import "NSString+ALTAdditions.h"
#import "NSNumber+ALTAdditions.h"

@implementation ALTAttribution

+ (ALTAttribution *)dataWithJsonDict:(NSDictionary *)jsonDict
                                adid:(NSString *)adid {
    return [[ALTAttribution alloc] initWithJsonDict:jsonDict adid:adid];
}

- (id)initWithJsonDict:(NSDictionary *)jsonDict
                  adid:(NSString *)adid {
    self = [super init];
    if (self == nil) {
        return nil;
    }
    if ([ALTUtil isNull:jsonDict]) {
        return nil;
    }

    self.trackerToken = [jsonDict objectForKey:@"tracker_token"];
    self.trackerName = [jsonDict objectForKey:@"tracker_name"];
    self.network = [jsonDict objectForKey:@"network"];
    self.campaign = [jsonDict objectForKey:@"campaign"];
    self.adgroup = [jsonDict objectForKey:@"adgroup"];
    self.creative = [jsonDict objectForKey:@"creative"];
    self.clickLabel = [jsonDict objectForKey:@"click_label"];
    self.adid = adid;
    self.costType = [jsonDict objectForKey:@"cost_type"];
    self.costAmount = [jsonDict objectForKey:@"cost_amount"];
    self.costCurrency = [jsonDict objectForKey:@"cost_currency"];

    return self;
}

- (BOOL)isEqualToAttribution:(ALTAttribution *)attribution {
    if (attribution == nil) {
        return NO;
    }
    if (![NSString altIsEqual:self.trackerToken toString:attribution.trackerToken]) {
        return NO;
    }
    if (![NSString altIsEqual:self.trackerName toString:attribution.trackerName]) {
        return NO;
    }
    if (![NSString altIsEqual:self.network toString:attribution.network]) {
        return NO;
    }
    if (![NSString altIsEqual:self.campaign toString:attribution.campaign]) {
        return NO;
    }
    if (![NSString altIsEqual:self.adgroup toString:attribution.adgroup]) {
        return NO;
    }
    if (![NSString altIsEqual:self.creative toString:attribution.creative]) {
        return NO;
    }
    if (![NSString altIsEqual:self.clickLabel toString:attribution.clickLabel]) {
        return NO;
    }
    if (![NSString altIsEqual:self.adid toString:attribution.adid]) {
        return NO;
    }
    if (![NSString altIsEqual:self.costType toString:attribution.costType]) {
        return NO;
    }
    if (![NSNumber altIsEqual:self.costAmount toNumber:attribution.costAmount]) {
        return NO;
    }
    if (![NSString altIsEqual:self.costCurrency toString:attribution.costCurrency]) {
        return NO;
    }

    return YES;
}

- (NSDictionary *)dictionary {
    NSMutableDictionary *responseDataDic = [NSMutableDictionary dictionary];

    if (self.trackerToken != nil) {
        [responseDataDic setObject:self.trackerToken forKey:@"trackerToken"];
    }
    if (self.trackerName != nil) {
        [responseDataDic setObject:self.trackerName forKey:@"trackerName"];
    }
    if (self.network != nil) {
        [responseDataDic setObject:self.network forKey:@"network"];
    }
    if (self.campaign != nil) {
        [responseDataDic setObject:self.campaign forKey:@"campaign"];
    }
    if (self.adgroup != nil) {
        [responseDataDic setObject:self.adgroup forKey:@"adgroup"];
    }
    if (self.creative != nil) {
        [responseDataDic setObject:self.creative forKey:@"creative"];
    }
    if (self.clickLabel != nil) {
        [responseDataDic setObject:self.clickLabel forKey:@"click_label"];
    }
    if (self.adid != nil) {
        [responseDataDic setObject:self.adid forKey:@"adid"];
    }
    if (self.costType != nil) {
        [responseDataDic setObject:self.costType forKey:@"costType"];
    }
    if (self.costAmount != nil) {
        [responseDataDic setObject:[self.costAmount stringValue] forKey:@"costAmount"];
    }
    if (self.costCurrency != nil) {
        [responseDataDic setObject:self.costCurrency forKey:@"costCurrency"];
    }

    return responseDataDic;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"tt:%@ tn:%@ net:%@ cam:%@ adg:%@ cre:%@ cl:%@ adid:%@ ct:%@ ca:%@ cc:%@",
            self.trackerToken, self.trackerName, self.network, self.campaign,
            self.adgroup, self.creative, self.clickLabel, self.adid, self.costType,
            self.costAmount, self.costCurrency];
}


#pragma mark - NSObject
- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[ALTAttribution class]]) {
        return NO;
    }

    return [self isEqualToAttribution:(ALTAttribution *)object];
}

- (NSUInteger)hash {
    return [self.trackerName hash];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    ALTAttribution *copy = [[[self class] allocWithZone:zone] init];

    if (copy) {
        copy.trackerToken = [self.trackerToken copyWithZone:zone];
        copy.trackerName = [self.trackerName copyWithZone:zone];
        copy.network = [self.network copyWithZone:zone];
        copy.campaign = [self.campaign copyWithZone:zone];
        copy.adgroup = [self.adgroup copyWithZone:zone];
        copy.creative = [self.creative copyWithZone:zone];
        copy.clickLabel = [self.clickLabel copyWithZone:zone];
        copy.adid = [self.adid copyWithZone:zone];
        copy.costType = [self.costType copyWithZone:zone];
        copy.costAmount = [self.costAmount copyWithZone:zone];
        copy.costCurrency = [self.costCurrency copyWithZone:zone];
    }

    return copy;
}


#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    self.trackerToken = [decoder decodeObjectForKey:@"trackerToken"];
    self.trackerName = [decoder decodeObjectForKey:@"trackerName"];
    self.network = [decoder decodeObjectForKey:@"network"];
    self.campaign = [decoder decodeObjectForKey:@"campaign"];
    self.adgroup = [decoder decodeObjectForKey:@"adgroup"];
    self.creative = [decoder decodeObjectForKey:@"creative"];
    self.clickLabel = [decoder decodeObjectForKey:@"click_label"];
    self.adid = [decoder decodeObjectForKey:@"adid"];
    self.costType = [decoder decodeObjectForKey:@"costType"];
    self.costAmount = [decoder decodeObjectForKey:@"costAmount"];
    self.costCurrency = [decoder decodeObjectForKey:@"costCurrency"];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.trackerToken forKey:@"trackerToken"];
    [encoder encodeObject:self.trackerName forKey:@"trackerName"];
    [encoder encodeObject:self.network forKey:@"network"];
    [encoder encodeObject:self.campaign forKey:@"campaign"];
    [encoder encodeObject:self.adgroup forKey:@"adgroup"];
    [encoder encodeObject:self.creative forKey:@"creative"];
    [encoder encodeObject:self.clickLabel forKey:@"click_label"];
    [encoder encodeObject:self.adid forKey:@"adid"];
    [encoder encodeObject:self.costType forKey:@"costType"];
    [encoder encodeObject:self.costAmount forKey:@"costAmount"];
    [encoder encodeObject:self.costCurrency forKey:@"costCurrency"];
}

@end
