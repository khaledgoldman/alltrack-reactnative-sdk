'use strict';

import { 
    NativeEventEmitter,
    NativeModules,
    Platform,
} from 'react-native';

const module_alltrack = NativeModules.Alltrack;

let module_alltrack_emitter = null;
if (Platform.OS === "android") {
    module_alltrack_emitter = new NativeEventEmitter(NativeModules.Alltrack);
} else if (Platform.OS === "ios") {
    module_alltrack_emitter = new NativeEventEmitter(NativeModules.AlltrackEventEmitter);
}

// Alltrack

var Alltrack = {};

Alltrack.create = function(alltrackConfig) {
    module_alltrack.create(alltrackConfig);
};

Alltrack.trackEvent = function(alltrackEvent) {
    module_alltrack.trackEvent(alltrackEvent);
};

Alltrack.setEnabled = function(enabled) {
    module_alltrack.setEnabled(enabled);
};

Alltrack.isEnabled = function(callback) {
    module_alltrack.isEnabled(callback);
};

Alltrack.setOfflineMode = function(enabled) {
    module_alltrack.setOfflineMode(enabled);
};

Alltrack.setPushToken = function(token) {
    module_alltrack.setPushToken(token);
};

Alltrack.appWillOpenUrl = function(uri) {
    module_alltrack.appWillOpenUrl(uri);
};

Alltrack.sendFirstPackages = function() {
    module_alltrack.sendFirstPackages();
};

Alltrack.trackAdRevenue = function(source, payload = undefined) {
    if (payload === undefined) {
        // new API
        module_alltrack.trackAdRevenueNew(source);
    } else {
        // old API
        module_alltrack.trackAdRevenue(source, payload);
    }
};

Alltrack.trackAppStoreSubscription = function(subscription) {
    if (Platform.OS === "ios") {
        module_alltrack.trackAppStoreSubscription(subscription);
    }
};

Alltrack.trackPlayStoreSubscription = function(subscription) {
    if (Platform.OS === "android") {
        module_alltrack.trackPlayStoreSubscription(subscription);
    }
};

Alltrack.addSessionCallbackParameter = function(key, value) {
    if (typeof key !== 'string' || typeof value !== 'string') {
        return;
    }
    module_alltrack.addSessionCallbackParameter(key, value);
};

Alltrack.addSessionPartnerParameter = function(key, value) {
    if (typeof key !== 'string' || typeof value !== 'string') {
        return;
    }
    module_alltrack.addSessionPartnerParameter(key, value);
};

Alltrack.removeSessionCallbackParameter = function(key) {
    module_alltrack.removeSessionCallbackParameter(key);
};

Alltrack.removeSessionPartnerParameter = function(key) {
    module_alltrack.removeSessionPartnerParameter(key);
};

Alltrack.resetSessionCallbackParameters = function() {
    module_alltrack.resetSessionCallbackParameters();
};

Alltrack.resetSessionPartnerParameters = function() {
    module_alltrack.resetSessionPartnerParameters();
};

Alltrack.gdprForgetMe = function() {
    module_alltrack.gdprForgetMe();
};

Alltrack.disableThirdPartySharing = function() {
    module_alltrack.disableThirdPartySharing();
};

Alltrack.getIdfa = function(callback) {
    module_alltrack.getIdfa(callback);
};

Alltrack.getGoogleAdId = function(callback) {
    module_alltrack.getGoogleAdId(callback);
};

Alltrack.getAdid = function(callback) {
    module_alltrack.getAdid(callback);
};

Alltrack.getAttribution = function(callback) {
    module_alltrack.getAttribution(callback);
};

Alltrack.getAmazonAdId = function(callback) {
    module_alltrack.getAmazonAdId(callback);
};

Alltrack.getSdkVersion = function(callback) {
    module_alltrack.getSdkVersion("react-native0.0.1", callback);
};

Alltrack.setReferrer = function(referrer) {
    if (Platform.OS === "android") {
        module_alltrack.setReferrer(referrer);
    }
};

Alltrack.convertUniversalLink = function(url, scheme, callback) {
    if (!url || !scheme || !callback) {
        return;
    }
    module_alltrack.convertUniversalLink(url, scheme, callback);
};

