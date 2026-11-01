package io.doompal.doompal

/** Everything Doomy says on the overlays, in Gen Alpha. Roasts the habit, never the person. */
object DoomyLines {
    private val rnd = java.util.Random()

    fun <T> pick(list: List<T>): T = list[rnd.nextInt(list.size)]

    val gateOpen: List<List<String>> = listOf(
        listOf("boi boi.", "no reels?", "why u scrolling"),
        listOf("yo yo yo.", "u said NO reels today fr", "what happened to the plan"),
        listOf("hold up bro.", "we lockin or we scrollin?"),
        listOf("bro really opened Shorts like it's a personality", "(it's not)"),
        listOf("sus.", "ur thumb is acting out of pocket rn")
    )

    fun gateAgain(min: Int): List<String> =
        listOf("back already?? it's been " + min + " min.", "doomy sees everything. i'm him.")

    val riskLine = listOf("also it's ur danger hour fr.", "u always spiral around now. i checked.")

    const val PLEASE = "pls let me scroll 🥺"
    const val OUT = "ok ok i'm out"
    val gateNo = listOf("fuh naw.", "but okay then.", "WATCH THIS")
    val proud = listOf(
        listOf("W. big W.", "go touch grass, report back"),
        listOf("say less. aura +500", "proud of u fr fr")
    )

    val limitOpen: List<List<String>> = listOf(
        listOf("okay bud,", "time to pack it up now.", "no more reels."),
        listOf("ur cooked.", "limit hit. we're done here."),
        listOf("L + ratio + no more Shorts", "go outside bro")
    )

    fun begAsk(n: Int): String = "pls doomy just " + n + " more 🙏"

    val begReply: List<List<String>> = listOf(
        listOf("begging??", "in this economy??", "fine. WATCH THIS"),
        listOf("u said that last time bro.", "WATCH THIS"),
        listOf("ugh.", "ok but u gotta sit thru this first")
    )

    val noBegs = listOf("no more begging today.", "doomy has standards. aura matters.")
    val bedtime = listOf("it's bedtime bro.", "Shorts are asleep. u should be too.", "sleep = free glow up")

    val eyeBreak = listOf(
        "eye break bro. look at something far away for 20 sec. ur eyeballs are begging",
        "20 min straight?? blink. stretch. drink water. then we talk",
        "ur eyes called. they want a break. 20 sec, look out the window"
    )

    fun milestone(n: Int, noun: String, mins: Int): String {
        val options = mutableListOf(
            "$n $noun?? ur thumb is built different",
            "$n already?? ur brain is lowkey buffering",
            "$n $noun and none of them paid u",
            "$n. doomy is taking notes 📝",
            "ur screen time report is gonna be cooked ($n)",
            "$n $noun deep. touch grass speedrun any%"
        )
        if (mins >= 10) options.add("that's $mins min. u could've boiled " + (mins / 10) + " eggs")
        else if (mins >= 2) options.add("that's $mins min. that's like " + (mins * 2 / 7).coerceAtLeast(1) + " whole songs")
        return pick(options)
    }

    class Ad(val title: String, val sub: String)

    val ads = listOf(
        Ad("GRASS™", "now available outside. touch it fr. zero lag."),
        Ad("SLEEP", "the original endless scroll. 8 hours. zero ads. big aura."),
        Ad("YOUR MOM", "she called. not about the reel. about the dishes."),
        Ad("THE CEILING", "same content as Shorts. zero regret."),
        Ad("WATER", "hydrate or diedrate. sponsored by ur kidneys."),
        Ad("A BOOK", "like reels but the plot actually makes sense."),
        Ad("STRETCHING", "ur spine filed a complaint."),
        Ad("FRIENDS", "real ones. they text back. probably."),
        Ad("A WALK", "the only scroll that's good for u."),
        Ad("SUNLIGHT", "free vitamin D. no subscription.")
    )

    val punchlines = listOf(
        "BRAIN.EXE HAS STOPPED",
        "ONE MORE (LIE)",
        "IT'S 2AM AND I KNOW 40 DANCES",
        "AURA: -9000",
        "I AM SO COOKED",
        "THUMB TIRED. ME NOT YET",
        "NPC BEHAVIOR"
    )
}
