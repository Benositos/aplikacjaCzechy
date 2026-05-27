package com.calma.calma

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

/// FlutterFragmentActivity (not FlutterActivity) — extends FragmentActivity
/// which extends ComponentActivity, giving us `registerForActivityResult`
/// needed by Health Connect's permission contract.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        HealthChannel(activity = this, messenger = messenger).register()
        UsageChannel(activity = this, messenger = messenger).register()
    }
}
