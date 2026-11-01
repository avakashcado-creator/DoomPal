package io.doompal.doompal

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.os.PowerManager
import android.provider.Settings
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var pendingPick: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // a fresh start (not a restore) may have come from another app's Share button
        if (savedInstanceState == null) handleShare(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShare(intent)
    }

    /** Pictures or stickers shared to DoomPal from another app are copied in, on this phone only. */
    private fun handleShare(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return
        val uris = ArrayList<Uri>()
        val clip = intent.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) clip.getItemAt(i).uri?.let { uris.add(it) }
        }
        if (uris.isEmpty()) intent.data?.let { uris.add(it) }
        if (uris.isEmpty()) return
        intent.action = null // handled, so a restart can't import them twice
        val app = applicationContext
        Thread {
            var added = 0
            for (u in uris) {
                if (Pictures.import(app, u)) added++
            }
            runOnUiThread {
                val msg = when (added) {
                    0 -> "DoomPal couldn't add that picture"
                    1 -> "Added 1 picture to DoomPal"
                    else -> "Added " + added + " pictures to DoomPal"
                }
                Toast.makeText(app, msg, Toast.LENGTH_LONG).show()
            }
        }.start()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "doompal/native")
            .setMethodCallHandler { call, result ->
                val ctx = this@MainActivity
                when (call.method) {
                    "isServiceEnabled" -> result.success(isServiceEnabled())
                    "isBatteryUnrestricted" -> result.success(isBatteryUnrestricted())
                    "openAccessibilitySettings" -> {
                        openSafely(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    "openBatterySettings" -> {
                        openSafely(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
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
                    "getPending" -> {
                        Store.applyDue(ctx)
                        result.success(
                            Store.pendingAll(ctx).map { (k, v, at) -> hashMapOf<String, Any>("key" to k, "value" to v, "at" to at) }
                        )
                    }
                    "cancelPending" -> {
                        val key = call.argument<String>("key")
                        if (key != null) Store.cancelPending(ctx, key)
                        result.success(null)
                    }
                    "getCoach" -> result.success(Coach.summary(ctx))
                    "getHistory" -> result.success(Store.history(ctx))
                    "getTime" -> result.success(Store.timeHistory(ctx))
                    "getSettings" -> {
                        Store.applyDue(ctx)
                        result.success(Store.allSettings(ctx))
                    }
                    "getStatus" -> result.success(Store.status(ctx))
                    "setSetting" -> {
                        val key = call.argument<String>("key")
                        val value = call.argument<Int>("value")
                        if (key != null && value != null) {
                            result.success(Restrict.request(ctx, key, value))
                        } else {
                            result.success(hashMapOf<String, Any>("status" to "applied"))
                        }
                    }
                    "getChat" -> result.success(Store.getChat(ctx))
                    "addChat" -> {
                        val who = call.argument<String>("who")
                        val text = call.argument<String>("text")
                        if (who != null && text != null) Store.chat(ctx, who, text)
                        result.success(null)
                    }
                    "listPictures" -> result.success(Pictures.list(ctx).map { it.absolutePath })
                    "pickPictures" -> startPick(result, call.argument<String>("source") == "files")
                    "removePicture" -> {
                        val path = call.argument<String>("path")
                        if (path != null) Pictures.remove(ctx, path)
                        result.success(null)
                    }
                    "clearPictures" -> {
                        Pictures.clear(ctx)
                        result.success(null)
                    }
                    "getLog" -> result.success(Store.getLog(ctx))
                    "clearLog" -> {
                        Store.clearLog(ctx)
                        result.success(null)
                    }
                    "clearHistory" -> {
                        // while the lock is on, today's numbers stay, so deleting history can't reset a limit
                        Store.clearHistory(ctx, Store.getSetting(ctx, "lock", 1) == 1)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Opens Android's own photo picker. It needs no storage permission: you choose, the app gets only those. */
    private fun startPick(result: MethodChannel.Result, files: Boolean) {
        if (pendingPick != null) {
            result.error("busy", "Already picking pictures", null)
            return
        }
        val intent = if (!files && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Intent(MediaStore.ACTION_PICK_IMAGES).apply {
                putExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, minOf(20, MediaStore.getPickImagesMaxLimit()))
            }
        } else {
            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "image/*"
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/jpeg", "image/png", "image/gif", "image/webp"))
            }
        }
        pendingPick = result
        try {
            startActivityForResult(intent, REQ_PICK)
        } catch (e: Exception) {
            pendingPick = null
            result.error("no_picker", "No photo picker found on this phone", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_PICK) return
        val result = pendingPick ?: return
        pendingPick = null
        if (resultCode != RESULT_OK || data == null) {
            result.success(0)
            return
        }
        val uris = ArrayList<Uri>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri)
        } else {
            data.data?.let { uris.add(it) }
        }
        val app = applicationContext
        Thread {
            var added = 0
            for (u in uris) {
                if (Pictures.import(app, u)) added++
            }
            runOnUiThread { result.success(added) }
        }.start()
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

    private fun isBatteryUnrestricted(): Boolean {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    companion object {
        private const val REQ_PICK = 4711
    }
}
