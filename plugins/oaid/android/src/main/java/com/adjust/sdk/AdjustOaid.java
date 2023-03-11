package com.alltrack.oaid.nativemodule;

import com.facebook.react.bridge.*;
import com.facebook.react.modules.core.*;
import com.alltrack.sdk.oaid.*;

public class AlltrackOaid extends ReactContextBaseJavaModule {
    public AlltrackOaid(ReactApplicationContext reactContext) {
        super(reactContext);
    }

    @Override
    public String getName() {
        return "AlltrackOaid";
    }

    @Override
    public void initialize() {
    }

    @ReactMethod
    public void readOaid() {
        com.alltrack.sdk.oaid.AlltrackOaid.readOaid(getReactApplicationContext());
    }

    @ReactMethod
    public void doNotReadOaid() {
        com.alltrack.sdk.oaid.AlltrackOaid.doNotReadOaid();
    }
}