Alltrack.requestTrackingAuthorizationWithCompletionHandler = function(callback) {
    module_alltrack.requestTrackingAuthorizationWithCompletionHandler(callback);
};

Alltrack.updateConversionValue = function(conversionValue) {
    module_alltrack.updateConversionValue(conversionValue);
};

Alltrack.updateConversionValueWithErrorCallback = function(conversionValue, callback) {
    module_alltrack.updateConversionValueWithErrorCallback(conversionValue, callback);
};

Alltrack.updateConversionValueWithSkad4ErrorCallback = function(conversionValue, coarseValue, lockWindow, callback) {
    module_alltrack.updateConversionValueWithSkad4ErrorCallback(conversionValue, coarseValue, lockWindow, callback);
};

Alltrack.getAppTrackingAuthorizationStatus = function(callback) {
    module_alltrack.getAppTrackingAuthorizationStatus(callback);
};

Alltrack.trackThirdPartySharing = function(alltrackThirdPartySharing) {
    module_alltrack.trackThirdPartySharing(alltrackThirdPartySharing);
};

Alltrack.trackMeasurementConsent = function(measurementConsent) {
    module_alltrack.trackMeasurementConsent(measurementConsent);
};

Alltrack.checkForNewAttStatus = function() {
    module_alltrack.checkForNewAttStatus();
};

Alltrack.getLastDeeplink = function(callback) {
    module_alltrack.getLastDeeplink(callback);
};

Alltrack.componentWillUnmount = function() {
    if (AlltrackConfig.AttributionSubscription != null) {
        AlltrackConfig.AttributionSubscription.remove();
        AlltrackConfig.AttributionSubscription = null;
    }

    if (AlltrackConfig.EventTrackingSucceededSubscription != null) {
        AlltrackConfig.EventTrackingSucceededSubscription.remove();
        AlltrackConfig.EventTrackingSucceededSubscription = null;
    }

    if (AlltrackConfig.EventTrackingFailedSubscription != null) {
        AlltrackConfig.EventTrackingFailedSubscription.remove();
        AlltrackConfig.EventTrackingFailedSubscription = null;
    }

    if (AlltrackConfig.SessionTrackingSucceededSubscription != null) {
        AlltrackConfig.SessionTrackingSucceededSubscription.remove();
        AlltrackConfig.SessionTrackingSucceededSubscription = null;
    }

    if (AlltrackConfig.SessionTrackingFailedSubscription != null) {
        AlltrackConfig.SessionTrackingFailedSubscription.remove();
        AlltrackConfig.SessionTrackingFailedSubscription = null;
    }

    if (AlltrackConfig.DeferredDeeplinkSubscription != null) {
        AlltrackConfig.DeferredDeeplinkSubscription.remove();
        AlltrackConfig.DeferredDeeplinkSubscription = null;
    }
};

// =========================================== //
// Alltrack methods used for SDK testing only.   //
// Do NOT use any of these in production code. //
// =========================================== //

Alltrack.teardown = function(testParam) {
    if (testParam === null || testParam === undefined || testParam !== 'test') {
        return;
    }
    Alltrack.componentWillUnmount();
    module_alltrack.teardown();
};

Alltrack.setTestOptions = function(testOptions) {
    module_alltrack.setTestOptions(testOptions);
};

Alltrack.onResume = function(testParam) {
    if (testParam === null || testParam === undefined || testParam !== 'test') {
        return;
    }
    module_alltrack.onResume();
};

Alltrack.onPause = function(testParam) {
    if (testParam === null || testParam === undefined || testParam !== 'test') {
        return;
    }
    module_alltrack.onPause();
};

// AlltrackConfig

