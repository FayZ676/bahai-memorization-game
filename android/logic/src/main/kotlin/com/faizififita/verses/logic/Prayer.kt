package com.faizififita.verses.logic

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
data class Prayer(
    val id: Long,
    val author: String,
    val heading: String,
    val text: String,
    val tags: List<String>,
    val primaryTag: String,
    val collection: String,
    val section: String,
) {
    val title: String by lazy { AutoTitle.from(heading, text) }

    val wordCount: Int by lazy { text.split(' ', '\n').count { it.isNotEmpty() } }

    val deepestSection: String
        get() = if (primaryTag.isEmpty() || primaryTag == section) section else primaryTag

    val path: String
        get() = listOf(collection, section, primaryTag)
            .filter { it.isNotEmpty() }
            .fold(mutableListOf<String>()) { parts, part ->
                if (parts.lastOrNull() != part) parts += part
                parts
            }
            .joinToString(" / ")
}

object PrayerLibrary {
    data class Category(val name: String, val prayers: List<Prayer>)

    data class Section(val name: String, val categories: List<Category>) {
        val prayerCount: Int get() = categories.sumOf { it.prayers.size }
    }

    data class Collection(val name: String, val sections: List<Section>) {
        val prayerCount: Int get() = sections.sumOf { it.prayerCount }
    }

    const val HIDDEN_WORDS_COLLECTION = "The Hidden Words"

    @Serializable
    private class Entries(val entries: List<Prayer>)

    var all: List<Prayer> = emptyList()
        private set
    var collections: List<Collection> = emptyList()
        private set
    private var byID: Map<Long, Prayer> = emptyMap()

    fun load(json: String) {
        all = Json { ignoreUnknownKeys = true }.decodeFromString(Entries.serializer(), json).entries
        byID = all.reversed().associateBy { it.id }
        collections = all.groupOrdered { it.collection }.map { (name, prayers) ->
            Collection(name, prayers.groupOrdered { it.section }.map { (sectionName, sectionPrayers) ->
                Section(sectionName, sectionPrayers.groupOrdered { it.primaryTag }.map { (category, categoryPrayers) ->
                    Category(category, categoryPrayers)
                })
            })
        }
    }

    fun prayer(id: Long): Prayer? = byID[id]

    fun collection(named: String): Collection? = collections.firstOrNull { it.name == named }

    fun section(named: String): Section? =
        collections.firstNotNullOfOrNull { collection -> collection.sections.firstOrNull { it.name == named } }

    fun category(named: String, inSection: String): Category? =
        section(inSection)?.categories?.firstOrNull { it.name == named }

    private fun List<Prayer>.groupOrdered(key: (Prayer) -> String): List<Pair<String, List<Prayer>>> {
        val buckets = LinkedHashMap<String, MutableList<Prayer>>()
        for (prayer in this) buckets.getOrPut(key(prayer)) { mutableListOf() } += prayer
        return buckets.map { it.key to it.value }
    }
}
