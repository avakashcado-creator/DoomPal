package io.doompal.doompal

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.graphics.drawable.AnimatedImageDrawable
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import java.io.File
import java.io.InputStream

/**
 * The user's own pictures. They are picked with Android's photo picker (no storage permission),
 * copied into DoomPal's private folder on the phone, and never leave it.
 */
object Pictures {
    private const val MAX_PICTURES = 60
    private const val MAX_SIDE = 1080
    private const val MAX_ANIMATED_BYTES = 10L * 1024 * 1024
    private var seq = 0

    private val EXT = listOf(".jpg", ".png", ".gif", ".webp")

    private fun dir(c: Context): File {
        val d = File(c.filesDir, "pictures")
        d.mkdirs()
        return d
    }

    fun list(c: Context): List<File> {
        val files = dir(c).listFiles() ?: return emptyList()
        return files.filter { f -> f.isFile && EXT.any { f.name.endsWith(it) } }.sortedBy { it.name }
    }

    fun remove(c: Context, path: String): Boolean {
        val f = File(path)
        // only ever delete files inside our own folder
        val root = dir(c).canonicalPath + File.separator
        if (!f.canonicalPath.startsWith(root)) return false
        return f.delete()
    }

    fun clear(c: Context) {
        for (f in list(c)) f.delete()
    }

    /** Copies one picked picture into the private folder. Returns false if it was skipped. */
    fun import(c: Context, uri: Uri): Boolean {
        if (list(c).size >= MAX_PICTURES) return false
        return try {
            val cr = c.contentResolver
            val mime = cr.getType(uri) ?: ""
            val base = System.currentTimeMillis().toString() + "_" + (seq++)
            if (mime == "image/gif" || mime == "image/webp") {
                // keep as is so animations survive
                val out = File(dir(c), base + (if (mime == "image/gif") ".gif" else ".webp"))
                val input = cr.openInputStream(uri) ?: return false
                val ok = input.use { copyLimited(it, out, MAX_ANIMATED_BYTES) }
                if (!ok) out.delete()
                ok
            } else {
                val bmp = decode(c, uri) ?: return false
                val png = mime == "image/png"
                val out = File(dir(c), base + (if (png) ".png" else ".jpg"))
                out.outputStream().use { o ->
                    if (png) bmp.compress(Bitmap.CompressFormat.PNG, 100, o)
                    else bmp.compress(Bitmap.CompressFormat.JPEG, 88, o)
                }
                bmp.recycle()
                true
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun copyLimited(input: InputStream, out: File, limit: Long): Boolean {
        var total = 0L
        val buf = ByteArray(16 * 1024)
        out.outputStream().use { o ->
            while (true) {
                val n = input.read(buf)
                if (n < 0) break
                total += n
                if (total > limit) return false
                o.write(buf, 0, n)
            }
        }
        return true
    }

    /** Decodes a picked picture, scaled so its longest side is at most 1080 px. */
    private fun decode(c: Context, uri: Uri): Bitmap? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val src = ImageDecoder.createSource(c.contentResolver, uri)
            return ImageDecoder.decodeBitmap(src) { decoder, info, _ ->
                val w = info.size.width
                val h = info.size.height
                val longest = maxOf(w, h)
                if (longest > MAX_SIDE) {
                    val k = MAX_SIDE.toFloat() / longest
                    decoder.setTargetSize(maxOf(1, (w * k).toInt()), maxOf(1, (h * k).toInt()))
                }
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            }
        }
        val bounds = BitmapFactory.Options()
        bounds.inJustDecodeBounds = true
        c.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= MAX_SIDE) sample *= 2
        val opts = BitmapFactory.Options()
        opts.inSampleSize = sample
        return c.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opts) }
    }

    /** A drawable for showing the picture. GIFs and animated WebP play on Android 9 and newer. */
    fun drawable(c: Context, f: File): Drawable? {
        val name = f.name
        if ((name.endsWith(".gif") || name.endsWith(".webp")) && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                val d = ImageDecoder.decodeDrawable(ImageDecoder.createSource(f))
                if (d is AnimatedImageDrawable) d.start()
                return d
            } catch (e: Exception) {
                // fall back to a still image below
            }
        }
        val b = BitmapFactory.decodeFile(f.absolutePath) ?: return null
        return BitmapDrawable(c.resources, b)
    }
}