var AlltrackConfig = function(appToken, environment) {
    this.sdkPrefix = "react-native0.0.1";
    this.appToken = appToken;
    this.environment = environment;
    this.logLevel = null;
    this.eventBufferingEnabled = null;
    this.shouldLaunchDeeplink = null;
    this.sendInBackground = null;
    this.needsCost = null;
    this.delayStart = null;
    this.userAgent = null;
    this.isDeviceKnown = null;
    this.defaultTracker = null;
    this.externalDeviceId = null;
    this.secretId = null;
    this.info1 = null;
    this.info2 = null;
    this.info3 = null;
    this.info4 = null;
    this.urlStrategy = null;
    this.coppaCompliantEnabled = null;
    // Android only
    this.processName = null;
    this.readMobileEquipmentIdentity = null;
    this.preinstallTrackingEnabled = null;
    this.preinstallFilePath = null;
    this.playStoreKidsAppEnabled = null;
    // iOS only
    this.allowiAdInfoReading = null;
    this.allowAdServicesInfoReading = null;
    this.allowIdfaReading = null;
    this.skAdNetworkHandling = null;
    this.linkMeEnabled = null;
};

AlltrackConfig.EnvironmentSandbox = "sandbox";
AlltrackConfig.EnvironmentProduction = "production";

AlltrackConfig.LogLevelVerbose = "VERBOSE";
AlltrackConfig.LogLevelDebug = "DEBUG";
AlltrackConfig.LogLevelInfo = "INFO";
AlltrackConfig.LogLevelWarn = "WARN";
AlltrackConfig.LogLevelError = "ERROR";
AlltrackConfig.LogLevelAssert = "ASSERT";
AlltrackConfig.LogLevelSuppress = "SUPPRESS";

AlltrackConfig.AttributionSubscription = null;
AlltrackConfig.EventTrackingSucceededSubscription = null;
AlltrackConfig.EventTrackingFailedSubscription = null;
AlltrackConfig.SessionTrackingSucceededSubscription = null;
AlltrackConfig.SessionTrackingFailedSubscription = null;
AlltrackConfig.DeferredDeeplinkSubscription = null;
AlltrackConfig.ConversionValueUpdatedSubscription = null;
AlltrackConfig.Skad4ConversionValueUpdatedSubscription = null;

AlltrackConfig.UrlStrategyChina = "china";
AlltrackConfig.UrlStrategyIndia = "india";
AlltrackConfig.UrlStrategyCn = "cn";

AlltrackConfig.DataResidencyEU = "data-residency-eu";
AlltrackConfig.DataResidencyTR = "data-residency-tr";
AlltrackConfig.DataResidencyUS = "data-residency-us";

AlltrackConfig.AdRevenueSourceAppLovinMAX = "applovin_max_sdk";
AlltrackConfig.AdRevenueSourceMopub = "mopub";
AlltrackConfig.AdRevenueSourceAdmob = "admob_sdk";
AlltrackConfig.AdRevenueSourceIronSource = "ironsource_sdk";
AlltrackConfig.AdRevenueSourceAdmost = "admost_sdk";
AlltrackConfig.AdRevenueSourcePublisher = "publisher_sdk";

AlltrackConfig.prototype.setEventBufferingEnabled = function(isEnabled) {
    this.eventBufferingEnabled = isEnabled;
};

AlltrackConfig.prototype.setLogLevel = function(logLevel) {
    this.logLevel = logLevel;
};

AlltrackConfig.prototype.setProcessName = function(processName) {
    this.processName = processName;
};

AlltrackConfig.prototype.setDefaultTracker = function(defaultTracker) {
    this.defaultTracker = defaultTracker;
};

AlltrackConfig.prototype.setExternalDeviceId = function(externalDeviceId) {
    this.externalDeviceId = externalDeviceId;
};

AlltrackConfig.prototype.setUserAgent = function(userAgent) {
    this.userAgent = userAgent;
};

AlltrackConfig.prototype.setAppSecret = function(secretId, info1, info2, info3, info4) {
    if (secretId != null) {
        this.secretId = secretId.toString();
    }
    if (info1 != null) {
        this.info1 = info1.toString();
    }
    if (info2 != null) {
        this.info2 = info2.toString();
    }
    if (info3 != null) {
        this.info3 = info3.toString();
    }
    if (info4 != null) {
        this.info4 = info4.toString();
    }
};

AlltrackConfig.prototype.setDelayStart = function(delayStart) {
    this.delayStart = delayStart;
};

AlltrackConfig.prototype.setSendInBackground = function(sendInBackground) {
    this.sendInBackground = sendInBackground;
};

