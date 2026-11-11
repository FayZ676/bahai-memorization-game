package com.faizififita.verses.logic

import kotlinx.serialization.Serializable
import kotlinx.serialization.Transient
import java.util.UUID

@Serializable
data class Passage(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val dateAdded: Long = System.currentTimeMillis(),
    val author: String? = null,
    val section: String? = null,
    val sourceID: Long? = null,
    val isArchived: Boolean = false,
    val text: String = "",
    val hiddenWords: Set<Int> = emptySet(),
    val lastPracticed: Long? = null,
) {
    @Transient
    private val layout: WordLayout = WordLayoutStore.layout(text)

    val words: List<String> get() = layout.words
    val paragraphs: List<IntRange> get() = layout.paragraphs
    val wordCount: Int get() = layout.words.size

    val hiddenFraction: Double
        get() = if (wordCount > 0) hiddenWords.size.toDouble() / wordCount else 0.0

    val isMemorized: Boolean get() = wordCount > 0 && hiddenWords.size == wordCount

    fun recitableIndices(from: Int): List<Int> {
        val owed = hiddenWords.filter { it >= from }
        if (owed.isNotEmpty()) return owed.sorted()
        return words.indices.filter { it >= from && words[it].any(Char::isLetter) }
    }

    fun togglingWord(index: Int): Passage =
        copy(hiddenWords = if (index in hiddenWords) hiddenWords - index else hiddenWords + index)

    fun settingAllWords(hidden: Boolean): Passage =
        copy(hiddenWords = if (hidden) (0 until wordCount).toSet() else emptySet())

    val sourcePath: String?
        get() {
            sourceID?.let { PrayerLibrary.prayer(it) }?.let { return it.path }
            if (section == null || section.lowercase().startsWith("http")) return null
            return section
        }

    companion object {
        fun tokens(text: String): List<String> = WordLayoutStore.layout(text).words

        fun paragraphsOf(content: String): List<String> =
            content.split('\n').map { it.trim(' ', '\t') }.filter { it.isNotEmpty() }
    }
}

@Serializable
enum class AppTheme(val label: String) {
    System("System"),
    Light("Light"),
    Dark("Dark"),
}

@Serializable
enum class FontSize(val label: String, val scale: Float) {
    Small("Small", 0.85f),
    Medium("Medium", 1f),
    Large("Large", 1.2f),
}

@Serializable
enum class Difficulty(val label: String) {
    Lines("Lines"),
    Blank("Blank"),
}

@Serializable
data class Reminder(
    val id: String = UUID.randomUUID().toString(),
    val minuteOfDay: Int = 9 * 60,
    val message: String = AppSettings.DEFAULT_REMINDER_MESSAGE,
)

@Serializable
data class AppSettings(
    val reminderEnabled: Boolean = false,
    val reminders: List<Reminder> = listOf(Reminder()),
    val appTheme: AppTheme = AppTheme.Light,
    val fontSize: FontSize = FontSize.Medium,
    val hasSeenWelcomeTour: Boolean = false,
    val randomHideCount: Int = 2,
    val difficulty: Difficulty = Difficulty.Lines,
    val lastReviewRequestVersion: String? = null,
    val lastSeenReleaseNotesVersion: String? = null,
) {
    companion object {
        const val DEFAULT_REMINDER_MESSAGE = "A few minutes with your passages keeps them fresh."
    }
}

@Serializable
data class Snapshot(val passages: List<Passage> = emptyList(), val settings: AppSettings = AppSettings())

object Percent {
    fun label(fraction: Double): String = "${value(fraction)}%"

    fun value(fraction: Double): Int {
        val clamped = fraction.coerceIn(0.0, 1.0)
        return when (clamped) {
            0.0 -> 0
            1.0 -> 100
            else -> Math.round(clamped * 100).toInt().coerceIn(1, 99)
        }
    }
}
