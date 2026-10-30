package io.doompal.doompal

import android.content.Context

object Limits {
    /** Returns a message if the app is over a limit right now, otherwise null. -1 = off, 0 = block completely. */
    fun exceeded(c: Context, app: Targets.App): String? {
        val per = Store.getSetting(c, "limit:" + app.key, -1)
        if (per >= 0 && Store.count(c, app.key) >= per) {
            return if (per == 0) {
                app.label + " is blocked."
            } else {
                "You reached your " + app.label + " limit of " + per + " for today."
            }
        }
        val total = Store.getSetting(c, "total", -1)
        if (total >= 0 && Store.total(c) >= total) {
            return if (total == 0) {
                "Reels are blocked."
            } else {
                "You reached your daily limit of " + total + " reels."
            }
        }
        return null
    }
}
