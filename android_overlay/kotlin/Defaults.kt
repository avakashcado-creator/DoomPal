package io.doompal.doompal

/** Settings start restrictive. Anything not listed here defaults to whatever the caller passes. */
object Defaults {
    private val map: Map<String, Int> = mapOf(
        "total" to 50,
        "quiet" to 1, "quietStart" to 23, "quietEnd" to 6,
        "lock" to 1, "lockHours" to 24,
        "coach" to 1, "eyeBreak" to 1,
        "maxSnooze" to 1, "begReels" to 5, "adSecs" to 10,
        "nudge" to 5, "gate" to 1, "gateEvery" to 15, "counter" to 1,
        "guest" to 1, "guestMins" to 15, "guestPerDay" to 1,
        "hard" to 0, "lenient" to 0, "debug" to 0, "terms" to 0
    )

    fun of(key: String): Int? = map[key]
    fun all(): Map<String, Int> = map
}
