package io.doompal.doompal

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.graphics.Typeface
import android.graphics.drawable.AnimatedImageDrawable
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build

/** Doomy's stickers, the memes and the fonts all ship inside the APK under flutter_assets. */
object DoomyAssets {
    private const val ROOT = "flutter_assets/assets/"
    private val bitmaps = HashMap<String, Bitmap>()
    private val fonts = HashMap<String, Typeface>()

    fun bitmap(c: Context, rel: String): Bitmap? {
        bitmaps[rel]?.let { return it }
        return try {
            c.assets.open(ROOT + rel).use { BitmapFactory.decodeStream(it) }?.also { bitmaps[rel] = it }
        } catch (e: Exception) {
            null
        }
    }

    fun doomy(c: Context, expr: String): Bitmap? = bitmap(c, "doomy/$expr.png")

    fun font(c: Context, file: String, fallback: Typeface): Typeface {
        fonts[file]?.let { return it }
        val tf = try {
            Typeface.createFromAsset(c.assets, ROOT + "fonts/" + file)
        } catch (e: Exception) {
            fallback
        }
        fonts[file] = tf
        return tf
    }

    private val IMAGE = listOf(".png", ".jpg", ".jpeg", ".gif", ".webp")

    /** Files in assets/memes or assets/templates. Drop new ones in those folders, no code needed. */
    fun list(c: Context, dir: String): List<String> = try {
        (c.assets.list(ROOT + dir) ?: emptyArray()).filter { f -> IMAGE.any { f.lowercase().endsWith(it) } }
    } catch (e: Exception) {
        emptyList()
    }

    /** GIFs and animated WebP play on Android 9+, everything else is a still image. */
    fun drawable(c: Context, rel: String): Drawable? {
        val lower = rel.lowercase()
        if ((lower.endsWith(".gif") || lower.endsWith(".webp")) && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                val d = ImageDecoder.decodeDrawable(ImageDecoder.createSource(c.assets, ROOT + rel))
                if (d is AnimatedImageDrawable) d.start()
                return d
            } catch (e: Exception) {
                // fall through to a still image
            }
        }
        val b = bitmap(c, rel) ?: return null
        return BitmapDrawable(c.resources, b)
    }
}
