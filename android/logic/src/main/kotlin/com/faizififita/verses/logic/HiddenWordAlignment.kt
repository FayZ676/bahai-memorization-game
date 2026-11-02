package com.faizififita.verses.logic

object HiddenWordAlignment {
    fun remap(oldWords: List<String>, hidden: Set<Int>, newWords: List<String>): Set<Int> {
        if (oldWords == newWords) return hidden
        if (oldWords.isEmpty() || newWords.isEmpty() || hidden.isEmpty()) return emptySet()

        val old = oldWords.map { it.lowercase() }
        val new = newWords.map { it.lowercase() }

        val lengths = Array(old.size + 1) { IntArray(new.size + 1) }
        for (i in old.size - 1 downTo 0) {
            for (j in new.size - 1 downTo 0) {
                lengths[i][j] = if (old[i] == new[j]) lengths[i + 1][j + 1] + 1
                else maxOf(lengths[i + 1][j], lengths[i][j + 1])
            }
        }

        val remapped = mutableSetOf<Int>()
        var i = 0
        var j = 0
        while (i < old.size && j < new.size) {
            when {
                old[i] == new[j] -> {
                    if (i in hidden) remapped += j
                    i++
                    j++
                }
                lengths[i + 1][j] >= lengths[i][j + 1] -> i++
                else -> j++
            }
        }
        return remapped
    }
}
