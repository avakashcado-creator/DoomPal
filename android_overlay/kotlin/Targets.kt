package io.doompal.doompal

/** The apps DoomPal watches. Keys must match lib/apps.dart. */
object Targets {
    class App(
        val key: String,
        val label: String,
        val packages: List<String>,
        /** If a view id on screen contains one of these, we are inside the reels screen. */
        val keywords: List<String>
    )

    // Note: inside Instagram, "reel" means STORIES and "clips" means REELS. Do not add "reel_viewer" here.
    val all: List<App> = listOf(
        App(
            "instagram", "Instagram Reels",
            listOf("com.instagram.android", "com.instagram.lite"),
            listOf("clips_viewer")
        ),
        App(
            "youtube", "YouTube Shorts",
            listOf("com.google.android.youtube"),
            listOf("reel_recycler", "reel_player", "reel_watch", "shorts_player", "shorts_container")
        ),
        App(
            "facebook", "Facebook Reels",
            listOf("com.facebook.katana", "com.facebook.lite"),
            listOf("reels_viewer", "reel_viewer", "fb_reels", "reels_tab_content")
        ),
        App(
            "snapchat", "Snapchat Spotlight",
            listOf("com.snapchat.android"),
            listOf("spotlight")
        )
    )

    fun byPackage(pkg: String): App? = all.firstOrNull { it.packages.contains(pkg) }

    fun matches(app: App, viewId: String): Boolean {
        for (kw in app.keywords) {
            if (viewId.contains(kw)) return true
        }
        return false
    }
}
