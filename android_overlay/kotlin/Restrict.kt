package io.doompal.doompal

import android.content.Context

/**
 * The lock. Making things stricter is instant. Making them looser has to wait out a cooldown,
 * so a weak moment can't undo a strong decision.
 */
object Restrict {
    private const val SETUP_MS = 20 * 60_000L

    /** Minutes left in the one-time setup window that starts when the terms are accepted. */
    fun setupMinsLeft(c: Context): Int {
        val at = Store.prefs(c).getLong("termsAt", 0L)
        if (at <= 0L) return 0
        val left = SETUP_MS - (System.currentTimeMillis() - at)
        return if (left <= 0L) 0 else ((left + 59_999L) / 60_000L).toInt()
    }

    private fun eff(v: Int): Int = if (v < 0) Int.MAX_VALUE else v

    private fun windowLen(start: Int, end: Int): Int = ((end - start) % 24 + 24) % 24

    private val strictWhenOn = setOf("hard", "quiet", "lock", "coach", "gate", "lenient")

    fun looser(c: Context, key: String, old: Int, new: Int): Boolean {
        if (old == new) return false
        if (key == "total" || key.startsWith("limit:") || key == "maxSnooze") return eff(new) > eff(old)
        if (key in strictWhenOn || key.startsWith("track:")) return old == 1 && new == 0
        if (key == "guest") return new == 1 && old == 0
        if (key == "begReels" || key == "guestMins" || key == "guestPerDay" || key == "gateEvery") return new > old
        if (key == "adSecs" || key == "lockHours") return new < old
        if (key == "quietStart") {
            val end = Store.getSetting(c, "quietEnd", 6)
            return windowLen(new, end) < windowLen(old, end)
        }
        if (key == "quietEnd") {
            val start = Store.getSetting(c, "quietStart", 23)
            return windowLen(start, new) < windowLen(start, old)
        }
        return false // nudge, counter, eyeBreak, debug, terms: not restrictions
    }

    fun request(c: Context, key: String, value: Int): HashMap<String, Any> {
        Store.applyDue(c)
        if (key == "terms" && value == 1 && Store.prefs(c).getLong("termsAt", 0L) == 0L) {
            Store.prefs(c).edit().putLong("termsAt", System.currentTimeMillis()).apply()
        }
        val out = HashMap<String, Any>()
        val cur = Store.getSetting(c, key, value)
        if (cur == value) {
            Store.cancelPending(c, key)
            out["status"] = "applied"
            return out
        }
        val lockOn = Store.getSetting(c, "lock", 1) == 1 && setupMinsLeft(c) == 0
        if (lockOn && looser(c, key, cur, value)) {
            val hours = Store.getSetting(c, "lockHours", 24)
            val at = System.currentTimeMillis() + hours * 3_600_000L
            Store.setPending(c, key, value, at)
            out["status"] = "queued"
            out["applyAt"] = at
            out["hours"] = hours
            return out
        }
        Store.cancelPending(c, key)
        Store.setSetting(c, key, value)
        out["status"] = "applied"
        return out
    }
}
