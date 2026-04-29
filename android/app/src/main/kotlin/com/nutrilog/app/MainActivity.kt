package com.nutrilog.app

import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"com.nutrilog/app_info"
		).setMethodCallHandler { call, result ->
			if (call.method == "getSdkInt") {
				result.success(Build.VERSION.SDK_INT)
			} else {
				result.notImplemented()
			}
		}
	}
}
