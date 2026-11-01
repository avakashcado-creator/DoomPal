package io.doompal.doompal

import android.content.Context
import java.util.Calendar

/**
 * Doomy's coach. It learns from your own history on this phone, with simple counting, no cloud and no
 * neural network. Once a day it looks at the last 7 days and decides how strict to be:
 *  - hit your limit on 4+ days, or begged 5+ times: tighten limits by 10% (up to 50%), longer ads, fewer begs
 *  - 5+ days of data, almost never near the limit, no begging: relax a step back toward YOUR limit
 * It can never be looser than the limit you set. It also learns which hours you scroll most.
 */
object Coach {
    private fun pad2(n: Int): String = (if (n < 10) "0" else "") + n

    fun updateIfNeeded(c: Context) {
        if (Store.prefs(c).getString("co|day", "") != Store.today()) update(c)
    }

    fun update(c: Context) {
        val p = Store.prefs(c)
        val e = p.edit()
        e.putString("co|day", Store.today())

        // hours you scroll most (last 14 days)
        val sums = IntArray(24)
        for (i in 0..13) {
            val d = Store.dateKey(i)
            for (h in 0..23) sums[h] += p.getInt("h|" + d + "|" + pad2(h), 0)
        }
        var mask = 0
        if (sums.sum() >= 40) {
            val top = (0..23).sortedByDescending { sums[it] }.take(3).filter { sums[it] > 0 }
            for (h in top) mask = mask or (1 shl h)
        }
        e.putInt("co|risk", mask)

        if (Store.getSetting(c, "coach", 1) != 1) {
            e.putInt("co|pct", 0).putInt("co|ad", 0).putInt("co|beg", 0)
            e.putString("co|note", "off|The coach is off, so Doomy only uses the limits you set.")
            e.apply()
            return
        }

        val hist = Store.history(c)
        val totalBase = Store.getSetting(c, "total", 50)
        var hitDays = 0
        var dataDays = 0
        var begs = 0
        for (i in 1..7) {
            val d = Store.dateKey(i)
            val day = hist[d] ?: HashMap()
            var sum = 0
            var any = false
            var appHit = false
            for (a in Targets.all) {
                if (!Store.isTracked(c, a)) continue
                val n = day[a.key] ?: 0
                sum += n
                if (n > 0) any = true
                val lim = Store.getSetting(c, "limit:" + a.key, -1)
                if (lim > 0 && n >= lim * 0.9) appHit = true
            }
            if (any) dataDays++
            if (appHit || (totalBase > 0 && sum >= totalBase * 0.9)) hitDays++
            begs += p.getInt("z|" + d, 0)
        }

        var pct = p.getInt("co|pct", 0)
        var ad = p.getInt("co|ad", 0)
        var cut = p.getInt("co|beg", 0)
        val note: String
        if (hitDays >= 4 || begs >= 5) {
            pct = minOf(50, pct + 10)
            ad = minOf(30, ad + 5)
            if (begs >= 5) cut = 1
            note = "tight|Tightened to " + pct + "% stricter. You hit your limit on " + hitDays +
                " of the last 7 days and begged " + begs + " times."
        } else if (dataDays >= 5 && hitDays <= 1 && begs == 0) {
            pct = maxOf(0, pct - 10)
            ad = maxOf(0, ad - 5)
            cut = 0
            note = "relax|Easing off toward your own limit. You stayed well under it, with no begging."
        } else {
            note = "hold|Holding steady. Keep it up and Doomy eases off, or slip and he tightens."
        }
        e.putInt("co|pct", pct).putInt("co|ad", ad).putInt("co|beg", cut).putString("co|note", note)
        e.apply()
    }

    fun isRiskHour(c: Context): Boolean {
        val mask = Store.prefs(c).getInt("co|risk", 0)
        val h = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        return (mask shr h) and 1 == 1
    }

    fun riskHours(c: Context): List<Int> {
        val mask = Store.prefs(c).getInt("co|risk", 0)
        return (0..23).filter { (mask shr it) and 1 == 1 }
    }

    /** Everything the Rules screen shows about what Doomy has learned. */
    fun summary(c: Context): HashMap<String, Any> {
        updateIfNeeded(c)
        val p = Store.prefs(c)
        val out = HashMap<String, Any>()
        out["pct"] = p.getInt("co|pct", 0)
        out["ad"] = p.getInt("co|ad", 0)
        out["beg"] = p.getInt("co|beg", 0)
        out["risk"] = riskHours(c)
        out["note"] = p.getString("co|note", "hold|Doomy is still getting to know you.") ?: ""
        val style = ScrollStyle.summary(c)
        out["swipes"] = style["n"] ?: 0
        out["pause"] = style["pause"] ?: 0.0
        out["trained"] = style["trained"] ?: false
        out["minTrain"] = ScrollStyle.MIN_TRAIN
        return out
    }
}
