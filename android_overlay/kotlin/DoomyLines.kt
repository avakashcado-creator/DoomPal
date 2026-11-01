package io.doompal.doompal

/** Everything Doomy says on the overlays. Keep it funny, never mean about who someone is. */
object DoomyLines {
    private val rnd = java.util.Random()

    fun <T> pick(list: List<T>): T = list[rnd.nextInt(list.size)]

    val gateOpen: List<List<String>> = listOf(
        listOf("boi boi.", "no reels?", "why u scrolling"),
        listOf("oh we're back?", "already??"),
        listOf("bro opened Shorts like they owe him money"),
        listOf("hold up.", "where u think ur going")
    )

    fun gateAgain(min: Int): List<String> = listOf("still here?", "it's been " + min + " min. i'm counting. obviously.")

    const val PLEASE = "please let me scroll 🥺"
    const val OUT = "ok fine, i'm out"
    val gateNo = listOf("fuh naw.", "but okay then.", "WATCH THIS")
    val proud = listOf(listOf("W.", "proud of u fr"), listOf("say less.", "go do something cool"))

    val limitOpen: List<List<String>> = listOf(
        listOf("okay bud,", "time to pack it up now.", "no more reels."),
        listOf("that's it.", "the Shorts machine is closed.", "go touch something."),
        listOf("nah we're done.", "pack it up.")
    )

    fun begAsk(n: Int): String = "please doomy just " + n + " more 🙏"

    val begReply: List<List<String>> = listOf(
        listOf("begging?", "in this economy?", "fine. WATCH THIS"),
        listOf("more??", "u said that last time.", "WATCH THIS"),
        listOf("ugh.", "okay but u gotta watch this first")
    )

    val noBegs = listOf("no more begging today.", "i have standards.")
    val bedtime = listOf("it's bedtime.", "Shorts are asleep. u should be too.")

    fun milestone(n: Int, noun: String, mins: Int): String {
        val options = mutableListOf(
            "$n $noun. ur thumb is getting buff",
            "$n already?? blink twice if u need help",
            "$n $noun and none of them paid u",
            "$n. doomy is taking notes 📝",
            "ur screen time report is gonna be crazy ($n)"
        )
        if (mins >= 10) options.add("that's $mins min. u could've boiled " + (mins / 10) + " eggs")
        else if (mins >= 2) options.add("that's $mins min. that's like " + (mins * 2 / 7).coerceAtLeast(1) + " whole songs")
        return pick(options)
    }

    class Ad(val title: String, val sub: String)

    val ads = listOf(
        Ad("GRASS™", "now available outside. touch it for free."),
        Ad("SLEEP", "the original endless scroll. 8 hours, zero ads."),
        Ad("YOUR MOM", "she called. not about the reel. about the dishes."),
        Ad("THE CEILING", "same content as Shorts. zero regret."),
        Ad("WATER", "hydrate or diedrate. sponsored by ur kidneys."),
        Ad("A BOOK", "like reels but the plot actually makes sense."),
        Ad("STRETCHING", "ur spine filed a complaint."),
        Ad("FRIENDS", "real ones. they text back. probably."),
        Ad("A WALK", "the only scroll that's good for u.")
    )

    val punchlines = listOf(
        "BRAIN.EXE HAS STOPPED",
        "ONE MORE (LIE)",
        "IT'S 2AM AND I KNOW 40 DANCES",
        "THUMB TIRED. ME NOT YET",
        "THIS IS FINE",
        "I SHOULD BE ASLEEP"
    )
}
