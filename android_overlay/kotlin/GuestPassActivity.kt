package io.doompal.doompal

import android.annotation.TargetApi
import android.app.Activity
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.widget.Toast

/**
 * Guest pass. Two checks, both on this phone:
 *  1. A fingerprint saved on this phone. Android only answers yes or no, it can't say whose finger it is.
 *  2. After that, Doomy watches the guest's first 10 swipes. If they scroll like the owner, the pass is
 *     cancelled and those swipes count (see ReelAccessibilityService.checkGuest).
 */
class GuestPassActivity : Activity() {
    private var signal: CancellationSignal? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val perDay = Store.getSetting(this, "guestPerDay", 1)
        if (Store.getSetting(this, "guest", 1) != 1 || Store.guestUsesToday(this) >= perDay) {
            say("no guest passes left today.")
            finish()
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            say("guest pass needs Android 9 or newer.")
            finish()
            return
        }
        startPrompt()
    }

    private fun say(text: String) {
        Toast.makeText(this, text, Toast.LENGTH_LONG).show()
    }

    @TargetApi(Build.VERSION_CODES.P)
    private fun startPrompt() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bm = getSystemService(BiometricManager::class.java)
            if (bm != null &&
                bm.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) != BiometricManager.BIOMETRIC_SUCCESS
            ) {
                say("no fingerprint is saved on this phone. add one in Android settings first.")
                finish()
                return
            }
        }
        val mins = Store.getSetting(this, "guestMins", 15)
        val executor = mainExecutor
        val cancel = CancellationSignal()
        signal = cancel
        val prompt = BiometricPrompt.Builder(this)
            .setTitle("Guest pass")
            .setSubtitle("Use a fingerprint saved on this phone")
            .setDescription("Guests get " + mins + " minutes with no limits. Doomy watches how you scroll for the first few swipes.")
            .setNegativeButton("Never mind", executor) { _, _ -> finish() }
            .build()
        prompt.authenticate(cancel, executor, object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                Store.grantGuest(this@GuestPassActivity, mins)
                Store.chat(this@GuestPassActivity, "doomy", "guest pass on for " + mins + " min. owner, i'm watching how u scroll.")
                say("guest pass on for " + mins + " minutes.")
                finish()
            }

            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                if (errorCode != BiometricPrompt.BIOMETRIC_ERROR_USER_CANCELED &&
                    errorCode != BiometricPrompt.BIOMETRIC_ERROR_CANCELED
                ) {
                    say(errString.toString())
                }
                finish()
            }
        })
    }

    override fun onDestroy() {
        signal?.cancel()
        super.onDestroy()
    }
}
