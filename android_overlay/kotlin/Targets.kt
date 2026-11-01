package io.doompal.doompal

/** The apps DoomPal watches. Keys must match lib/apps.dart. */
object Targets {
    class App(
        val key: String,
        val label: String,
        /** Word used in messages: "Shorts", "reels"... */
        val noun: String,
        val packages: List<String>,
        /** If a view id on screen contains one of these, we are inside the reels screen. */
        val keywords: List<String>,
        /** true = only count when the view that scrolled IS the reels pager (ignores comment panels etc.). */
        val strictSource: Boolean,
        /** Tracked until the user switches it off in Limits. */
        val defaultOn: Boolean
    )

    // Note: inside Instagram's code, "reel" means STORIES and "clips" means REELS. Do not add "reel_viewer" there.
    val all: List<App> = listOf(
        App(
            "youtube", "YouTube Shorts", "Shorts",
            listOf("com.google.android.youtube"),
            listOf("reel_recycler", "reel_player", "reel_watch", "shorts_player", "shorts_container"),
            true, true
        ),
        App(
            "instagram", "Instagram Reels", "reels",
            listOf("com.instagram.android", "com.instagram.lite"),
            listOf("clips_viewer"),
            false, true
        ),
        App(
            "facebook", "Facebook Reels", "reels",
            listOf("com.facebook.katana", "com.facebook.lite"),
            listOf("reels_viewer", "reel_viewer", "fb_reels", "reels_tab_content"),
            false, false
        ),
        App(
            "snapchat", "Snapchat Spotlight", "Spotlights",
            listOf("com.snapchat.android"),
            listOf("spotlight"),
            false, false
        )
    )

    fun byPackage(pkg: String): App? = all.firstOrNull { it.packages.contains(pkg) }

    fun byKey(key: String): App? = all.firstOrNull { it.key == key }

    fun matches(app: App, viewId: String): Boolean {
        for (kw in app.keywords) {
            if (viewId.contains(kw)) return true
        }
        return false
    }
}
