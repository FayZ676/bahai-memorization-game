package com.faizififita.verses.logic

sealed interface BrowseRoute {
    data object Browse : BrowseRoute
    data class Collection(val name: String) : BrowseRoute
    data class Section(val name: String) : BrowseRoute
    data class Category(val section: String, val name: String) : BrowseRoute
    data class Prayer(val id: Long) : BrowseRoute
}

sealed interface AchievementRequirement {
    data class Section(val name: String) : AchievementRequirement
    data class Category(val name: String, val section: String) : AchievementRequirement
    data class Count(val needed: Int, val collection: String) : AchievementRequirement

    val count: Int
        get() = if (this is Count) needed else 1

    val prayerIDs: Set<Long>
        get() = when (this) {
            is Section -> ids { it.section == name }
            is Category -> ids { it.section == section && it.primaryTag == name }
            is Count -> ids { it.collection == collection }
        }

    val route: BrowseRoute
        get() = when (this) {
            is Section -> BrowseRoute.Section(name)
            is Category -> BrowseRoute.Category(section, name)
            is Count -> BrowseRoute.Collection(collection)
        }

    private fun ids(predicate: (Prayer) -> Boolean): Set<Long> =
        PrayerLibrary.all.filter(predicate).map { it.id }.toSet()
}

enum class AchievementSymbol { Hands, Sunrise, Heart, HandRaised, House, Moon, Book }

data class Achievement(
    val title: String,
    val symbol: AchievementSymbol,
    val condition: String,
    val requirement: AchievementRequirement,
) {
    val id: String = title.lowercase().split(Regex("[^\\p{L}\\p{N}]+")).filter { it.isNotEmpty() }.joinToString("-")

    fun matchedCount(memorized: Set<Long>): Int = memorized.intersect(requirement.prayerIDs).size

    fun isEarned(memorized: Set<Long>): Boolean = matchedCount(memorized) >= requirement.count
}

object AchievementCatalog {
    val all = listOf(
        Achievement("Obligatory Prayer", AchievementSymbol.Hands, "Memorize one Obligatory Prayer.",
            AchievementRequirement.Section("Obligatory Prayers")),
        Achievement("Morning Prayer", AchievementSymbol.Sunrise, "Memorize one prayer for the morning.",
            AchievementRequirement.Category("Morning", "General Prayers")),
        Achievement("Healing Prayer", AchievementSymbol.Heart, "Memorize one prayer for healing.",
            AchievementRequirement.Category("Healing", "General Prayers")),
        Achievement("Aid & Assistance Prayer", AchievementSymbol.HandRaised, "Memorize one prayer for aid and assistance.",
            AchievementRequirement.Category("Aid and Assistance", "General Prayers")),
        Achievement("Family Prayer", AchievementSymbol.House, "Memorize one prayer for the family.",
            AchievementRequirement.Category("Families", "General Prayers")),
        Achievement("Fasting Prayer", AchievementSymbol.Moon, "Memorize one prayer for the Fast.",
            AchievementRequirement.Category("The Fast", "Occasional Prayers")),
        Achievement("5 Hidden Words", AchievementSymbol.Book, "Memorize five Hidden Words.",
            AchievementRequirement.Count(5, PrayerLibrary.HIDDEN_WORDS_COLLECTION)),
    )

    val problems: List<String>
        get() {
            val problems = mutableListOf<String>()
            val seen = mutableSetOf<String>()
            for (achievement in all) {
                val label = "“${achievement.title}”"
                if (!seen.add(achievement.id)) problems += "$label collides with another achievement’s title."
                val matches = achievement.requirement.prayerIDs.size
                val needed = achievement.requirement.count
                if (needed < 1) problems += "$label requires $needed prayers."
                else if (matches < needed) problems += "$label needs $needed prayers but its requirement matches $matches in library.json."
            }
            return problems
        }
}
