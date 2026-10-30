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
}
