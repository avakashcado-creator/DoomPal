package io.doompal.doompal

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

class ReelAccessibilityService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var ui: DoomyUi
    private val lastScrollEvent = HashMap<String, Long>()
    private val lastCounted = HashMap<String, Long>()
    private val adSkipStreak = HashMap<String, Int>()
    private val burstLast = HashMap<String, Long>()
    private val burstEvents = HashMap<String, Int>()
    private var lastPassiveCheck = 0L
    private var lastHousekeeping = 0L

    // full-screen Doomy screen (check-in, limit, ad)
    private var overlay: View? = null
    private var overlayBox: LinearLayout? = null
    private var overlayPkg = ""
    private var overlayApp: Targets.App? = null
    private var watcherTicks = 0
    private var flowToken = 0 // bumps whenever the screen closes, so old delayed steps do nothing

    // live counter pill and comment bubble
    private var pill: LinearLayout? = null
    private var pillText: TextView? = null
    private var pillFace: ImageView? = null
    private var pillRing: GradientDrawable? = null
    private var pillPkg = ""
    private var pillApp: Targets.App? = null
    private var pillTicks = 0
    private var bubble: View? = null

    private val wm: WindowManager get() = getSystemService(WINDOW_SERVICE) as WindowManager

    override fun onServiceConnected() {
        super.onServiceConnected()
        ui = DoomyUi(this)
        if (debugOn()) Store.log(this, "service connected (Android " + Build.VERSION.SDK_INT + ")")
    }

    private fun debugOn(): Boolean = Store.getSetting(this, "debug", 0) == 1

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || !::ui.isInitialized) return
        val pkg = event.packageName?.toString() ?: return
        val app = Targets.byPackage(pkg) ?: return
        if (Store.getSetting(this, "terms", 0) != 1) return // nothing happens until the terms are accepted
        if (!Store.isTracked(this, app)) return
        val now = System.currentTimeMillis()
        housekeeping(now)
        if (Store.guestActive(this)) { // guest pass: nothing counts or blocks. Doomy only watches the swipes
            hidePill()
            if (overlay != null) hideOverlay()
            if (event.eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED) handleScroll(event, app, pkg, now)
            return
        }
        when (event.eventType) {
            AccessibilityEvent.TYPE_VIEW_SCROLLED -> handleScroll(event, app, pkg, now)
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> handlePassive(app, pkg, now)
            else -> {}
        }
    }

    /** Once a minute: let changes that finished their cooldown take effect, and let the coach think daily. */
    private fun housekeeping(now: Long) {
        if (now - lastHousekeeping < 60_000L) return
        lastHousekeeping = now
        Store.applyDue(this)
        Coach.updateIfNeeded(this)
    }

    // ------------------------------------------------------------------ counting

    private fun handleScroll(event: AccessibilityEvent, app: Targets.App, pkg: String, now: Long) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            if (event.scrollDeltaX != 0 && event.scrollDeltaY == 0) return
        }
        val prev = lastScrollEvent[app.key] ?: 0L
        lastScrollEvent[app.key] = now
        if (now - prev < GESTURE_GAP_MS) {
            // still the same swipe: remember how long it lasted and how many events it fired
            burstLast[app.key] = now
            burstEvents[app.key] = (burstEvents[app.key] ?: 0) + 1
            return
        }
        val lastC = lastCounted[app.key] ?: 0L
        if (now - lastC < MIN_COUNT_INTERVAL_MS) return
        if (overlay != null) return

        val debug = debugOn()
        val lenient = Store.getSetting(this, "lenient", 0) == 1
        val src: AccessibilityNodeInfo? = event.source
        val srcId = ReelDetector.shortId(src)
        val srcMatch = srcId != null && Targets.matches(app, srcId)

        var treeMatch = false
        var sample = ""
        var ratio = -1f
        val root = rootInActiveWindow
        if (!srcMatch && root != null && (!app.strictSource || debug)) {
            val scan = ReelDetector.scan(root, app, debug)
            treeMatch = scan.matched
            sample = scan.sample
            if (src != null) {
                val s = Rect()
                val r = Rect()
                src.getBoundsInScreen(s)
                root.getBoundsInScreen(r)
                if (r.height() > 0) ratio = s.height().toFloat() / r.height().toFloat()
            }
        }
        val bigScroller = ratio < 0f || ratio >= TALL_RATIO
        val screenOk = !app.strictSource && treeMatch && (srcId == null || bigScroller)
        val inReels = lenient || srcMatch || screenOk

        if (debug) {
            val cls = event.className?.toString()?.substringAfterLast('.') ?: "?"
            val r = if (ratio < 0f) "?" else String.format(java.util.Locale.US, "%.2f", ratio)
            Store.log(
                this,
                "scroll " + app.key + " src=" + (srcId ?: "-") + " cls=" + cls + " h=" + r +
                    " srcMatch=" + srcMatch + " screenMatch=" + treeMatch +
                    " COUNTED=" + inReels + (if (sample.isNotEmpty()) " ids=" + sample else "")
            )
        }
        if (!inReels) return

        val adRoot = rootInActiveWindow
        if (adRoot != null) {
            val ad = ReelDetector.adReason(adRoot)
            if (ad != null) {
                val streak = (adSkipStreak[app.key] ?: 0) + 1
                if (streak <= MAX_AD_SKIPS) {
                    adSkipStreak[app.key] = streak
                    if (debug) Store.log(this, "skipped ad (" + ad + ") in " + app.key)
                    return
                }
                if (debug) Store.log(this, "ad filter ignored after " + MAX_AD_SKIPS + " in a row")
            }
        }
        adSkipStreak[app.key] = 0

        // how long this reel was watched and how the swipe felt, for the scroll-style profile
        val guest = Store.guestActive(this)
        val dwell = if (lastC > 0L && now - lastC <= 120_000L) now - lastC else -1L
        burstLast[app.key] = now
        burstEvents[app.key] = 1
        val key = app.key
        handler.postDelayed({
            val swipeMs = (burstLast[key] ?: now) - now
            if (dwell > 0L) {
                if (guest) ScrollStyle.recordGuest(this, dwell, swipeMs, burstEvents[key] ?: 1)
                else ScrollStyle.record(this, dwell, swipeMs, burstEvents[key] ?: 1)
            }
            if (guest) checkGuest(app, pkg)
        }, 600L)

        lastCounted[app.key] = now
        if (guest) return // a guest's swipes don't count against the owner
        val n = Store.increment(this, app.key)
        showPill(app, pkg)

        val risk = Coach.isRiskHour(this)
        val nudgeBase = Store.getSetting(this, "nudge", 5)
        val nudge = if (nudgeBase > 0 && risk) minOf(nudgeBase, 3) else nudgeBase
        if (nudge > 0 && n % nudge == 0) {
            val mins = Store.seconds(this, app.key) / 60
            showBubble(DoomyLines.milestone(n, app.noun, mins), moodOf(ratioFor(app)))
        } else if (Store.getSetting(this, "eyeBreak", 1) == 1 && Store.eyeBreakDue(this, now)) {
            showBubble(DoomyLines.pick(DoomyLines.eyeBreak), "judge")
        }

        val reason = Limits.exceeded(this, app) ?: return
        showLimit(app, pkg, reason)
    }

    /** After a guest's first swipes: if they scroll like the owner, cancel the pass and count them. */
    private fun checkGuest(app: Targets.App, pkg: String) {
        val p = Store.prefs(this)
        if (!Store.guestActive(this) || p.getInt("gs|done", 0) == 1) return
        val n = p.getInt("gs|n", 0)
        if (n < GUEST_WATCH_SWIPES) return
        p.edit().putInt("gs|done", 1).apply()
        if (ScrollStyle.verdict(this, "gs|recent").kind != "owner") return // looks like a different person
        Store.revokeGuest(this)
        for (i in 0..n) Store.increment(this, app.key) // those swipes were the owner's
        showBubble("that scrolls like the owner bro. guest pass cancelled, those swipes count.", "smug")
        handler.postDelayed({
            val reason = Limits.exceeded(this, app)
            if (reason != null) showLimit(app, pkg, reason)
        }, 2500L)
    }

    // Opening reels: show the live counter, Doomy's check-in, or the limit screen.
    private fun handlePassive(app: Targets.App, pkg: String, now: Long) {
        if (now - lastPassiveCheck < PASSIVE_THROTTLE_MS) return
        lastPassiveCheck = now
        if (overlay != null) return
        val root = rootInActiveWindow ?: return
        if (!ReelDetector.scan(root, app, false).matched) return

        val reason = Limits.exceeded(this, app)
        if (reason != null) {
            showLimit(app, pkg, reason)
            return
        }
        showPill(app, pkg)

        if (Store.getSetting(this, "gate", 1) == 1) {
            val risk = Coach.isRiskHour(this)
            val base = Store.getSetting(this, "gateEvery", 15).coerceAtLeast(1)
            val every = (if (risk) minOf(base, 5) else base) * 60_000L
            val last = Store.lastGate(this)
            if (now - last >= every) {
                Store.setLastGate(this, now)
                val again = now - last < 3 * 3_600_000L
                showGate(app, pkg, if (again) ((now - last) / 60_000L).toInt() else -1, risk)
            }
        }
    }

    // ------------------------------------------------------------------ Doomy's mood

    private fun ratioFor(app: Targets.App): Float {
        val n = Store.count(this, app.key)
        val limit = Limits.limitFor(this, app)
        return if (limit > 0) n.toFloat() / limit else n / 60f
    }

    private fun moodOf(ratio: Float): String = when {
        ratio >= 1f -> "dead"
        ratio >= 0.8f -> "shocked"
        ratio >= 0.5f -> "judge"
        else -> "chill"
    }

    private fun ringColor(ratio: Float): Int = when {
        ratio >= 1f -> Color.rgb(0xFF, 0x5C, 0x5C)
        ratio >= 0.8f -> Color.rgb(0xFF, 0xB0, 0x20)
        else -> Color.rgb(0xA9, 0x9B, 0xFF)
    }

    // ------------------------------------------------------------------ live counter pill

    private fun pillLabel(app: Targets.App): String {
        val n = Store.count(this, app.key)
        val limit = Limits.limitFor(this, app)
        return if (limit > 0) "$n / $limit " + app.noun else "$n " + app.noun
    }

    private fun refreshPill(app: Targets.App, pkg: String, pulse: Boolean) {
        val ratio = ratioFor(app)
        pillText?.text = pillLabel(app)
        DoomyAssets.doomy(this, moodOf(ratio))?.let { pillFace?.setImageBitmap(it) }
        pillRing?.setStroke(ui.dp(3), ringColor(ratio))
        pillPkg = pkg
        pillApp = app
        val row = pill ?: return
        if (pulse) {
            row.animate().cancel()
            row.animate().scaleX(1.18f).scaleY(1.18f).setDuration(110L).withEndAction {
                row.animate().scaleX(1f).scaleY(1f).setDuration(160L).start()
            }.start()
        }
    }

    private fun showPill(app: Targets.App, pkg: String) {
        if (Store.getSetting(this, "counter", 1) != 1) return
        if (pill != null) {
            refreshPill(app, pkg, true)
            return
        }
        val row = LinearLayout(this)
        row.orientation = LinearLayout.HORIZONTAL
        row.gravity = Gravity.CENTER_VERTICAL
        val bg = GradientDrawable()
        bg.cornerRadius = ui.dp(32).toFloat()
        bg.setColor(Color.argb(0xF0, 0, 0, 0))
        row.background = bg
        row.setPadding(ui.dp(8), ui.dp(6), ui.dp(18), ui.dp(6))
        val face = ui.avatar("chill", 46)
        row.addView(face)
        val t = TextView(this)
        t.textSize = 18f
        t.typeface = ui.semibold
        t.setTextColor(Color.WHITE)
        val tlp = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        tlp.leftMargin = ui.dp(10)
        row.addView(t, tlp)

        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        lp.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
        lp.y = ui.dp(48)
        try {
            wm.addView(row, lp)
            pill = row
            pillText = t
            pillFace = face
            pillRing = bg
            pillTicks = 0
            refreshPill(app, pkg, true)
            handler.postDelayed(pillWatcher, WATCH_MS)
        } catch (e: Exception) {
            Store.log(this, "pill failed: " + e.message)
        }
    }

    private val pillWatcher = object : Runnable {
        override fun run() {
            if (pill == null) return
            val root = rootInActiveWindow
            if (root == null || root.packageName?.toString() != pillPkg) {
                hidePill()
                return
            }
            pillTicks++
            val app = pillApp
            val lenient = Store.getSetting(this@ReelAccessibilityService, "lenient", 0) == 1
            if (app != null && !lenient && pillTicks % 2 == 0 && !ReelDetector.scan(root, app, false).matched) {
                hidePill()
                return
            }
            handler.postDelayed(this, WATCH_MS)
        }
    }

    private fun hidePill() {
        handler.removeCallbacks(pillWatcher)
        val v = pill ?: return
        pill = null
        pillText = null
        pillFace = null
        pillRing = null
        try {
            wm.removeView(v)
        } catch (e: Exception) {
            // already gone
        }
    }

    // ------------------------------------------------------------------ comment bubble

    private val hideBubbleRunnable = Runnable { hideBubble() }

    private fun showBubble(text: String, expr: String) {
        hideBubble()
        Store.chat(this, "doomy", text)
        val row = LinearLayout(this)
        row.orientation = LinearLayout.HORIZONTAL
        row.gravity = Gravity.BOTTOM
        row.setPadding(ui.dp(14), 0, ui.dp(14), 0)
        row.addView(ui.avatar(expr, 72))
        val b = TextView(this)
        b.text = text
        b.textSize = 19f
        b.typeface = ui.semibold
        b.setTextColor(Color.WHITE)
        val bg = GradientDrawable()
        bg.cornerRadius = ui.dp(22).toFloat()
        bg.setColor(Color.argb(0xF8, 0x1E, 0x1E, 0x1E))
        bg.setStroke(ui.dp(2), Color.rgb(0xA9, 0x9B, 0xFF))
        b.background = bg
        b.setPadding(ui.dp(16), ui.dp(12), ui.dp(16), ui.dp(12))
        b.maxWidth = (resources.displayMetrics.widthPixels * 0.66).toInt()
        val blp = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        blp.leftMargin = ui.dp(8)
        blp.bottomMargin = ui.dp(14)
        row.addView(b, blp)

        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        lp.gravity = Gravity.BOTTOM or Gravity.START
        lp.y = ui.dp(140)
        try {
            wm.addView(row, lp)
            bubble = row
            row.performHapticFeedback(android.view.HapticFeedbackConstants.LONG_PRESS)
            handler.postDelayed(hideBubbleRunnable, BUBBLE_MS)
        } catch (e: Exception) {
            Store.log(this, "bubble failed: " + e.message)
        }
    }

    private fun hideBubble() {
        handler.removeCallbacks(hideBubbleRunnable)
        val v = bubble ?: return
        bubble = null
        try {
            wm.removeView(v)
        } catch (e: Exception) {
            // already gone
        }
    }

    // ------------------------------------------------------------------ full screens

    /** Opens an empty full-screen Doomy screen and returns its content column. */
    private fun openScreen(app: Targets.App, pkg: String): LinearLayout? {
        if (overlay != null) return null
        hideBubble()
        val scroll = ScrollView(this)
        scroll.setBackgroundColor(Color.argb(0xF7, 0, 0, 0))
        scroll.isFillViewport = true
        val box = LinearLayout(this)
        box.orientation = LinearLayout.VERTICAL
        box.gravity = Gravity.CENTER_VERTICAL
        box.setPadding(ui.dp(24), ui.dp(56), ui.dp(24), ui.dp(40))
        scroll.addView(box, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))

        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        lp.gravity = Gravity.TOP or Gravity.START
        return try {
            wm.addView(scroll, lp)
            overlay = scroll
            overlayBox = box
            overlayPkg = pkg
            overlayApp = app
            watcherTicks = 0
            flowToken++
            handler.postDelayed(watcher, WATCH_MS)
            scroll.performHapticFeedback(android.view.HapticFeedbackConstants.LONG_PRESS)
            box
        } catch (e: Exception) {
            Store.log(this, "screen failed: " + e.message)
            null
        }
    }

    /** Run [step] after [delay] ms, but only if the same screen is still open. */
    private fun later(delay: Long, step: () -> Unit) {
        val token = flowToken
        handler.postDelayed({ if (overlay != null && token == flowToken) step() }, delay)
    }

    /** Doomy "types" a few messages one after another, then calls [then]. */
    private fun doomySays(box: LinearLayout, lines: List<String>, then: () -> Unit) {
        var t = 0L
        for (line in lines) {
            later(t) {
                val big = line == line.uppercase() && line.any { it.isLetter() }
                box.addView(ui.bubble(line, mine = false, big = big))
                Store.chat(this, "doomy", line)
            }
            t += 550L
        }
        later(t + 150L) { then() }
    }

    private fun youSay(box: LinearLayout, line: String) {
        box.addView(ui.bubble(line, mine = true, top = 14))
        Store.chat(this, "you", line)
    }

    private fun clearButtons(box: LinearLayout) {
        val toRemove = (0 until box.childCount).map { box.getChildAt(it) }.filter { it.tag == "button" }
        toRemove.forEach { box.removeView(it) }
    }

    private fun addButton(box: LinearLayout, label: String, primary: Boolean, top: Int, onClick: () -> Unit) {
        val b = ui.button(label, primary, top) { onClick() }
        b.tag = "button"
        box.addView(b)
    }

    private fun guestAvailable(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false
        if (Store.getSetting(this, "guest", 1) != 1) return false
        return Store.guestUsesToday(this) < Store.getSetting(this, "guestPerDay", 1)
    }

    private fun launchGuest() {
        // start the screen first (Android is stricter about starting screens from the background),
        // then hide our overlay a moment later so it can't cover the fingerprint prompt
        val i = Intent(this, GuestPassActivity::class.java)
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            startActivity(i)
            handler.postDelayed({ hideOverlay() }, 400L)
        } catch (e: Exception) {
            Store.log(this, "guest launch failed: " + e.message)
        }
    }

    private fun addGuestButton(box: LinearLayout) {
        if (guestAvailable()) addButton(box, "not the owner? guest pass", false, 10) { launchGuest() }
    }

    /** "boi boi. no reels? why u scrolling" */
    private fun showGate(app: Targets.App, pkg: String, minutesSinceLast: Int, risk: Boolean) {
        val box = openScreen(app, pkg) ?: return
        box.addView(ui.header("judge"))
        val lines = ArrayList<String>()
        lines.addAll(if (minutesSinceLast >= 0) DoomyLines.gateAgain(minutesSinceLast) else DoomyLines.pick(DoomyLines.gateOpen))
        if (risk) lines.add(DoomyLines.pick(DoomyLines.riskLine))
        doomySays(box, lines) {
            addButton(box, DoomyLines.PLEASE, false, 28) {
                clearButtons(box)
                youSay(box, DoomyLines.PLEASE)
                doomySays(box, DoomyLines.gateNo) {
                    later(700L) { showAd(app, Limits.adSeconds(this)) { hideOverlay() } }
                }
            }
            addButton(box, DoomyLines.OUT, true, 10) {
                clearButtons(box)
                youSay(box, DoomyLines.OUT)
                doomySays(box, DoomyLines.pick(DoomyLines.proud)) { later(700L) { goHome() } }
            }
            addGuestButton(box)
        }
    }

    /** "okay bud, time to pack it up now. no more reels." */
    private fun showLimit(app: Targets.App, pkg: String, reason: String) {
        val box = openScreen(app, pkg) ?: return
        hidePill()
        val bedtime = Limits.inQuietHours(this)
        val hard = Store.getSetting(this, "hard", 0) == 1
        val maxBegs = Limits.begsPerDay(this)
        val used = Store.snoozesToday(this)
        val begsLeft = if (maxBegs < 0) 99 else maxBegs - used
        val canBeg = !hard && begsLeft > 0
        val begReels = Store.getSetting(this, "begReels", 5)

        box.addView(ui.header(if (bedtime) "chill" else "dead"))
        val total = Store.total(this)
        val stats = "you scrolled " + total + " today, about " + Limits.duration(Store.totalSeconds(this)) + "."
        val opening = if (bedtime) DoomyLines.bedtime else DoomyLines.pick(DoomyLines.limitOpen)
        doomySays(box, opening) {
            box.addView(ui.text(reason + " " + stats, 14f, ui.muted, ui.regular, 14))
            if (canBeg) {
                val ask = DoomyLines.begAsk(begReels)
                val left = if (maxBegs < 0) "" else " (" + begsLeft + " left)"
                addButton(box, ask + left, false, 24) {
                    clearButtons(box)
                    youSay(box, ask)
                    doomySays(box, DoomyLines.pick(DoomyLines.begReply)) {
                        // every beg today makes the ad longer
                        val secs = Limits.adSeconds(this) * (used + 1)
                        later(700L) {
                            showAd(app, secs) {
                                Store.addSnooze(this)
                                Store.addBonus(this, begReels)
                                Store.chat(this, "doomy", "fine. $begReels more. i'm counting.")
                                hideOverlay()
                            }
                        }
                    }
                }
                addButton(box, "take me home", true, 10) { goHome() }
                addGuestButton(box)
            } else {
                val why = if (hard) listOf("hard mode is on.", "no begging. home.") else DoomyLines.noBegs
                doomySays(box, why) {
                    addButton(box, "take me home", true, 24) { goHome() }
                    addGuestButton(box)
                    later(8000L) { goHome() }
                }
            }
        }
    }

    /** The unskippable joke ad. Calls [done] when the countdown is over and you tap through. */
    private fun showAd(app: Targets.App, seconds: Int, done: () -> Unit) {
        val box = overlayBox ?: return
        box.removeAllViews()
        flowToken++
        val ad = DoomyLines.pick(DoomyLines.ads)
        val n = Store.count(this, app.key)
        box.addView(ui.adChip())
        val card = ui.memeCard("ME AFTER " + n + " " + app.noun, DoomyLines.pick(DoomyLines.punchlines), 300)
        val clp = card.layoutParams as LinearLayout.LayoutParams
        clp.topMargin = ui.dp(14)
        box.addView(card)
        box.addView(ui.text(ad.title, 44f, ui.white, ui.anton, 22))
        box.addView(ui.text(ad.sub, 17f, ui.muted, ui.regular, 4))
        val bar = ui.progress(0f, 26)
        box.addView(bar)
        val count = ui.text("you can leave in " + seconds, 14f, ui.muted, ui.regular, 10)
        box.addView(count)
        Store.chat(this, "doomy", "[ad] " + ad.title + ": " + ad.sub)

        val total = seconds.coerceAtLeast(1)
        for (i in 1..total) {
            later(i * 1000L) {
                ui.setProgress(bar, i.toFloat() / total)
                val left = total - i
                if (left > 0) {
                    count.text = "you can leave in " + left
                } else {
                    count.text = "ok that's it. doomy appreciates u."
                    addButton(box, "ok i get it", true, 18) { done() }
                }
            }
        }
    }

    // While a Doomy screen is up: close it if you leave the app or leave the reels screen.
    private val watcher = object : Runnable {
        override fun run() {
            if (overlay == null) return
            if (Store.guestActive(this@ReelAccessibilityService)) {
                hideOverlay()
                return
            }
            val root = rootInActiveWindow
            if (root == null || root.packageName?.toString() != overlayPkg) {
                hideOverlay()
                return
            }
            watcherTicks++
            val app = overlayApp
            val lenient = Store.getSetting(this@ReelAccessibilityService, "lenient", 0) == 1
            if (app != null && !lenient && watcherTicks % 3 == 0 && !ReelDetector.scan(root, app, false).matched) {
                hideOverlay()
                return
            }
            handler.postDelayed(this, WATCH_MS)
        }
    }

    private fun hideOverlay() {
        handler.removeCallbacks(watcher)
        flowToken++
        val v = overlay ?: return
        overlay = null
        overlayBox = null
        overlayApp = null
        try {
            wm.removeView(v)
        } catch (e: Exception) {
            // already gone
        }
    }

    private fun goHome() {
        performGlobalAction(GLOBAL_ACTION_HOME)
        hideOverlay()
        hidePill()
    }

    override fun onInterrupt() {
        hideOverlay()
        hidePill()
        hideBubble()
    }

    override fun onDestroy() {
        hideOverlay()
        hidePill()
        hideBubble()
        super.onDestroy()
    }

    companion object {
        private const val GESTURE_GAP_MS = 400L
        private const val MIN_COUNT_INTERVAL_MS = 700L
        private const val TALL_RATIO = 0.75f
        private const val PASSIVE_THROTTLE_MS = 1500L
        private const val WATCH_MS = 1000L
        private const val BUBBLE_MS = 4500L
        private const val MAX_AD_SKIPS = 3
        private const val GUEST_WATCH_SWIPES = 10
    }
}
