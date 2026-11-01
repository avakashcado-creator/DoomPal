package io.doompal.doompal

import android.view.accessibility.AccessibilityNodeInfo

object ReelDetector {
    class Scan(val matched: Boolean, val sample: String)

    /** Short, lowercase view id ("clips_viewer_view_pager"), or null if the view has none. */
    fun shortId(node: AccessibilityNodeInfo?): String? {
        val raw = node?.viewIdResourceName ?: return null
        return raw.substringAfter(":id/").lowercase()
    }

    /** Walks the on-screen view tree (max 700 nodes) looking for a view id that belongs to the reels screen. */
    fun scan(root: AccessibilityNodeInfo, app: Targets.App, collectSample: Boolean): Scan {
        val queue = java.util.ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        var visited = 0
        val sample = LinkedHashSet<String>()
        while (visited < 700) {
            val n = queue.poll() ?: break
            visited++
            val id = shortId(n)
            if (id != null) {
                if (collectSample && sample.size < 14) sample.add(id)
                if (Targets.matches(app, id)) return Scan(true, sample.joinToString(","))
            }
            val count = n.childCount
            for (i in 0 until count) {
                val child = n.getChild(i)
                if (child != null) queue.add(child)
            }
        }
        return Scan(false, sample.joinToString(","))
    }

    /** Words that mark a sponsored item when they appear as a separate word in a view id. */
    private val AD_WORDS = setOf("ad", "ads", "sponsored", "sponsor")

    /**
     * Returns a short reason if a sponsored item (an ad) is VISIBLE on screen, otherwise null.
     * Only visible views are checked, because the reels list keeps the next pages loaded off screen.
     */
    fun adReason(root: AccessibilityNodeInfo): String? {
        val queue = java.util.ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        var visited = 0
        while (visited < 700) {
            val n = queue.poll() ?: break
            visited++
            if (!n.isVisibleToUser) continue // skip off-screen pages and everything inside them

            val id = shortId(n)
            if (id != null) {
                val words = id.split("_", ".", "-")
                for (w in words) {
                    if (AD_WORDS.contains(w)) return "id:" + id
                }
            }

            val text = n.text?.toString()?.trim()
            if (text != null && (text.equals("Ad", ignoreCase = true) || text.equals("Sponsored", ignoreCase = true))) {
                return "text:" + text
            }

            val desc = n.contentDescription?.toString()?.lowercase()
            if (desc != null && desc.contains("sponsored")) return "desc:sponsored"

            val count = n.childCount
            for (i in 0 until count) {
                val child = n.getChild(i)
                if (child != null) queue.add(child)
            }
        }
        return null
    }
}
