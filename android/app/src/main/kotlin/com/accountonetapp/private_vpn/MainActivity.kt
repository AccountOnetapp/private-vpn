package com.accountonetapp.private_vpn

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.accountonetapp.privatevpn/vpn"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "configure" -> result.success(null)
                "connect" -> {
                    if (BuildConfig.DEBUG) {
                        result.success("connected")
                    } else {
                        result.error(
                            "TRANSPORT_NOT_LINKED",
                            "Android VpnService transport is not linked in this build.",
                            null
                        )
                    }
                }
                "disconnect" -> result.success("disconnected")
                else -> result.notImplemented()
            }
        }
    }
}
