package io.doompal.doompal

import android.content.Context
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.sqrt

/**
 * How YOU scroll: the pause between reels, how long a swipe takes, and how many scroll events it fires.
 * Only these three timing numbers are kept (as running averages on this phone), never what you watched.
 * It is a rough guess about who is holding the phone, and is only used for the guest pass.
 */
object ScrollStyle {
    const val MIN_TRAIN = 100
    private const val RECENT = 12
    private val FLOOR = floatArrayOf(0.25f, 40f, 0.8f) // smallest "normal spread" for each number

    class Verdict(val kind: String, val score: Float, val n: Int)

    fun record(c: Context, dwellMs: Long, swipeMs: Long, events: Int) {
        if (Store.guestActive(c)) return // never learn from a guest
        val x = floatArrayOf(
            ln(1.0 + dwellMs.coerceIn(1L, 60_000L)).toFloat(),
            swipeMs.coerceIn(0L, 1500L).toFloat(),
            events.coerceIn(1, 30).toFloat()
        )
        val p = Store.prefs(c)
        val n = p.getInt("ss|n", 0)
        val e = p.edit()
        val alpha = maxOf(1f / (n + 1), 0.01f) // learns fast at first, then slowly
        for (k in 0..2) {
            val mean = p.getFloat("ss|m$k", x[k])
            val v = p.getFloat("ss|v$k", 0f)
            val delta = x[k] - mean
            val newMean = if (n == 0) x[k] else mean + alpha * delta
            val newVar = if (n == 0) 0f else (1 - alpha) * (v + alpha * delta * delta)
            e.putFloat("ss|m$k", newMean).putFloat("ss|v$k", newVar)
        }
        val recent = (p.getString("ss|recent", "") ?: "").split(";").filter { it.isNotEmpty() }.toMutableList()
        recent.add(x[0].toString() + "," + x[1] + "," + x[2])
        while (recent.size > RECENT) recent.removeAt(0)
        e.putInt("ss|n", n + 1).putString("ss|recent", recent.joinToString(";")).apply()
    }

    /** Remembers a guest's swipe in its own buffer. It never touches the owner's profile. */
    fun recordGuest(c: Context, dwellMs: Long, swipeMs: Long, events: Int) {
        val x0 = ln(1.0 + dwellMs.coerceIn(1L, 60_000L)).toFloat()
        val x1 = swipeMs.coerceIn(0L, 1500L).toFloat()
        val x2 = events.coerceIn(1, 30).toFloat()
        val p = Store.prefs(c)
        val recent = (p.getString("gs|recent", "") ?: "").split(";").filter { it.isNotEmpty() }.toMutableList()
        recent.add("$x0,$x1,$x2")
        while (recent.size > RECENT) recent.removeAt(0)
        p.edit()
            .putString("gs|recent", recent.joinToString(";"))
            .putInt("gs|n", p.getInt("gs|n", 0) + 1)
            .apply()
    }

    /** Do the swipes in [recentKey] ("ss|recent" for the owner, "gs|recent" for a guest) look like the owner? */
    fun verdict(c: Context, recentKey: String = "ss|recent"): Verdict {
        val p = Store.prefs(c)
        val n = p.getInt("ss|n", 0)
        val recent = (p.getString(recentKey, "") ?: "").split(";").filter { it.isNotEmpty() }
        if (n < MIN_TRAIN || recent.size < 8) return Verdict("unsure", 0f, n)
        val sums = FloatArray(3)
        for (r in recent) {
            val parts = r.split(",")
            if (parts.size != 3) return Verdict("unsure", 0f, n)
            for (k in 0..2) sums[k] += parts[k].toFloatOrNull() ?: 0f
        }
        var score = 0f
        for (k in 0..2) {
            val mean = sums[k] / recent.size
            val mu = p.getFloat("ss|m$k", mean)
            val sd = maxOf(sqrt(p.getFloat("ss|v$k", 0f)), FLOOR[k])
            score += abs(mean - mu) / sd
        }
        score /= 3f
        val kind = when {
            score < 0.5f -> "owner"
            score >= 0.9f -> "different"
            else -> "unsure"
        }
        return Verdict(kind, score, n)
    }

    fun summary(c: Context): HashMap<String, Any> {
        val p = Store.prefs(c)
        val n = p.getInt("ss|n", 0)
        val out = HashMap<String, Any>()
        out["n"] = n
        out["trained"] = n >= MIN_TRAIN
        val m0 = p.getFloat("ss|m0", 0f)
        out["pause"] = if (n == 0) 0.0 else (exp(m0.toDouble()) - 1.0) / 1000.0
        return out
    }
}
