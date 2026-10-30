package io.doompal.doompal

import android.accessibilityservice.AccessibilityService
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
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class ReelAccessibilityService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private val lastScrollEvent = HashMap<String, Long>()
    private val lastCounted = HashMap<String, Long>()
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

        // 1) Fast path: the view that scrolled is the reels pager itself.
        val src: AccessibilityNodeInfo? = event.source
        val srcId = ReelDetector.shortId(src)
        val srcMatch = srcId != null && Targets.matches(app, srcId)

        // 2) Otherwise look at the whole screen, and only trust it if the scrolled view is
        //    big (the reels pager is full screen; comment sheets and carousels are not).
        var treeMatch = false
        var sample = ""
        var ratio = -1f
        val root = rootInActiveWindow
        if (!srcMatch && root != null) {
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
        val inReels = lenient || srcMatch || (treeMatch && (srcId == null || bigScroller))

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

        lastCounted[app.key] = now
        Store.increment(this, app.key)

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

    private fun showOverlay(app: Targets.App, pkg: String, reason: String) {
        if (overlay != null) return
        val hard = Store.getSetting(this, "hard", 0) == 1
        val snoozeMin = Store.getSetting(this, "snooze", 5)

        val box = LinearLayout(this)
        box.orientation = LinearLayout.VERTICAL
        box.gravity = Gravity.CENTER
        box.setBackgroundColor(Color.parseColor("#F2111116"))
        box.setPadding(dp(32), dp(32), dp(32), dp(32))
        box.isClickable = true
        box.isFocusable = false

        val title = TextView(this)
        title.text = "Take a break"
        title.setTextColor(Color.WHITE)
        title.textSize = 32f
        title.gravity = Gravity.CENTER
        box.addView(title)

        val msg = TextView(this)
        msg.text = reason + "\n\nToday so far: " + Store.total(this) + " reels."
        msg.setTextColor(Color.parseColor("#CCCCCC"))
        msg.textSize = 17f
        msg.gravity = Gravity.CENTER
        val msgLp = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        )
        msgLp.topMargin = dp(16)
        box.addView(msg, msgLp)

        if (hard) {
            val note = TextView(this)
            note.text = "Hard mode is on. Taking you home..."
            note.setTextColor(Color.parseColor("#999999"))
            note.textSize = 14f
            note.gravity = Gravity.CENTER
            val noteLp = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
            )
            noteLp.topMargin = dp(12)
            box.addView(note, noteLp)
        }

        val homeBtn = Button(this)
        homeBtn.text = "Take me home"
        homeBtn.setOnClickListener { goHome() }
        val btnLp = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        )
        btnLp.topMargin = dp(28)
        box.addView(homeBtn, btnLp)

        if (!hard) {
            val snoozeBtn = Button(this)
            snoozeBtn.text = "Give me " + snoozeMin + " more minutes"
            snoozeBtn.setOnClickListener {
                Store.setSnoozeUntil(
                    this@ReelAccessibilityService,
                    System.currentTimeMillis() + snoozeMin * 60_000L
                )
                hideOverlay()
            }
            val lp2 = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
            )
            lp2.topMargin = dp(12)
            box.addView(snoozeBtn, lp2)
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
            if (hard) handler.postDelayed(autoHome, HARD_HOME_MS)
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
        private const val GESTURE_GAP_MS = 400L        // quiet time that separates two swipes
        private const val MIN_COUNT_INTERVAL_MS = 700L // never count faster than this per app
        private const val TALL_RATIO = 0.75f           // scrolled view must cover 75% of the screen
        private const val PASSIVE_THROTTLE_MS = 1500L
        private const val WATCH_MS = 700L
        private const val HARD_HOME_MS = 5000L
    }
}
