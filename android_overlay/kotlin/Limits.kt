package io.doompal.doompal

import android.content.Context
import java.util.Calendar
import kotlin.math.roundToInt

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
        if (Store.getSetting(c, "quiet", 1) != 1) return false
        val start = Store.getSetting(c, "quietStart", 23)
        val end = Store.getSetting(c, "quietEnd", 6)
        if (start == end) return false
        val h = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        return if (start < end) (h >= start && h < end) else (h >= start || h < end)
    }

    /** The limit you set, tightened by the coach if it has been needed. Never looser than you set it. */
    fun effective(c: Context, key: String): Int {
        val base = Store.getSetting(c, key, -1)
        if (base <= 0) return base
        if (Store.getSetting(c, "coach", 1) != 1) return base
        val pct = Store.prefs(c).getInt("co|pct", 0)
        if (pct <= 0) return base
        val cut = (base * (100 - pct) / 100.0).roundToInt()
        return cut.coerceAtLeast(3).coerceAtMost(base)
    }

    /** Begs per day, after the coach. -1 = unlimited. */
    fun begsPerDay(c: Context): Int {
        val base = Store.getSetting(c, "maxSnooze", 1)
        if (base < 0) return -1
        if (Store.getSetting(c, "coach", 1) != 1) return base
        return (base - Store.prefs(c).getInt("co|beg", 0)).coerceAtLeast(0)
    }

    /** Seconds the joke ad lasts for the first beg of the day. */
    fun adSeconds(c: Context): Int {
        val base = Store.getSetting(c, "adSecs", 10)
        if (Store.getSetting(c, "coach", 1) != 1) return base
        return base + Store.prefs(c).getInt("co|ad", 0)
    }

    /** The limit shown to you right now for an app (including bonus reels you won), or -1 if none. */
    fun limitFor(c: Context, app: Targets.App): Int {
        val bonus = Store.bonusToday(c)
        val per = effective(c, "limit:" + app.key)
        val total = effective(c, "total")
        return when {
            per >= 0 -> per + bonus
            total >= 0 -> total + bonus
            else -> -1
        }
    }

    /** Returns a message if the app is blocked right now, otherwise null. -1 = off, 0 = block completely. */
    fun exceeded(c: Context, app: Targets.App): String? {
        if (Store.guestActive(c)) return null
        if (inQuietHours(c)) {
            val s = Store.getSetting(c, "quietStart", 23)
            val e = Store.getSetting(c, "quietEnd", 6)
            return "Quiet hours (" + pad(s) + " to " + pad(e) + "): " + app.noun + " are blocked."
        }
        val bonus = Store.bonusToday(c)
        val per = effective(c, "limit:" + app.key)
        if (per >= 0 && Store.count(c, app.key) >= per + bonus) {
            return if (per == 0) {
                app.label + " is blocked."
            } else {
                "You reached your " + app.label + " limit of " + per + " for today."
            }
        }
        val total = effective(c, "total")
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
