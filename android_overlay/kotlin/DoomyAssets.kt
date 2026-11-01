package io.doompal.doompal

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Typeface

/** Doomy's stickers and the fonts ship inside the APK under flutter_assets. */
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
}
