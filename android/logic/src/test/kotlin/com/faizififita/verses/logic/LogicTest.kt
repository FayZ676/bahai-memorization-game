package com.faizififita.verses.logic

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class LogicTest {
    private val repo = File(System.getProperty("repo"))
    private val tokenizer = loadTokenizer(File(repo, "MemorizationGame/Resources/conformer-vocabulary.json").path)

    init {
        PrayerLibrary.load(File(repo, "MemorizationGame/Resources/library.json").readText())
    }

    @Test
    fun noLibraryWordTokenizesToAnUnknownPiece() {
        val words = PrayerLibrary.all.flatMap { WordLayoutStore.tokenize(it.text) }.toSet()
        val unknown = words.filter { 0 in tokenizer.tokenize(it) }
        assertTrue(unknown.isEmpty(), "unknown pieces in: ${unknown.take(20)}")
        System.getProperty("tokenizerOut")?.let { out ->
            File(out).writeText(JsonObject(words.associateWith { word -> JsonArray(tokenizer.tokenize(word).map(::JsonPrimitive)) }).toString())
        }
    }

    @Test
    fun accentsFoldToPlainLetters() {
        assertEquals(tokenizer.tokenize("ahmad"), tokenizer.tokenize("Aḥmad"))
        assertEquals(tokenizer.tokenize("ali"), tokenizer.tokenize("‘Alí"))
        assertEquals(tokenizer.tokenize("bahaullah"), tokenizer.tokenize("Bahá’u’lláh"))
    }

    @Test
    fun meaningIsNotForgiven() {
        for ((said, written) in listOf("my" to "Thy", "me" to "Thee", "myself" to "Thyself")) {
            assertTrue(tokenizer.tokenize(said) != tokenizer.tokenize(written), "$said must not match $written")
        }
    }

    @Test
    fun wordLayoutSplitsInternalHyphensAndParagraphs() {
        val layout = WordLayoutStore.layout("the Self-Subsisting.\nSecond line here")
        assertEquals(listOf("the", "Self", "-Subsisting.", "Second", "line", "here"), layout.words)
        assertEquals(listOf(0..2, 3..5), layout.paragraphs)
    }

    @Test
    fun hiddenWordsFollowAnEdit() {
        val remapped = HiddenWordAlignment.remap(listOf("O", "my", "God"), setOf(2), listOf("O", "my", "dear", "God"))
        assertEquals(setOf(3), remapped)
    }

    @Test
    fun achievementsAllMatchTheLibrary() {
        assertTrue(AchievementCatalog.problems.isEmpty(), AchievementCatalog.problems.joinToString("\n"))
    }

    @Test
    fun searchFindsAHiddenWordByItsOpening() {
        val hits = FuzzySearch.rank("O Son of Spirit")
        assertTrue(hits.isNotEmpty())
        assertTrue(hits.take(5).any { it.prayer.collection == PrayerLibrary.HIDDEN_WORDS_COLLECTION })
        val typo = FuzzySearch.rank("forgivness")
        assertTrue(typo.isNotEmpty(), "a misspelling still finds prayers")
    }

    @Test
    fun percentNeverRoundsToTheEnds() {
        assertEquals("1%", Percent.label(0.001))
        assertEquals("99%", Percent.label(0.999))
        assertEquals("100%", Percent.label(1.0))
    }

    @Test
    fun passagesRoundTripThroughJson() {
        val passage = Passage(title = "T", text = "a b\nc", hiddenWords = setOf(1, 2))
        val json = Json { encodeDefaults = true }
        val back = json.decodeFromString(Snapshot.serializer(), json.encodeToString(Snapshot.serializer(), Snapshot(listOf(passage))))
        assertEquals(passage, back.passages.single())
        assertEquals(3, back.passages.single().wordCount)
        val old = Json { ignoreUnknownKeys = true }.decodeFromString(Snapshot.serializer(), """{"passages":[{"id":"x","title":"Old","text":"a"}]}""")
        assertEquals(emptySet(), old.passages.single().hiddenWords)
        assertTrue(Json.parseToJsonElement(json.encodeToString(Snapshot.serializer(), Snapshot())).jsonObject.containsKey("settings"))
    }
}
