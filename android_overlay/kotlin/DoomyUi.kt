package io.doompal.doompal

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/** Small view kit for Doomy's screens: Instagram-style dark chat, meme cards, pills. */
class DoomyUi(private val c: Context) {
    val ink = Color.BLACK
    val card = Color.rgb(0x12, 0x12, 0x12)
    val bubbleGrey = Color.rgb(0x26, 0x26, 0x26)
    val line = Color.rgb(0x36, 0x36, 0x36)
    val white = Color.rgb(0xF5, 0xF5, 0xF5)
    val muted = Color.rgb(0xA8, 0xA8, 0xA8)
    val doomy = Color.rgb(0xA9, 0x9B, 0xFF)
    val blue = Color.rgb(0x37, 0x97, 0xF0)

    val anton: Typeface get() = DoomyAssets.font(c, "Anton-Regular.ttf", Typeface.DEFAULT_BOLD)
    val regular: Typeface get() = DoomyAssets.font(c, "Figtree-Regular.ttf", Typeface.DEFAULT)
    val semibold: Typeface get() = DoomyAssets.font(c, "Figtree-SemiBold.ttf", Typeface.DEFAULT_BOLD)

    fun dp(v: Int): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), c.resources.displayMetrics).toInt()

    fun lp(w: Int, h: Int, top: Int = 0): LinearLayout.LayoutParams {
        val p = LinearLayout.LayoutParams(w, h)
        p.topMargin = dp(top)
        return p
    }

    fun text(s: String, sp: Float, color: Int, face: Typeface, top: Int = 0): TextView {
        val t = TextView(c)
        t.text = s
        t.textSize = sp
        t.setTextColor(color)
        t.typeface = face
        t.setLineSpacing(dp(2).toFloat(), 1f)
        t.layoutParams = lp(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT, top)
        return t
    }

    fun avatar(expr: String, sizeDp: Int): ImageView {
        val iv = ImageView(c)
        DoomyAssets.doomy(c, expr)?.let { iv.setImageBitmap(it) }
        iv.layoutParams = LinearLayout.LayoutParams(dp(sizeDp), dp(sizeDp))
        return iv
    }

    /** Doomy's name row, like the top of a post: avatar, name, verified tick, handle. */
    fun header(expr: String): LinearLayout {
        val row = LinearLayout(c)
        row.orientation = LinearLayout.HORIZONTAL
        row.gravity = Gravity.CENTER_VERTICAL
        row.addView(avatar(expr, 56))
        val col = LinearLayout(c)
        col.orientation = LinearLayout.VERTICAL
        val nameRow = LinearLayout(c)
        nameRow.orientation = LinearLayout.HORIZONTAL
        nameRow.gravity = Gravity.CENTER_VERTICAL
        val name = TextView(c)
        name.text = "Doomy"
        name.textSize = 17f
        name.typeface = semibold
        name.setTextColor(white)
        nameRow.addView(name)
        val tick = TextView(c)
        tick.text = " ✓"
        tick.textSize = 11f
        tick.typeface = semibold
        tick.setTextColor(Color.WHITE)
        val tb = GradientDrawable()
        tb.shape = GradientDrawable.OVAL
        tb.setColor(blue)
        tick.background = tb
        tick.gravity = Gravity.CENTER
        val tlp = LinearLayout.LayoutParams(dp(17), dp(17))
        tlp.leftMargin = dp(6)
        tick.layoutParams = tlp
        tick.setPadding(0, 0, dp(2), 0)
        nameRow.addView(tick)
        col.addView(nameRow)
        val handle = TextView(c)
        handle.text = "@doomy · watching u"
        handle.textSize = 13f
        handle.typeface = regular
        handle.setTextColor(muted)
        col.addView(handle)
        val clp = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        clp.leftMargin = dp(12)
        col.layoutParams = clp
        row.addView(col)
        row.layoutParams = lp(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        return row
    }

    /** A chat bubble. Doomy's are grey on the left, yours are blue on the right. */
    fun bubble(s: String, mine: Boolean, big: Boolean = false, top: Int = 8): View {
        val t = TextView(c)
        t.text = s
        t.textSize = if (big) 34f else 17f
        t.typeface = if (big) anton else regular
        t.setTextColor(Color.WHITE)
        val bg = GradientDrawable()
        bg.cornerRadius = dp(22).toFloat()
        bg.setColor(if (mine) blue else bubbleGrey)
        t.background = bg
        t.setPadding(dp(16), dp(if (big) 8 else 11), dp(16), dp(if (big) 8 else 11))
        t.maxWidth = (c.resources.displayMetrics.widthPixels * 0.78).toInt()
        val wrap = LinearLayout(c)
        wrap.orientation = LinearLayout.HORIZONTAL
        wrap.gravity = if (mine) Gravity.END else Gravity.START
        wrap.addView(t)
        wrap.layoutParams = lp(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT, top)
        return wrap
    }

    fun button(s: String, primary: Boolean, top: Int, onClick: () -> Unit): TextView {
        val bg = GradientDrawable()
        bg.cornerRadius = dp(14).toFloat()
        if (primary) bg.setColor(doomy) else {
            bg.setColor(Color.TRANSPARENT)
            bg.setStroke(dp(1), line)
        }
        val t = TextView(c)
        t.text = s
        t.textSize = 16f
        t.typeface = semibold
        t.setTextColor(if (primary) Color.BLACK else white)
        t.gravity = Gravity.CENTER
        t.background = RippleDrawable(ColorStateList.valueOf(Color.argb(50, 255, 255, 255)), bg, null)
        t.isClickable = true
        t.isFocusable = true
        t.setPadding(dp(16), dp(15), dp(16), dp(15))
        t.setOnClickListener { onClick() }
        t.layoutParams = lp(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT, top)
        return t
    }

    /** White Anton caption with a black outline, the classic meme look. */
    fun caption(s: String, sp: Float, gravity: Int, margin: Int): FrameLayout {
        val f = FrameLayout(c)
        for (stroke in listOf(true, false)) {
            val t = TextView(c)
            t.text = s.uppercase()
            t.textSize = sp
            t.typeface = anton
            t.gravity = Gravity.CENTER
            t.setTextColor(if (stroke) Color.BLACK else Color.WHITE)
            if (stroke) {
                t.paint.style = Paint.Style.STROKE
                t.paint.strokeWidth = dp(4).toFloat()
                t.paint.strokeJoin = Paint.Join.ROUND
            }
            f.addView(t, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        }
        val p = FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT, gravity)
        p.setMargins(dp(12), dp(margin), dp(12), dp(margin))
        f.layoutParams = p
        return f
    }

    /** A square meme: either a finished meme from assets/memes, or a template photo with captions. */
    fun memeCard(topText: String, bottomText: String, heightDp: Int): FrameLayout {
        val frame = FrameLayout(c)
        val bg = GradientDrawable()
        bg.cornerRadius = dp(16).toFloat()
        bg.setColor(card)
        frame.background = bg
        frame.clipToOutline = true
        val memes = DoomyAssets.list(c, "memes")
        val templates = DoomyAssets.list(c, "templates")
        val useTemplate = templates.isNotEmpty() && (memes.isEmpty() || Math.random() < 0.6)
        val iv = ImageView(c)
        if (useTemplate) {
            DoomyAssets.drawable(c, "templates/" + DoomyLines.pick(templates))?.let { iv.setImageDrawable(it) }
            iv.scaleType = ImageView.ScaleType.CENTER_CROP
        } else if (memes.isNotEmpty()) {
            DoomyAssets.drawable(c, "memes/" + DoomyLines.pick(memes))?.let { iv.setImageDrawable(it) }
            iv.scaleType = ImageView.ScaleType.FIT_CENTER
        } else {
            DoomyAssets.doomy(c, "shocked")?.let { iv.setImageBitmap(it) }
            iv.scaleType = ImageView.ScaleType.FIT_CENTER
        }
        frame.addView(iv, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        if (useTemplate || (memes.isEmpty() && templates.isEmpty())) {
            frame.addView(caption(topText, 28f, Gravity.TOP, 10))
            frame.addView(caption(bottomText, 28f, Gravity.BOTTOM, 10))
        }
        frame.layoutParams = lp(ViewGroup.LayoutParams.MATCH_PARENT, dp(heightDp))
        return frame
    }

    /** The little "Ad" label, like a sponsored post. */
    fun adChip(): LinearLayout {
        val row = LinearLayout(c)
        row.orientation = LinearLayout.HORIZONTAL
        row.gravity = Gravity.CENTER_VERTICAL
        val chip = TextView(c)
        chip.text = "Ad"
        chip.textSize = 13f
        chip.typeface = semibold
        chip.setTextColor(Color.BLACK)
        val bg = GradientDrawable()
        bg.cornerRadius = dp(6).toFloat()
        bg.setColor(Color.rgb(0xFF, 0xD4, 0x4D))
        chip.background = bg
        chip.setPadding(dp(8), dp(3), dp(8), dp(3))
        row.addView(chip)
        val by = TextView(c)
        by.text = "   sponsored by doomy"
        by.textSize = 14f
        by.typeface = regular
        by.setTextColor(muted)
        row.addView(by)
        row.layoutParams = lp(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        return row
    }

    fun progress(fraction: Float, top: Int): FrameLayout {
        val f = FrameLayout(c)
        val track = GradientDrawable()
        track.cornerRadius = dp(3).toFloat()
        track.setColor(line)
        f.background = track
        val fill = View(c)
        val fb = GradientDrawable()
        fb.cornerRadius = dp(3).toFloat()
        fb.setColor(doomy)
        fill.background = fb
        f.addView(fill, FrameLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT))
        f.layoutParams = lp(ViewGroup.LayoutParams.MATCH_PARENT, dp(6), top)
        f.tag = fill
        f.post { setProgress(f, fraction) }
        return f
    }

    fun setProgress(bar: FrameLayout, fraction: Float) {
        val fill = bar.tag as? View ?: return
        val p = fill.layoutParams
        p.width = (bar.width * fraction.coerceIn(0f, 1f)).toInt()
        fill.layoutParams = p
    }
}