AlltrackConfig.prototype.setDeviceKnown = function(isDeviceKnown) {
    this.isDeviceKnown = isDeviceKnown;
};

AlltrackConfig.prototype.setNeedsCost = function(needsCost) {
    this.needsCost = needsCost;
};

AlltrackConfig.prototype.setSdkPrefix = function(sdkPrefix) {
    this.sdkPrefix = sdkPrefix;
};

AlltrackConfig.prototype.setUrlStrategy = function(urlStrategy) {
    this.urlStrategy = urlStrategy;
};

AlltrackConfig.prototype.setCoppaCompliantEnabled = function(coppaCompliantEnabled) {
    this.coppaCompliantEnabled = coppaCompliantEnabled;
};

AlltrackConfig.prototype.setReadMobileEquipmentIdentity = function(readMobileEquipmentIdentity) {
    // this.readMobileEquipmentIdentity = readMobileEquipmentIdentity;
};

AlltrackConfig.prototype.setPreinstallTrackingEnabled = function(isEnabled) {
    this.preinstallTrackingEnabled = isEnabled;
};

AlltrackConfig.prototype.setPreinstallFilePath = function(preinstallFilePath) {
    this.preinstallFilePath = preinstallFilePath;
};

AlltrackConfig.prototype.setPlayStoreKidsAppEnabled = function(isEnabled) {
    this.playStoreKidsAppEnabled = isEnabled;
};

AlltrackConfig.prototype.setAllowiAdInfoReading = function(allowiAdInfoReading) {
    this.allowiAdInfoReading = allowiAdInfoReading;
};

AlltrackConfig.prototype.setAllowAdServicesInfoReading = function(allowAdServicesInfoReading) {
    this.allowAdServicesInfoReading = allowAdServicesInfoReading;
};

AlltrackConfig.prototype.setAllowIdfaReading = function(allowIdfaReading) {
    this.allowIdfaReading = allowIdfaReading;
};

AlltrackConfig.prototype.setShouldLaunchDeeplink = function(shouldLaunchDeeplink) {
    this.shouldLaunchDeeplink = shouldLaunchDeeplink;
};

AlltrackConfig.prototype.deactivateSKAdNetworkHandling = function() {
    this.skAdNetworkHandling = false;
};

AlltrackConfig.prototype.setLinkMeEnabled = function(linkMeEnabled) {
    this.linkMeEnabled = linkMeEnabled;
};

AlltrackConfig.prototype.setAttributionCallbackListener = function(attributionCallbackListener) {
    if (null == AlltrackConfig.AttributionSubscription) {
        module_alltrack.setAttributionCallbackListener();
        AlltrackConfig.AttributionSubscription = module_alltrack_emitter.addListener(
            'alltrack_attribution', attributionCallbackListener
        );
    }
};

AlltrackConfig.prototype.setEventTrackingSucceededCallbackListener = function(eventTrackingSucceededCallbackListener) {
    if (null == AlltrackConfig.EventTrackingSucceededSubscription) {
        module_alltrack.setEventTrackingSucceededCallbackListener();
        AlltrackConfig.EventTrackingSucceededSubscription = module_alltrack_emitter.addListener(
            'alltrack_eventTrackingSucceeded', eventTrackingSucceededCallbackListener
        );
    }
};

AlltrackConfig.prototype.setEventTrackingFailedCallbackListener = function(eventTrackingFailedCallbackListener) {
    if (null == AlltrackConfig.EventTrackingFailedSubscription) {
        module_alltrack.setEventTrackingFailedCallbackListener();
        AlltrackConfig.EventTrackingFailedSubscription = module_alltrack_emitter.addListener(
            'alltrack_eventTrackingFailed', eventTrackingFailedCallbackListener
        );
    }
};

AlltrackConfig.prototype.setSessionTrackingSucceededCallbackListener = function(sessionTrackingSucceededCallbackListener) {
    if (null == AlltrackConfig.SessionTrackingSucceededSubscription) {
        module_alltrack.setSessionTrackingSucceededCallbackListener();
        AlltrackConfig.SessionTrackingSucceededSubscription = module_alltrack_emitter.addListener(
            'alltrack_sessionTrackingSucceeded', sessionTrackingSucceededCallbackListener
        );
    }
};

