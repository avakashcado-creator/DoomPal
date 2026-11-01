package io.doompal.doompal

import android.content.Context
import android.content.SharedPreferences
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/** All data lives in SharedPreferences on the phone. Nothing is ever sent anywhere. */
object Store {
    private const val MAX_GAP_MS = 120_000L // longer than this between two reels = a new session
    private const val FIRST_REEL_SECS = 20  // guess for the first reel of a session
    private const val EYE_BREAK_MS = 20 * 60_000L

    fun prefs(c: Context): SharedPreferences = c.getSharedPreferences("doompal", Context.MODE_PRIVATE)

    fun dateKey(daysAgo: Int): String {
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_YEAR, -daysAgo)
        return SimpleDateFormat("yyyy-MM-dd", Locale.US).format(cal.time)
    }

    fun today(): String = dateKey(0)

    private fun pad2(n: Int): String = (if (n < 10) "0" else "") + n

    // ---- counts "c|date|app", estimated seconds "t|date|app", hourly "h|date|HH" ----
    fun increment(c: Context, app: String): Int {
        val p = prefs(c)
        val now = System.currentTimeMillis()
        val day = today()
        val ck = "c|" + day + "|" + app
        val tk = "t|" + day + "|" + app
        val hk = "h|" + day + "|" + pad2(Calendar.getInstance().get(Calendar.HOUR_OF_DAY))
        val n = p.getInt(ck, 0) + 1
        val lastApp = p.getString("lastApp", "") ?: ""
        val lastTime = p.getLong("lastTime", 0L)
        val gap = now - lastTime
        val addSecs = if (lastApp == app && gap in 1L..MAX_GAP_MS) (gap / 1000L).toInt() else FIRST_REEL_SECS
        val e = p.edit()
            .putInt(ck, n)
            .putInt(tk, p.getInt(tk, 0) + addSecs)
            .putInt(hk, p.getInt(hk, 0) + 1)
            .putString("lastApp", app)
            .putLong("lastTime", now)
        if (lastTime == 0L || gap > MAX_GAP_MS) {
            e.putLong("sessionStart", now).putLong("eyeLast", now)
        }
        e.apply()
        return n
    }

    /** True once per 20 minutes of continuous scrolling. Calling it again starts the next 20. */
    fun eyeBreakDue(c: Context, now: Long): Boolean {
        val p = prefs(c)
        val last = p.getLong("eyeLast", now)
        if (now - last < EYE_BREAK_MS) return false
        p.edit().putLong("eyeLast", now).apply()
        return true
    }

    fun count(c: Context, app: String): Int = prefs(c).getInt("c|" + today() + "|" + app, 0)

    fun total(c: Context): Int {
        var sum = 0
        for (a in Targets.all) if (isTracked(c, a)) sum += count(c, a.key)
        return sum
    }

    fun seconds(c: Context, app: String): Int = prefs(c).getInt("t|" + today() + "|" + app, 0)

    fun totalSeconds(c: Context): Int {
        var sum = 0
        for (a in Targets.all) if (isTracked(c, a)) sum += seconds(c, a.key)
        return sum
    }

    private fun grouped(c: Context, prefix: String): HashMap<String, HashMap<String, Int>> {
        val out = HashMap<String, HashMap<String, Int>>()
        for ((k, v) in prefs(c).all) {
            if (!k.startsWith(prefix) || v !is Int) continue
            val parts = k.split("|")
            if (parts.size != 3) continue
            val day = out.getOrPut(parts[1]) { HashMap() }
            day[parts[2]] = v
        }
        return out
    }

    fun history(c: Context): HashMap<String, HashMap<String, Int>> = grouped(c, "c|")
    fun timeHistory(c: Context): HashMap<String, HashMap<String, Int>> = grouped(c, "t|")

    /** With keepToday, today's numbers stay, so deleting history can never be used to reset a limit. */
    fun clearHistory(c: Context, keepToday: Boolean) {
        val p = prefs(c)
        val e = p.edit()
        val today = today()
        for (k in p.all.keys) {
            val isData = k.startsWith("c|") || k.startsWith("t|") || k.startsWith("z|") ||
                k.startsWith("b|") || k.startsWith("h|") || k.startsWith("gu|")
            if (!isData) continue
            if (keepToday && k.split("|").getOrNull(1) == today) continue
            e.remove(k)
        }
        if (!keepToday) e.remove("lastApp").remove("lastTime")
        e.remove("chat").apply()
    }

    // ---- begs ("snoozes") and bonus reels won by begging, per day ----
    fun snoozesToday(c: Context): Int = prefs(c).getInt("z|" + today(), 0)

    fun addSnooze(c: Context) {
        val k = "z|" + today()
        val p = prefs(c)
        p.edit().putInt(k, p.getInt(k, 0) + 1).apply()
    }

    fun bonusToday(c: Context): Int = prefs(c).getInt("b|" + today(), 0)

    fun addBonus(c: Context, n: Int) {
        val k = "b|" + today()
        val p = prefs(c)
        p.edit().putInt(k, p.getInt(k, 0) + n).apply()
    }

    // ---- when Doomy last checked on you ----
    fun lastGate(c: Context): Long = prefs(c).getLong("lastGate", 0L)

    fun setLastGate(c: Context, t: Long) {
        prefs(c).edit().putLong("lastGate", t).apply()
    }

    // ---- guest pass ----
    fun guestUntil(c: Context): Long = prefs(c).getLong("guestUntil", 0L)
    fun guestActive(c: Context): Boolean = System.currentTimeMillis() < guestUntil(c)
    fun guestUsesToday(c: Context): Int = prefs(c).getInt("gu|" + today(), 0)

    /** Starts a guest pass. Doomy then watches the guest's first swipes to see if they scroll like the owner. */
    fun grantGuest(c: Context, mins: Int) {
        val p = prefs(c)
        val k = "gu|" + today()
        p.edit()
            .putLong("guestUntil", System.currentTimeMillis() + mins * 60_000L)
            .putInt(k, p.getInt(k, 0) + 1)
            .putInt("gs|n", 0)
            .putInt("gs|done", 0)
            .putString("gs|recent", "")
            .apply()
    }

    fun revokeGuest(c: Context) {
        prefs(c).edit().putLong("guestUntil", 0L).apply()
    }

    // ---- chat with Doomy: "time<TAB>who<TAB>text" lines, newest last, last 80 kept ----
    fun chat(c: Context, who: String, text: String) {
        val clean = text.replace("\n", " ").replace("\t", " ")
        val p = prefs(c)
        val cur = p.getString("chat", "") ?: ""
        val lines = cur.split("\n").filter { it.isNotEmpty() } +
            (System.currentTimeMillis().toString() + "\t" + who + "\t" + clean)
        p.edit().putString("chat", lines.takeLast(80).joinToString("\n")).apply()
    }

    fun getChat(c: Context): String = prefs(c).getString("chat", "") ?: ""

    /** Small status map for the Today screen. */
    fun status(c: Context): HashMap<String, Any> {
        val p = prefs(c)
        val out = HashMap<String, Any>()
        out["lastApp"] = p.getString("lastApp", "") ?: ""
        out["lastTime"] = p.getLong("lastTime", 0L)
        out["snoozeUntil"] = p.getLong("snoozeUntil", 0L)
        out["snoozesToday"] = snoozesToday(c)
        out["bonusToday"] = bonusToday(c)
        out["guestUntil"] = guestUntil(c)
        out["guestUsesToday"] = guestUsesToday(c)
        return out
    }

    // ---- settings: key "s|name" (ints only), with restrictive defaults ----
    fun getSetting(c: Context, key: String, def: Int): Int =
        prefs(c).getInt("s|" + key, Defaults.of(key) ?: def)

    fun setSetting(c: Context, key: String, value: Int) {
        prefs(c).edit().putInt("s|" + key, value).apply()
    }

    /** Every setting with its current value, plus "eff:..." limits (what is really enforced right now). */
    fun allSettings(c: Context): HashMap<String, Int> {
        val out = HashMap<String, Int>()
        for ((k, v) in Defaults.all()) out[k] = v
        for ((k, v) in prefs(c).all) {
            if (k.startsWith("s|") && v is Int) out[k.substring(2)] = v
        }
        out["setupMinsLeft"] = Restrict.setupMinsLeft(c)
        out["eff:total"] = Limits.effective(c, "total")
        for (a in Targets.all) out["eff:limit:" + a.key] = Limits.effective(c, "limit:" + a.key)
        return out
    }

    fun isTracked(c: Context, app: Targets.App): Boolean =
        getSetting(c, "track:" + app.key, if (app.defaultOn) 1 else 0) == 1

    // ---- changes waiting out the lock: "pv|key" = value, "pt|key" = when it kicks in ----
    fun setPending(c: Context, key: String, value: Int, at: Long) {
        prefs(c).edit().putInt("pv|" + key, value).putLong("pt|" + key, at).apply()
    }

    fun cancelPending(c: Context, key: String) {
        prefs(c).edit().remove("pv|" + key).remove("pt|" + key).apply()
    }

    fun pendingAll(c: Context): List<Triple<String, Int, Long>> {
        val p = prefs(c)
        val out = ArrayList<Triple<String, Int, Long>>()
        for ((k, v) in p.all) {
            if (!k.startsWith("pv|") || v !is Int) continue
            val key = k.substring(3)
            out.add(Triple(key, v, p.getLong("pt|" + key, 0L)))
        }
        return out.sortedBy { it.third }
    }

    fun applyDue(c: Context) {
        val now = System.currentTimeMillis()
        for ((key, value, at) in pendingAll(c)) {
            if (at <= now) {
                setSetting(c, key, value)
                cancelPending(c, key)
            }
        }
    }

    // ---- snooze (kept for older builds, not used by the begging flow) ----
    fun snoozeUntil(c: Context): Long = prefs(c).getLong("snoozeUntil", 0L)

    // ---- debug log (last 150 lines) ----
    fun log(c: Context, line: String) {
        val ts = SimpleDateFormat("HH:mm:ss.SSS", Locale.US).format(Date())
        val p = prefs(c)
        val cur = p.getString("log", "") ?: ""
        val lines = cur.split("\n").filter { it.isNotEmpty() } + (ts + " " + line)
        p.edit().putString("log", lines.takeLast(150).joinToString("\n")).apply()
    }

    fun getLog(c: Context): String = prefs(c).getString("log", "") ?: ""

    fun clearLog(c: Context) {
        prefs(c).edit().remove("log").apply()
    }
}
