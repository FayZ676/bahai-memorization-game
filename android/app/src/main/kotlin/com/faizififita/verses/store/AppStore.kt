package com.faizififita.verses.store

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.faizififita.verses.BuildConfig
import com.faizififita.verses.logic.AppSettings
import com.faizififita.verses.logic.HiddenWordAlignment
import com.faizififita.verses.logic.Passage
import com.faizififita.verses.logic.Snapshot
import com.faizififita.verses.support.ReminderScheduler
import kotlinx.serialization.json.Json
import java.io.File
import java.util.concurrent.Executors

class AppStore(private val context: Context) {
    private val file = File(context.filesDir, "verses.json")
    private val writer = Executors.newSingleThreadExecutor()
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    var passages by mutableStateOf<List<Passage>>(emptyList())
        private set
    var settings by mutableStateOf(AppSettings())
        private set
    var passageJustMemorized by mutableStateOf(false)

    init {
        val snapshot = runCatching { json.decodeFromString(Snapshot.serializer(), file.readText()) }.getOrNull()
        if (snapshot != null) {
            passages = snapshot.passages
            settings = snapshot.settings
        } else {
            settings = AppSettings(lastSeenReleaseNotesVersion = BuildConfig.VERSION_NAME)
        }
    }

    fun updateSettings(change: (AppSettings) -> AppSettings) {
        val old = settings
        settings = change(old)
        persist()
        if (old.reminderEnabled != settings.reminderEnabled || old.reminders != settings.reminders) {
            ReminderScheduler.sync(context, settings)
        }
    }

    fun passage(id: String): Passage? = passages.firstOrNull { it.id == id }

    private val passagesSorted: List<Passage>
        get() = passages.sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it.title })

    val activePassages: List<Passage> get() = passagesSorted.filter { !it.isArchived }

    val archivedPassages: List<Passage> get() = passagesSorted.filter { it.isArchived }

    val memorizedPassageIDs: Set<String> get() = passages.filter { it.isMemorized }.map { it.id }.toSet()

    fun passageForPrayer(prayerID: Long): Passage? = passages.firstOrNull { it.sourceID == prayerID }

    fun createPassage(title: String, text: String, author: String? = null, section: String? = null, sourceID: Long? = null) {
        passages = passages + Passage(title = title.trim(), author = author, section = section, sourceID = sourceID, text = text)
        persist()
    }

    fun updatePassage(passage: Passage, title: String, text: String) {
        val old = passage(passage.id) ?: return
        replace(old.copy(
            title = title.trim(),
            text = text,
            hiddenWords = HiddenWordAlignment.remap(old.words, old.hiddenWords, Passage.tokens(text)),
        ))
        persist()
    }

    fun setArchived(passage: Passage, archived: Boolean) {
        val current = passage(passage.id) ?: return
        replace(current.copy(isArchived = archived))
        persist()
    }

    fun deletePassage(passage: Passage) {
        passages = passages.filter { it.id != passage.id }
        persist()
    }

    fun setAllWords(passage: Passage, hidden: Boolean) = mutate(passage) { it.settingAllWords(hidden) }

    fun hideRandomWords(passage: Passage, count: Int, among: Set<Int>): Set<Int> {
        val current = passage(passage.id) ?: return emptySet()
        val candidates = among.intersect(current.words.indices.toSet()) - current.hiddenWords
        if (candidates.isEmpty()) return emptySet()
        val chosen = candidates.shuffled().take(count).toSet()
        mutate(passage) { it.copy(hiddenWords = it.hiddenWords + chosen) }
        return chosen
    }

    fun toggleWord(passage: Passage, index: Int) = mutate(passage) { it.togglingWord(index) }

    fun markReviewRequested() = updateSettings { it.copy(lastReviewRequestVersion = BuildConfig.VERSION_NAME) }

    fun markReleaseNotesSeen() = updateSettings { it.copy(lastSeenReleaseNotesVersion = BuildConfig.VERSION_NAME) }

    private fun mutate(passage: Passage, change: (Passage) -> Passage) {
        val current = passage(passage.id) ?: return
        val memorizedPassagesBefore = memorizedPassageIDs
        replace(change(current))
        if ((memorizedPassageIDs - memorizedPassagesBefore).isNotEmpty()) passageJustMemorized = true
        persist()
    }

    private fun replace(passage: Passage) {
        passages = passages.map { if (it.id == passage.id) passage else it }
    }

    private fun persist() {
        val text = json.encodeToString(Snapshot.serializer(), Snapshot(passages, settings))
        writer.execute {
            val temporary = File(file.parentFile, "${file.name}.tmp")
            temporary.writeText(text)
            temporary.renameTo(file)
        }
    }
}