AlltrackConfig.prototype.setSessionTrackingFailedCallbackListener = function(sessionTrackingFailedCallbackListener) {
    if (null == AlltrackConfig.SessionTrackingFailedSubscription) {
        module_alltrack.setSessionTrackingFailedCallbackListener();
        AlltrackConfig.SessionTrackingFailedSubscription = module_alltrack_emitter.addListener(
            'alltrack_sessionTrackingFailed', sessionTrackingFailedCallbackListener
        );
    }
};

AlltrackConfig.prototype.setDeferredDeeplinkCallbackListener = function(deferredDeeplinkCallbackListener) {
    if (null == AlltrackConfig.DeferredDeeplinkSubscription) {
        module_alltrack.setDeferredDeeplinkCallbackListener();
        AlltrackConfig.DeferredDeeplinkSubscription = module_alltrack_emitter.addListener(
            'alltrack_deferredDeeplink', deferredDeeplinkCallbackListener
        );
    }
};

AlltrackConfig.prototype.setConversionValueUpdatedCallbackListener = function(conversionValueUpdatedCallbackListener) {
    if (Platform.OS === "ios") {
        if (null == AlltrackConfig.ConversionValueUpdatedSubscription) {
            module_alltrack.setConversionValueUpdatedCallbackListener();
            AlltrackConfig.ConversionValueUpdatedSubscription = module_alltrack_emitter.addListener(
                'alltrack_conversionValueUpdated', conversionValueUpdatedCallbackListener
            );
        }
    }
};

AlltrackConfig.prototype.setSkad4ConversionValueUpdatedCallbackListener = function(skad4ConversionValueUpdatedCallbackListener) {
    if (Platform.OS === "ios") {
        if (null == AlltrackConfig.Skad4ConversionValueUpdatedSubscription) {
            module_alltrack.setSkad4ConversionValueUpdatedCallbackListener();
            AlltrackConfig.Skad4ConversionValueUpdatedSubscription = module_alltrack_emitter.addListener(
                'alltrack_skad4ConversionValueUpdated', skad4ConversionValueUpdatedCallbackListener
            );
        }
    }
};

// AlltrackEvent

var AlltrackEvent = function(eventToken) {
    this.eventToken = eventToken;
    this.revenue = null;
    this.currency = null;
    this.transactionId = null;
    this.callbackId = null;
    this.callbackParameters = {};
    this.partnerParameters = {};
};

AlltrackEvent.prototype.setRevenue = function(revenue, currency) {
    if (revenue != null) {
        this.revenue = revenue.toString();
        this.currency = currency;
    }
};

AlltrackEvent.prototype.addCallbackParameter = function(key, value) {
    if (typeof key !== 'string' || typeof value !== 'string') {
        return;
    }
    this.callbackParameters[key] = value;
};

AlltrackEvent.prototype.addPartnerParameter = function(key, value) {
    if (typeof key !== 'string' || typeof value !== 'string') {
        return;
    }
    this.partnerParameters[key] = value;
};

AlltrackEvent.prototype.setTransactionId = function(transactionId) {
    this.transactionId = transactionId;
};

AlltrackEvent.prototype.setCallbackId = function(callbackId) {
    this.callbackId = callbackId;
};

// AlltrackAppStoreSubscription

var AlltrackAppStoreSubscription = function(price, currency, transactionId, receipt) {
    this.price = price;
    this.currency = currency;
    this.transactionId = transactionId;
    this.receipt = receipt;
    this.transactionDate = null;
    this.salesRegion = null;
    this.callbackParameters = {};
    this.partnerParameters = {};
};

AlltrackAppStoreSubscription.prototype.setTransactionDate = function(transactionDate) {
    this.transactionDate = transactionDate;
};

AlltrackAppStoreSubscription.prototype.setSalesRegion = function(salesRegion) {
    this.salesRegion = salesRegion;
};

AlltrackAppStoreSubscription.prototype.addCallbackParameter = function(key, value) {
    if (typeof key !== 'string' || typeof value !== 'string') {
        return;
    }
    this.callbackParameters[key] = value;
};

