package io.doompal.doompal

import android.content.Context
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** All data lives in SharedPreferences on the phone. Nothing is ever sent anywhere. */
object Store {
    private const val MAX_GAP_MS = 120_000L // longer than this between two reels = a new session
    private const val FIRST_REEL_SECS = 20  // guess for the first reel of a session

    private fun prefs(c: Context) = c.getSharedPreferences("doompal", Context.MODE_PRIVATE)

    fun today(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    // ---- counts "c|date|app" and estimated seconds "t|date|app" ----
    fun increment(c: Context, app: String): Int {
        val p = prefs(c)
        val now = System.currentTimeMillis()
        val day = today()
        val ck = "c|" + day + "|" + app
        val tk = "t|" + day + "|" + app
        val n = p.getInt(ck, 0) + 1
        val lastApp = p.getString("lastApp", "") ?: ""
        val gap = now - p.getLong("lastTime", 0L)
        val addSecs = if (lastApp == app && gap in 1L..MAX_GAP_MS) (gap / 1000L).toInt() else FIRST_REEL_SECS
        p.edit()
            .putInt(ck, n)
            .putInt(tk, p.getInt(tk, 0) + addSecs)
            .putString("lastApp", app)
            .putLong("lastTime", now)
            .apply()
        return n
    }

    fun count(c: Context, app: String): Int = prefs(c).getInt("c|" + today() + "|" + app, 0)

    fun total(c: Context): Int {
        var sum = 0
        for (a in Targets.all) {
            if (isTracked(c, a)) sum += count(c, a.key)
        }
        return sum
    }

    fun seconds(c: Context, app: String): Int = prefs(c).getInt("t|" + today() + "|" + app, 0)

    fun totalSeconds(c: Context): Int {
        var sum = 0
        for (a in Targets.all) {
            if (isTracked(c, a)) sum += seconds(c, a.key)
        }
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

    fun clearHistory(c: Context) {
        val p = prefs(c)
        val e = p.edit()
        for (k in p.all.keys) {
            if (k.startsWith("c|") || k.startsWith("t|") || k.startsWith("z|") || k.startsWith("b|")) e.remove(k)
        }
        e.remove("lastApp").remove("lastTime").remove("chat").apply()
    }

    // ---- snoozes used today ----
    fun snoozesToday(c: Context): Int = prefs(c).getInt("z|" + today(), 0)

    fun addSnooze(c: Context) {
        val k = "z|" + today()
        val p = prefs(c)
        p.edit().putInt(k, p.getInt(k, 0) + 1).apply()
    }

    // ---- bonus reels won by begging (per day) ----
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

    // ---- chat with Doomy: "time\twho\ttext" lines, newest last, last 80 kept ----
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
        return out
    }

    // ---- settings: key "s|name" (ints only) ----
    fun getSetting(c: Context, key: String, def: Int): Int = prefs(c).getInt("s|" + key, def)

    fun setSetting(c: Context, key: String, value: Int) {
        prefs(c).edit().putInt("s|" + key, value).apply()
    }

    fun allSettings(c: Context): HashMap<String, Int> {
        val out = HashMap<String, Int>()
        for ((k, v) in prefs(c).all) {
            if (k.startsWith("s|") && v is Int) out[k.substring(2)] = v
        }
        return out
    }

    fun isTracked(c: Context, app: Targets.App): Boolean =
        getSetting(c, "track:" + app.key, if (app.defaultOn) 1 else 0) == 1

    // ---- snooze ----
    fun snoozeUntil(c: Context): Long = prefs(c).getLong("snoozeUntil", 0L)

    fun setSnoozeUntil(c: Context, t: Long) {
        prefs(c).edit().putLong("snoozeUntil", t).apply()
    }

    fun isSnoozed(c: Context): Boolean = System.currentTimeMillis() < snoozeUntil(c)

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
