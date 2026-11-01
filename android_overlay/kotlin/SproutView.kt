package io.doompal.doompal

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.view.View
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

/**
 * The same sprout as the app's Today screen (lib/sprout.dart), drawn natively for the
 * "Take a break" screen. Drawing area is 180 x 240 units.
 */
class SproutView(context: Context, private val health: Float, private val stage: Float) : View(context) {

    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }

    private fun mix(a: Int, b: Int, t: Float): Int {
        val k = t.coerceIn(0f, 1f)
        return Color.rgb(
            (Color.red(a) + (Color.red(b) - Color.red(a)) * k).toInt(),
            (Color.green(a) + (Color.green(b) - Color.green(a)) * k).toInt(),
            (Color.blue(a) + (Color.blue(b) - Color.blue(a)) * k).toInt()
        )
    }

    private fun smooth(t: Float): Float {
        val x = t.coerceIn(0f, 1f)
        return x * x * (3 - 2 * x)
    }

    private fun oval(c: Canvas, cx: Float, cy: Float, rx: Float, ry: Float, angleRad: Float, color: Int) {
        c.save()
        c.translate(cx, cy)
        c.rotate(Math.toDegrees(angleRad.toDouble()).toFloat())
        fill.color = color
        c.drawOval(RectF(-rx, -ry, rx, ry), fill)
        c.restore()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val scale = width / 180f
        canvas.save()
        canvas.scale(scale, scale)
        canvas.translate(-60f, -40f)

        val wilt = smooth((0.8f - health) / 0.8f)
        val g = stage.coerceIn(0f, 7f)
        val bx = 150f
        val by = 214f
        val stemLen = 58f + 13f * min(g, 6f)
        val bend = (150.0 * Math.PI / 180.0).toFloat() * wilt
        val lean = (-6.0 * Math.PI / 180.0).toFloat()

        val n = 36
        val px = FloatArray(n + 1)
        val py = FloatArray(n + 1)
        val ang = FloatArray(n + 1)
        px[0] = bx; py[0] = by; ang[0] = lean
        var x = bx
        var y = by
        val seg = stemLen / n
        for (i in 1..n) {
            val s = i.toFloat() / n
            val a = lean + bend * s.toDouble().pow(2.6).toFloat()
            x += sin(a) * seg
            y -= cos(a) * seg
            px[i] = x; py[i] = y; ang[i] = a
        }

        val leaf = Color.rgb(0x8C, 0xC9, 0x7E)
        val straw = Color.rgb(0xC9, 0xA4, 0x5C)
        val dry = Color.rgb(0x93, 0x6E, 0x47)
        val lc = if (wilt < 0.5f) mix(leaf, straw, wilt * 2) else mix(straw, dry, (wilt - 0.5f) * 2)
        val rib = mix(lc, Color.rgb(0x2E, 0x45, 0x2E), 0.32f)
        val stemColor = mix(lc, Color.rgb(0x4E, 0x6E, 0x48), 0.35f)

        // pot
        val body = Path().apply {
            moveTo(98f, 222f); lineTo(202f, 222f); lineTo(190f, 272f)
            quadTo(189f, 276f, 185f, 276f); lineTo(115f, 276f)
            quadTo(111f, 276f, 110f, 272f); close()
        }
        fill.color = Color.rgb(0x34, 0x50, 0x3F)
        canvas.drawPath(body, fill)
        fill.color = Color.rgb(0x3F, 0x61, 0x50)
        canvas.drawRoundRect(RectF(92f, 208f, 208f, 226f), 5f, 5f, fill)
        fill.color = Color.rgb(0x20, 0x18, 0x0F)
        canvas.drawOval(RectF(98f, 206f, 202f, 216f), fill)
        stroke.color = Color.rgb(0x45, 0x6B, 0x59)
        stroke.strokeWidth = 3f
        canvas.drawLine(108f, 230f, 113f, 266f, stroke)

        // stem
        val stem = Path().apply {
            moveTo(px[0], py[0])
            for (i in 1..n) lineTo(px[i], py[i])
        }
        stroke.color = stemColor
        stroke.strokeWidth = 5f
        canvas.drawPath(stem, stroke)

        // leaves
        val leafCount = 2f + min(g, 5f)
        val count = ceil(leafCount).toInt()
        for (k in 0 until count) {
            val grow = (leafCount - k).coerceIn(0f, 1f)
            if (grow <= 0f) continue
            val s = if (count > 1) 0.22f + 0.68f * (k.toFloat() / (count - 1)) else 0.5f
            val idx = floor(s * n).toInt()
            val side = if (k % 2 == 0) -1f else 1f
            val len = 36f * (1 - 0.38f * s) * grow
            val wid = len * 0.46f
            val phi = ang[idx] + side * (58.0 * Math.PI / 180.0).toFloat()
            val down = side * (160.0 * Math.PI / 180.0).toFloat()
            val tip = phi + (down - phi) * (0.75f * wilt)
            canvas.save()
            canvas.translate(px[idx], py[idx])
            canvas.rotate(Math.toDegrees((tip - Math.PI / 2)).toFloat())
            val whole = Path().apply {
                moveTo(0f, 0f); quadTo(len * 0.45f, -wid, len, 0f); quadTo(len * 0.45f, wid, 0f, 0f); close()
            }
            val half = Path().apply {
                moveTo(0f, 0f); quadTo(len * 0.45f, -wid, len, 0f); quadTo(len * 0.5f, -wid * 0.12f, 0f, 0f); close()
            }
            fill.color = rib
            canvas.drawPath(whole, fill)
            fill.color = lc
            canvas.drawPath(half, fill)
            canvas.restore()
        }

        // bud or flower
        val tx = px[n]
        val ty = py[n]
        val ta = ang[n]
        val pollen = Color.rgb(0xE9, 0xC4, 0x6A)
        val petal = Color.rgb(0xF2, 0xC4, 0xD0)
        if (g >= 3f && wilt < 0.85f) {
            if (g >= 7f) {
                val pr = 9f * (1 - 0.6f * wilt)
                for (i in 0 until 5) {
                    val a = ta + i * (2 * Math.PI / 5).toFloat()
                    oval(canvas, tx + sin(a) * pr * 0.95f, ty - cos(a) * pr * 0.95f, pr * 0.62f, pr * 0.95f, a, petal)
                }
                fill.color = pollen
                canvas.drawCircle(tx, ty, 4.2f * (1 - 0.3f * wilt), fill)
            } else {
                val bs = (g - 2f).coerceIn(0f, 1f)
                oval(canvas, tx + sin(ta) * 5f, ty - cos(ta) * 5f, 5f * bs, 8f * bs, ta, pollen)
            }
        }
        canvas.restore()
    }
}
