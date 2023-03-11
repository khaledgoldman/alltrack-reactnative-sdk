/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 * @flow strict-local
 */

import React from 'react';
import {
  SafeAreaView,
  StyleSheet,
  ScrollView,
  View,
  Text,
  StatusBar,
  TouchableHighlight,
  Platform,
} from 'react-native';
import {
  Header,
  LearnMoreLinks,
  Colors,
  DebugInstructions,
  ReloadInstructions,
} from 'react-native/Libraries/NewAppScreen';
import {
  Alltrack,
  AlltrackEvent,
  AlltrackConfig
} from 'react-native-alltrack';
import { AlltrackOaid } from 'react-native-alltrack-oaid';

const App: () => React$Node = () => {
  Alltrack.getSdkVersion(function(sdkVersion) {
    console.log("Alltrack SDK version: " + sdkVersion);
  });

  const alltrackConfig = new AlltrackConfig("2fm9gkqubvpc", AlltrackConfig.EnvironmentSandbox);
  alltrackConfig.setLogLevel(AlltrackConfig.LogLevelVerbose);
  // alltrackConfig.setDelayStart(6.0);
  // alltrackConfig.setEventBufferingEnabled(true);
  // alltrackConfig.setUserAgent("Custom Alltrack User Agent");
  // alltrackConfig.setUrlStrategy(AlltrackConfig.UrlStrategyChina);
  // alltrackConfig.deactivateSKAdNetworkHandling();
  alltrackConfig.setNeedsCost(true);

  alltrackConfig.setAttributionCallbackListener(function(attribution) {
    console.log("Attribution callback received");
    console.log("Tracker token = " + attribution.trackerToken);
    console.log("Tracker name = " + attribution.trackerName);
    console.log("Network = " + attribution.network);
    console.log("Campaign = " + attribution.campaign);
    console.log("Adgroup = " + attribution.adgroup);
    console.log("Creative = " + attribution.creative);
    console.log("Click label = " + attribution.clickLabel);
    console.log("Adid = " + attribution.adid);
    console.log("Cost type = " + attribution.costType);
    console.log("Cost amount = " + attribution.costAmount);
    console.log("Cost currency = " + attribution.costCurrency);
  });

  alltrackConfig.setEventTrackingSucceededCallbackListener(function(eventSuccess) {
    console.log("Event tracking succeeded callback received");
    console.log("Message: " + eventSuccess.message);
    console.log("Timestamp: " + eventSuccess.timestamp);
    console.log("Adid: " + eventSuccess.adid);
    console.log("Event token: " + eventSuccess.eventToken);
    console.log("Callback Id: " + eventSuccess.callbackId);
    console.log("JSON response: " + eventSuccess.jsonResponse );
  });

  alltrackConfig.setEventTrackingFailedCallbackListener(function(eventFailed) {
    console.log("Event tracking failed callback received");
    console.log("Message: " + eventFailed.message);
    console.log("Timestamp: " + eventFailed.timestamp);
    console.log("Adid: " + eventFailed.adid);
    console.log("Event token: " + eventFailed.eventToken);
    console.log("Callback Id: " + eventFailed.callbackId);
    console.log("Will retry: " + eventFailed.willRetry);
    console.log("JSON response: " + eventFailed.jsonResponse);
  });

  alltrackConfig.setSessionTrackingSucceededCallbackListener(function(sessionSuccess) {
    console.log("Session tracking succeeded callback received");
    console.log("Message: " + sessionSuccess.message);
    console.log("Timestamp: " + sessionSuccess.timestamp);
    console.log("Adid: " + sessionSuccess.adid);
    console.log("JSON response: " + sessionSuccess.jsonResponse);
  });

  alltrackConfig.setSessionTrackingFailedCallbackListener(function(sessionFailed) {
    console.log("Session tracking failed callback received");
    console.log("Message: " + sessionFailed.message);
    console.log("Timestamp: " + sessionFailed.timestamp);
    console.log("Adid: " + sessionFailed.adid);
    console.log("Will retry: " + sessionFailed.willRetry);
    console.log("JSON response: " + sessionFailed.jsonResponse);
  });

  alltrackConfig.setDeferredDeeplinkCallbackListener(function(uri) {
    console.log("Deferred Deeplink Callback received");
    console.log("URL: " + uri.uri);
  });

  alltrackConfig.setConversionValueUpdatedCallbackListener(function(conversionValue) {
    console.log("Conversion value updated callback recveived");
    console.log("Conversion value: " + conversionValue.conversionValue);
  });

  Alltrack.addSessionCallbackParameter("scpk1", "scpv1");
  Alltrack.addSessionCallbackParameter("scpk2", "scpv2");

  Alltrack.addSessionPartnerParameter("sppk1", "sppv1");
  Alltrack.addSessionPartnerParameter("sppk2", "sppv2");

  Alltrack.removeSessionCallbackParameter("scpk1");
  Alltrack.removeSessionPartnerParameter("sppk2");

  // Alltrack.resetSessionCallbackParameters();
  // Alltrack.resetSessionPartnerParameters();

  Alltrack.requestTrackingAuthorizationWithCompletionHandler(function(status) {
    console.log("Authorization status update");
    switch (status) {
        case 0:
            // ATTrackingManagerAuthorizationStatusNotDetermined case
            console.log("Authorization status: ATTrackingManagerAuthorizationStatusNotDetermined");
            break;
        case 1:
            // ATTrackingManagerAuthorizationStatusRestricted case
            console.log("Authorization status: ATTrackingManagerAuthorizationStatusRestricted");
            break;
        case 2:
            // ATTrackingManagerAuthorizationStatusDenied case
            console.log("Authorization status: ATTrackingManagerAuthorizationStatusDenied");
            break;
        case 3:
            // ATTrackingManagerAuthorizationStatusAuthorized case
            console.log("Authorization status: ATTrackingManagerAuthorizationStatusAuthorized");
            break;
    }
  });

  if (Platform.OS === "android") {
    AlltrackOaid.readOaid();
  }
  Alltrack.create(alltrackConfig);

  function componentDidMount() {
    Linking.addEventListener('url', this.handleDeepLink);
    Linking.getInitialURL().then((url) => {
      if (url) {
        this.handleDeepLink({ url });
      }
    })
  }

  function componentWillUnmount() {
    Alltrack.componentWillUnmount();
    Linking.removeEventListener('url', this.handleDeepLink);
  }

  function handleDeepLink(e) {
    Alltrack.appWillOpenUrl(e.url);
  }

  function _onPress_trackSimpleEvent() {
    var alltrackEvent = new AlltrackEvent("g3mfiw");
    Alltrack.trackEvent(alltrackEvent);
    Alltrack.updateConversionValue(6);
    Alltrack.getAppTrackingAuthorizationStatus(function(status) {
      console.log("Authorization status = " + status);
    });
  }

  function _onPress_trackRevenueEvent() {
    var alltrackEvent = new AlltrackEvent("a4fd35");
    alltrackEvent.setRevenue(10.0, "USD");
    alltrackEvent.setTransactionId("DUMMY_TRANSACTION_ID");
    Alltrack.trackEvent(alltrackEvent);
  }

  function _onPress_trackCallbackEvent() {
    var alltrackEvent = new AlltrackEvent("34vgg9");
    alltrackEvent.addCallbackParameter("DUMMY_KEY_1", "DUMMY_VALUE_1");
    alltrackEvent.addCallbackParameter("DUMMY_KEY_2", "DUMMY_VALUE_2");
    Alltrack.trackEvent(alltrackEvent);
  }

  function _onPress_trackPartnerEvent() {
    var alltrackEvent = new AlltrackEvent("w788qs");
    alltrackEvent.addPartnerParameter("DUMMY_KEY_1", "DUMMY_VALUE_1");
    alltrackEvent.addPartnerParameter("DUMMY_KEY_2", "DUMMY_VALUE_2");
    Alltrack.trackEvent(alltrackEvent);
  }

  function _onPress_enableOfflineMode() {
    Alltrack.setOfflineMode(true);
  }

  function _onPress_disableOfflineMode() {
    Alltrack.setOfflineMode(false);
  }

  function _onPress_enableSdk() {
    Alltrack.setEnabled(true);
  }

  function _onPress_disableSdk() {
    Alltrack.setEnabled(false);
  }

  function _onPress_getIds() {
    Alltrack.getAdid((adid) => {
      console.log("Adid = " + adid);
    });

    Alltrack.getIdfa((idfa) => {
      console.log("IDFA = " + idfa);
    });

    Alltrack.getGoogleAdId((googleAdId) => {
      console.log("Google Ad Id = " + googleAdId);
    });

    Alltrack.getAmazonAdId((amazonAdId) => {
      console.log("Amazon Ad Id = " + amazonAdId);
    });

    Alltrack.getAttribution((attribution) => {
      console.log("Attribution:");
      console.log("Tracker token = " + attribution.trackerToken);
      console.log("Tracker name = " + attribution.trackerName);
      console.log("Network = " + attribution.network);
      console.log("Campaign = " + attribution.campaign);
      console.log("Adgroup = " + attribution.adgroup);
      console.log("Creative = " + attribution.creative);
      console.log("Click label = " + attribution.clickLabel);
      console.log("Adid = " + attribution.adid);
    });
  }

  function _onPress_isSdkEnabled() {
    Alltrack.isEnabled( (isEnabled) => {
      if (isEnabled) {
        console.log("SDK is enabled");
      } else {
        console.log("SDK is disabled");
      }
    });
  }

  return (
    <>
      <View style={styles.container}>
        <TouchableHighlight
          style={styles.button}
          onPress={_onPress_trackSimpleEvent}>
          <Text>Track Simple Event</Text>
        </TouchableHighlight>
        <TouchableHighlight
          style={styles.button}
          onPress={_onPress_trackRevenueEvent}>
          <Text>Track Revenue Event</Text>
        </TouchableHighlight>
        <TouchableHighlight
          style={styles.button}
          onPress={_onPress_trackCallbackEvent}>
          <Text>Track Callback Event</Text>
        </TouchableHighlight>
        <TouchableHighlight
          style={styles.button}
          onPress={_onPress_trackPartnerEvent}>
          <Text>Track Partner Event</Text>
        </TouchableHighlight>
        <TouchableHighlight
          style={styles.button}
          onPress={_onPress_enableOfflineMode}>
          <Text>Enable Offline Mode</Text>
        </TouchableHighlight>
        <TouchableHighlight
          style={styles.button}
          onPress={_onPress_disableOfflineMode}>
          <Text>Disable Offline Mode</Text>
        </TouchableHighlight>
        <TouchableHighlight
          style={styles.button}
          onPress={_onPress_enableSdk}>
          <Text>Enable SDK</Text>
        </TouchableHighlight>
        <TouchableHighlight
          style={styles.button}
          onPress={_onPress_disableSdk}>
          <Text>Disable SDK</Text>
        </TouchableHighlight>
        <TouchableHighlight
          style={styles.button}
          onPress={_onPress_getIds}>
          <Text>Get Ids</Text>
        </TouchableHighlight>
        <TouchableHighlight
          style={styles.button}
          onPress={_onPress_isSdkEnabled}>
          <Text>is SDK Enabled?</Text>
        </TouchableHighlight>
      </View>
    </>
  );
};

const styles = StyleSheet.create({
  scrollView: {
    backgroundColor: Colors.lighter,
  },
  engine: {
    position: 'absolute',
    right: 0,
  },
  body: {
    backgroundColor: Colors.white,
  },
  sectionContainer: {
    marginTop: 32,
    paddingHorizontal: 24,
  },
  sectionTitle: {
    fontSize: 24,
    fontWeight: '600',
    color: Colors.black,
  },
  sectionDescription: {
    marginTop: 8,
    fontSize: 18,
    fontWeight: '400',
    color: Colors.dark,
  },
  highlight: {
    fontWeight: '700',
  },
  footer: {
    color: Colors.dark,
    fontSize: 12,
    fontWeight: '600',
    padding: 4,
    paddingRight: 12,
    textAlign: 'right',
  },
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F5FCFF',
  },
  button: {
    alignItems: 'center',
    backgroundColor: '#61D4FB',
    padding: 10,
    width: '60%',
    height: 40,
    margin: 10,
  },
});

export default App;
