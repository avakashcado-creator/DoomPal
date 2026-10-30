package io.doompal.doompal

import android.content.Context
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** All data lives in SharedPreferences on the phone. Nothing is ever sent anywhere. */
object Store {
    private fun prefs(c: Context) = c.getSharedPreferences("doompal", Context.MODE_PRIVATE)

    fun today(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    // ---- counts: key "c|yyyy-MM-dd|appKey" ----
    fun increment(c: Context, app: String): Int {
        val k = "c|" + today() + "|" + app
        val p = prefs(c)
        val n = p.getInt(k, 0) + 1
        p.edit()
            .putInt(k, n)
            .putString("lastApp", app)
            .putLong("lastTime", System.currentTimeMillis())
            .apply()
        return n
    }

    fun count(c: Context, app: String): Int = prefs(c).getInt("c|" + today() + "|" + app, 0)

    fun total(c: Context): Int {
        var sum = 0
        for (a in Targets.all) sum += count(c, a.key)
        return sum
    }

    fun history(c: Context): HashMap<String, HashMap<String, Int>> {
        val out = HashMap<String, HashMap<String, Int>>()
        for ((k, v) in prefs(c).all) {
            if (!k.startsWith("c|") || v !is Int) continue
            val parts = k.split("|")
            if (parts.size != 3) continue
            val day = out.getOrPut(parts[1]) { HashMap() }
            day[parts[2]] = v
        }
        return out
    }

    fun clearHistory(c: Context) {
        val p = prefs(c)
        val e = p.edit()
        for (k in p.all.keys) {
            if (k.startsWith("c|")) e.remove(k)
        }
        e.remove("lastApp").remove("lastTime").apply()
    }

    /** Small status map for the Today screen. */
    fun status(c: Context): HashMap<String, Any> {
        val p = prefs(c)
        val out = HashMap<String, Any>()
        out["lastApp"] = p.getString("lastApp", "") ?: ""
        out["lastTime"] = p.getLong("lastTime", 0L)
        out["snoozeUntil"] = p.getLong("snoozeUntil", 0L)
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
