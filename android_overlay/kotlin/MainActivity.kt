package io.doompal.doompal

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "doompal/native")
            .setMethodCallHandler { call, result ->
                val ctx = this@MainActivity
                when (call.method) {
                    "isServiceEnabled" -> result.success(isServiceEnabled())
                    "openAccessibilitySettings" -> {
                        openSafely(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    "openAppInfo" -> {
                        openSafely(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:" + packageName)
                            )
                        )
                        result.success(null)
                    }
                    "getHistory" -> result.success(Store.history(ctx))
                    "getSettings" -> result.success(Store.allSettings(ctx))
                    "getStatus" -> result.success(Store.status(ctx))
                    "setSetting" -> {
                        val key = call.argument<String>("key")
                        val value = call.argument<Int>("value")
                        if (key != null && value != null) {
                            Store.setSetting(ctx, key, value)
                        }
                        result.success(null)
                    }
                    "getLog" -> result.success(Store.getLog(ctx))
                    "clearLog" -> {
                        Store.clearLog(ctx)
                        result.success(null)
                    }
                    "clearHistory" -> {
                        Store.clearHistory(ctx)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun openSafely(intent: Intent) {
        try {
            startActivity(intent)
        } catch (e: Exception) {
            // Fall back to the main Settings screen if a vendor removed the specific page
            try {
                startActivity(Intent(Settings.ACTION_SETTINGS))
            } catch (e2: Exception) {
                // nothing else to try
            }
        }
    }

    private fun isServiceEnabled(): Boolean {
        val enabled = Settings.Secure.getString(
            contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val me = packageName + "/"
        return enabled.split(':').any { it.startsWith(me) && it.endsWith("ReelAccessibilityService") }
    }
}
