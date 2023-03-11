'use strict';

import { 
    NativeEventEmitter,
    NativeModules,
    Platform,
} from 'react-native';

const module_alltrack_oaid = NativeModules.AlltrackOaid;

// AlltrackOaid

var AlltrackOaid = {};

AlltrackOaid.readOaid = function() {
    if (Platform.OS === "android") {
        module_alltrack_oaid.readOaid();
    }
};

AlltrackOaid.doNotReadOaid = function() {
    if (Platform.OS === "android") {
        module_alltrack_oaid.doNotReadOaid();
    }
};

module.exports = { AlltrackOaid }