AlltrackAppStoreSubscription.prototype.addPartnerParameter = function(key, value) {
    if (typeof key !== 'string' || typeof value !== 'string') {
        return;
    }
    this.partnerParameters[key] = value;
};

// AlltrackPlayStoreSubscription

var AlltrackPlayStoreSubscription = function(price, currency, sku, orderId, signature, purchaseToken) {
    this.price = price;
    this.currency = currency;
    this.sku = sku;
    this.orderId = orderId;
    this.signature = signature;
    this.purchaseToken = purchaseToken;
    this.purchaseTime = null;
    this.callbackParameters = {};
    this.partnerParameters = {};
};

AlltrackPlayStoreSubscription.prototype.setPurchaseTime = function(purchaseTime) {
    this.purchaseTime = purchaseTime;
};

AlltrackPlayStoreSubscription.prototype.addCallbackParameter = function(key, value) {
    if (typeof key !== 'string' || typeof value !== 'string') {
        return;
    }
    this.callbackParameters[key] = value;
};

AlltrackPlayStoreSubscription.prototype.addPartnerParameter = function(key, value) {
    if (typeof key !== 'string' || typeof value !== 'string') {
        return;
    }
    this.partnerParameters[key] = value;
};

// AlltrackThirdPartySharing

var AlltrackThirdPartySharing = function(isEnabled) {
    this.isEnabled = isEnabled;
    this.granularOptions = [];
    this.partnerSharingSettings = [];
};

AlltrackThirdPartySharing.prototype.addGranularOption = function(partnerName, key, value) {
    if (typeof partnerName !== 'string' || typeof key !== 'string' || typeof value !== 'string') {
        return;
    }
    this.granularOptions.push(partnerName);
    this.granularOptions.push(key);
    this.granularOptions.push(value);
};

AlltrackThirdPartySharing.prototype.addPartnerSharingSetting = function(partnerName, key, value) {
    if (typeof partnerName !== 'string' || typeof key !== 'string' || typeof value !== 'boolean') {
        return;
    }
    this.partnerSharingSettings.push(partnerName);
    this.partnerSharingSettings.push(key);
    this.partnerSharingSettings.push(value);
};

// AlltrackAdRevenue

var AlltrackAdRevenue = function(source) {
    this.source = source;
    this.revenue = null;
    this.currency = null;
    this.adImpressionsCount = null;
    this.adRevenueNetwork = null;
    this.adRevenueUnit = null;
    this.adRevenuePlacement = null;
    this.callbackParameters = {};
    this.partnerParameters = {};
};

AlltrackAdRevenue.prototype.setRevenue = function(revenue, currency) {
    if (revenue != null) {
        this.revenue = revenue.toString();
        this.currency = currency;
    }
};

AlltrackAdRevenue.prototype.setAdImpressionsCount = function(adImpressionsCount) {
    this.adImpressionsCount = adImpressionsCount.toString();
};

AlltrackAdRevenue.prototype.setAdRevenueNetwork = function(adRevenueNetwork) {
    this.adRevenueNetwork = adRevenueNetwork;
};

AlltrackAdRevenue.prototype.setAdRevenueUnit = function(adRevenueUnit) {
    this.adRevenueUnit = adRevenueUnit;
};

AlltrackAdRevenue.prototype.setAdRevenuePlacement = function(adRevenuePlacement) {
    this.adRevenuePlacement = adRevenuePlacement;
};

AlltrackAdRevenue.prototype.addCallbackParameter = function(key, value) {
    if (typeof key !== 'string' || typeof value !== 'string') {
        return;
    }
    this.callbackParameters[key] = value;
};

AlltrackAdRevenue.prototype.addPartnerParameter = function(key, value) {
    if (typeof key !== 'string' || typeof value !== 'string') {
        return;
    }
    this.partnerParameters[key] = value;
};

module.exports = {
    Alltrack,
    AlltrackEvent,
    AlltrackConfig,
    AlltrackAppStoreSubscription,
    AlltrackPlayStoreSubscription,
    AlltrackThirdPartySharing,
    AlltrackAdRevenue
}
