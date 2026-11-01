package io.doompal.doompal

import android.content.Context
import java.util.Calendar

object Limits {
    fun pad(hour: Int): String = (if (hour < 10) "0" else "") + hour + ":00"

    fun duration(secs: Int): String {
        if (secs < 60) return "under a minute"
        val m = (secs + 30) / 60
        if (m < 60) return m.toString() + " min"
        val h = m / 60
        val r = m % 60
        return if (r == 0) h.toString() + " h" else h.toString() + " h " + r + " min"
    }

    fun inQuietHours(c: Context): Boolean {
        if (Store.getSetting(c, "quiet", 0) != 1) return false
        val start = Store.getSetting(c, "quietStart", 23)
        val end = Store.getSetting(c, "quietEnd", 6)
        if (start == end) return false
        val h = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        return if (start < end) (h >= start && h < end) else (h >= start || h < end)
    }

    /** Returns a message if the app is blocked right now, otherwise null. -1 = off, 0 = block completely. */
    fun exceeded(c: Context, app: Targets.App): String? {
        if (inQuietHours(c)) {
            val s = Store.getSetting(c, "quietStart", 23)
            val e = Store.getSetting(c, "quietEnd", 6)
            return "Quiet hours (" + pad(s) + " to " + pad(e) + "): " + app.noun + " are blocked."
        }
        val bonus = Store.bonusToday(c)
        val per = Store.getSetting(c, "limit:" + app.key, -1)
        if (per >= 0 && Store.count(c, app.key) >= per + bonus) {
            return if (per == 0) {
                app.label + " is blocked."
            } else {
                "You reached your " + app.label + " limit of " + per + " for today."
            }
        }
        val total = Store.getSetting(c, "total", -1)
        if (total >= 0 && Store.total(c) >= total + bonus) {
            return if (total == 0) {
                "Reels are blocked."
            } else {
                "You reached your daily limit of " + total + " reels."
            }
        }
        return null
    }
}

/** The limit that applies to an app right now (including begged bonus reels), or -1 if none. */
fun Limits.limitFor(c: Context, app: Targets.App): Int {
    val bonus = Store.bonusToday(c)
    val per = Store.getSetting(c, "limit:" + app.key, -1)
    val total = Store.getSetting(c, "total", -1)
    return when {
        per >= 0 -> per + bonus
        total >= 0 -> total + bonus
        else -> -1
    }
}
