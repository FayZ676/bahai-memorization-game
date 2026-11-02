package com.faizififita.verses.logic

data class WordLayout(val words: List<String>, val paragraphs: List<IntRange>)

object WordLayoutStore {
    private const val CAPACITY = 96
    private val cache = object : LinkedHashMap<String, WordLayout>(CAPACITY, 0.75f, false) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, WordLayout>?) = size > CAPACITY
    }

    fun layout(text: String): WordLayout {
        synchronized(cache) { cache[text]?.let { return it } }
        val built = build(text)
        synchronized(cache) { cache.putIfAbsent(text, built) }
        return built
    }

    fun tokenize(text: String): List<String> =
        text.split(' ', '\n').filter { it.isNotEmpty() }.flatMap(::splitInternalHyphens)

    private fun build(text: String): WordLayout {
        val words = tokenize(text)
        val ranges = mutableListOf<IntRange>()
        var start = 0
        for (paragraph in text.split('\n').filter { it.isNotEmpty() }) {
            val count = tokenize(paragraph).size
            if (count == 0) continue
            ranges += start until start + count
            start += count
        }
        return WordLayout(words, ranges.ifEmpty { listOf(words.indices) })
    }

    private fun splitInternalHyphens(word: String): List<String> {
        val pieces = mutableListOf<String>()
        var pieceStart = 0
        var searchStart = 0
        while (true) {
            val hyphen = word.indexOf('-', searchStart)
            if (hyphen < 0) break
            val afterHyphen = hyphen + 1
            if (hyphen > pieceStart && afterHyphen < word.length) {
                pieces += word.substring(pieceStart, hyphen)
                pieceStart = hyphen
            }
            searchStart = afterHyphen
        }
        pieces += word.substring(pieceStart)
        return pieces
    }
}
