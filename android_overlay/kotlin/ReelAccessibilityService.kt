package io.doompal.doompal

import android.accessibilityservice.AccessibilityService
import android.content.res.ColorStateList
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

class ReelAccessibilityService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private val lastScrollEvent = HashMap<String, Long>()
    private val lastCounted = HashMap<String, Long>()
    private val adSkipStreak = HashMap<String, Int>()
    private var lastPassiveCheck = 0L
    private var overlay: View? = null
    private var overlayPkg: String = ""
    private var overlayApp: Targets.App? = null
    private var watcherTicks = 0

    // While the overlay is up: hide it if the user leaves the app, or leaves the reels screen.
    private val watcher = object : Runnable {
        override fun run() {
            if (overlay == null) return
            val root = rootInActiveWindow
            val rootPkg = root?.packageName?.toString()
            if (root == null || rootPkg != overlayPkg) {
                hideOverlay()
                return
            }
            watcherTicks++
            val app = overlayApp
            val lenient = Store.getSetting(this@ReelAccessibilityService, "lenient", 0) == 1
            if (app != null && !lenient && watcherTicks % 2 == 0) {
                if (!ReelDetector.scan(root, app, false).matched) {
                    hideOverlay()
                    return
                }
            }
            handler.postDelayed(this, WATCH_MS)
        }
    }

    private val autoHome = Runnable {
        if (overlay != null) goHome()
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        if (debugOn()) Store.log(this, "service connected (Android " + Build.VERSION.SDK_INT + ")")
    }

    private fun debugOn(): Boolean = Store.getSetting(this, "debug", 0) == 1

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val pkg = event.packageName?.toString() ?: return
        val app = Targets.byPackage(pkg) ?: return
        if (!Store.isTracked(this, app)) return
        val now = System.currentTimeMillis()
        when (event.eventType) {
            AccessibilityEvent.TYPE_VIEW_SCROLLED -> handleScroll(event, app, pkg, now)
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> handlePassive(app, pkg, now)
            else -> {}
        }
    }

    private fun handleScroll(event: AccessibilityEvent, app: Targets.App, pkg: String, now: Long) {
        // Ignore purely horizontal scrolls (carousels, stories).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            if (event.scrollDeltaX != 0 && event.scrollDeltaY == 0) return
        }

        // One swipe fires a burst of scroll events. Only the first event after a quiet gap
        // starts a new gesture; everything inside the burst is ignored.
        val prev = lastScrollEvent[app.key] ?: 0L
        lastScrollEvent[app.key] = now
        if (now - prev < GESTURE_GAP_MS) return
        val lastC = lastCounted[app.key] ?: 0L
        if (now - lastC < MIN_COUNT_INTERVAL_MS) return

        val debug = debugOn()
        val lenient = Store.getSetting(this, "lenient", 0) == 1

        // 1) The view that scrolled is the reels pager itself.
        val src: AccessibilityNodeInfo? = event.source
        val srcId = ReelDetector.shortId(src)
        val srcMatch = srcId != null && Targets.matches(app, srcId)

        // 2) For apps without strict mode: look at the whole screen, and only trust it if the
        //    scrolled view is big (comment sheets and carousels are not full screen).
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

        // Sponsored items (ads) are not reels. Skip them, but never more than 3 in a row:
        // if "ads" keep showing up, the detector is probably wrong, so count normally.
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

        lastCounted[app.key] = now
        val n = Store.increment(this, app.key)

        // Gentle nudge every N reels
        val nudge = Store.getSetting(this, "nudge", 10)
        if (nudge > 0 && n % nudge == 0) {
            val msg = n.toString() + " " + app.noun + " today, about " +
                Limits.duration(Store.seconds(this, app.key))
            Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
        }

        if (Store.isSnoozed(this)) return
        val reason = Limits.exceeded(this, app) ?: return
        showOverlay(app, pkg, reason)
    }

    // Catches "opened reels while already over the limit" (no swipe has happened yet).
    private fun handlePassive(app: Targets.App, pkg: String, now: Long) {
        if (now - lastPassiveCheck < PASSIVE_THROTTLE_MS) return
        lastPassiveCheck = now
        if (overlay != null) return
        if (Store.isSnoozed(this)) return
        val reason = Limits.exceeded(this, app) ?: return
        val root = rootInActiveWindow ?: return
        if (ReelDetector.scan(root, app, false).matched) {
            showOverlay(app, pkg, reason)
        }
    }

    private fun dp(v: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics
        ).toInt()

    // ---- look and feel of the "Take a break" screen (same palette and fonts as the app) ----
    private val moss = Color.rgb(0x15, 0x22, 0x1D)
    private val vein = Color.rgb(0x2D, 0x43, 0x39)
    private val lichen = Color.rgb(0xE3, 0xEA, 0xDB)
    private val sage = Color.rgb(0x93, 0xA7, 0x99)
    private val pollen = Color.rgb(0xE9, 0xC4, 0x6A)

    private var fontCache = HashMap<String, Typeface>()

    /** The app's own fonts live inside the APK under flutter_assets. Falls back to system fonts. */
    private fun font(file: String, fallback: Typeface): Typeface {
        fontCache[file]?.let { return it }
        val tf = try {
            Typeface.createFromAsset(assets, "flutter_assets/assets/fonts/" + file)
        } catch (e: Exception) {
            fallback
        }
        fontCache[file] = tf
        return tf
    }

    private fun text(s: String, size: Float, color: Int, face: Typeface, topDp: Int, lineExtra: Float = 0f): TextView {
        val t = TextView(this)
        t.text = s
        t.textSize = size
        t.setTextColor(color)
        t.typeface = face
        t.gravity = Gravity.START
        if (lineExtra > 0f) t.setLineSpacing(dp(lineExtra.toInt()).toFloat(), 1f)
        val lp = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        )
        lp.topMargin = dp(topDp)
        t.layoutParams = lp
        return t
    }

    private fun pill(s: String, primary: Boolean, topDp: Int, onClick: () -> Unit): TextView {
        val bg = GradientDrawable()
        bg.cornerRadius = dp(28).toFloat()
        if (primary) {
            bg.setColor(pollen)
        } else {
            bg.setColor(Color.TRANSPARENT)
            bg.setStroke(dp(1), vein)
        }
        val ripple = RippleDrawable(ColorStateList.valueOf(Color.argb(48, 255, 255, 255)), bg, null)
        val t = TextView(this)
        t.text = s
        t.textSize = 16f
        t.typeface = font("Figtree-SemiBold.ttf", Typeface.DEFAULT_BOLD)
        t.setTextColor(if (primary) moss else lichen)
        t.gravity = Gravity.CENTER
        t.background = ripple
        t.isClickable = true
        t.isFocusable = true
        t.setPadding(dp(20), dp(16), dp(20), dp(16))
        t.setOnClickListener { onClick() }
        val lp = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        )
        lp.topMargin = dp(topDp)
        t.layoutParams = lp
        return t
    }

    private fun showOverlay(app: Targets.App, pkg: String, reason: String) {
        if (overlay != null) return
        val hard = Store.getSetting(this, "hard", 0) == 1
        val snoozeMin = Store.getSetting(this, "snooze", 5)
        val maxSnooze = Store.getSetting(this, "maxSnooze", 2)
        val used = Store.snoozesToday(this)
        val snoozesLeft = if (maxSnooze < 0) 99 else maxSnooze - used
        val canSnooze = !hard && snoozesLeft > 0
        val goingHome = !canSnooze
        val bedtime = Limits.inQuietHours(this)

        val display = font("FrauncesDisplay.ttf", Typeface.SERIF)
        val regular = font("Figtree-Regular.ttf", Typeface.DEFAULT)

        val box = LinearLayout(this)
        box.orientation = LinearLayout.VERTICAL
        box.gravity = Gravity.CENTER_VERTICAL or Gravity.START
        box.setBackgroundColor(Color.argb(0xF7, 0x15, 0x22, 0x1D))
        box.setPadding(dp(32), dp(48), dp(32), dp(40))
        box.isClickable = true
        box.isFocusable = false

        // the sprout on its shelf: drooping when you hit a limit, sleepy at bedtime
        val plant = SproutView(this, if (bedtime) 0.55f else 0.12f, 3f)
        val plantLp = LinearLayout.LayoutParams(dp(132), dp(176))
        plant.layoutParams = plantLp
        box.addView(plant)
        val shelf = View(this)
        shelf.setBackgroundColor(vein)
        val shelfLp = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(1))
        shelfLp.topMargin = -dp(3)
        shelf.layoutParams = shelfLp
        box.addView(shelf)

        box.addView(text(if (bedtime) "Time to sleep." else "Take a break.", 44f, lichen, display, 28))
        box.addView(text(reason, 17f, lichen, regular, 12, 3f))

        val total = Store.total(this)
        val secs = Store.totalSeconds(this)
        box.addView(text("Today: " + total + " so far, about " + Limits.duration(secs) + ".", 15f, sage, regular, 8))

        val idea = IDEAS[((System.currentTimeMillis() / 60000L) % IDEAS.size).toInt()]
        box.addView(text("Instead, " + idea, 17f, pollen, regular, 24, 3f))

        if (goingHome) {
            val why = if (hard) "Hard mode is on." else "You've used today's snoozes."
            box.addView(text(why + " Taking you home in a moment.", 14f, sage, regular, 20))
        }

        box.addView(pill("Take me home", true, 32) { goHome() })

        if (canSnooze) {
            var label = snoozeMin.toString() + " more minutes"
            if (maxSnooze >= 0) label += " (" + snoozesLeft + " left today)"
            box.addView(
                pill(label, false, 12) {
                    Store.addSnooze(this@ReelAccessibilityService)
                    Store.setSnoozeUntil(
                        this@ReelAccessibilityService,
                        System.currentTimeMillis() + snoozeMin * 60_000L
                    )
                    hideOverlay()
                }
            )
        }

        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        lp.gravity = Gravity.TOP or Gravity.START

        try {
            val wm = getSystemService(WINDOW_SERVICE) as WindowManager
            wm.addView(box, lp)
            overlay = box
            overlayPkg = pkg
            overlayApp = app
            watcherTicks = 0
            handler.postDelayed(watcher, WATCH_MS)
            if (goingHome) handler.postDelayed(autoHome, HARD_HOME_MS)
            if (debugOn()) Store.log(this, "overlay shown: " + reason)
        } catch (e: Exception) {
            Store.log(this, "overlay failed: " + e.message)
        }
    }

    private fun hideOverlay() {
        handler.removeCallbacks(watcher)
        handler.removeCallbacks(autoHome)
        val v = overlay ?: return
        overlay = null
        overlayApp = null
        try {
            val wm = getSystemService(WINDOW_SERVICE) as WindowManager
            wm.removeView(v)
        } catch (e: Exception) {
            // already gone
        }
    }

    private fun goHome() {
        performGlobalAction(GLOBAL_ACTION_HOME)
        hideOverlay()
    }

    override fun onInterrupt() {
        hideOverlay()
    }

    override fun onDestroy() {
        hideOverlay()
        super.onDestroy()
    }

    companion object {
        private const val GESTURE_GAP_MS = 400L
        private const val MIN_COUNT_INTERVAL_MS = 700L
        private const val TALL_RATIO = 0.75f
        private const val PASSIVE_THROTTLE_MS = 1500L
        private const val WATCH_MS = 700L
        private const val HARD_HOME_MS = 5000L
        private const val MAX_AD_SKIPS = 3

        private val IDEAS = listOf(
            "drink a glass of water.",
            "stand up and stretch for one minute.",
            "step outside for five minutes.",
            "text a friend instead.",
            "take ten slow breaths.",
            "read one page of a book.",
            "tidy one small thing near you.",
            "walk around the room.",
            "think of one thing you would rather do tonight."
        )
    }
}
