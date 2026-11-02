package com.faizififita.verses.logic

import java.text.Normalizer
import kotlin.math.pow

data class TextExcerpt(val snippet: String, val highlightInSnippet: IntRange, val rangeInText: IntRange)

data class SearchHit(val prayer: Prayer, val excerpt: TextExcerpt?)

object SearchText {
    fun normalized(value: String): String = tokens(value).joinToString(" ")
    fun tokens(value: String): List<String> = WordIndex.tokens(value).map { it.text }
}

private class SearchDocument(
    val title: String,
    val labels: String,
    val body: String,
    val terms: Set<String>,
    val pairs: Set<String>,
    val fragments: Set<String>,
)

object FuzzySearch {
    const val RESULT_LIMIT = 60

    private const val TITLE_WEIGHT = 1.0
    private const val LABEL_WEIGHT = 0.6
    private const val BODY_WEIGHT = 0.35
    private const val PHRASE_WEIGHT = 0.5
    private const val EXACT_TITLE_BONUS = 0.5
    private const val EXACT_LABEL_BONUS = 0.5
    private const val CONNECTIVE_WEIGHT = 0.35
    private const val COVERAGE_EXPONENT = 1.5
    private const val FAINT_COVERAGE = 0.08
    private const val FRAGMENT_LENGTH = 3
    private const val SPELLING_KEY_LENGTH = 2
    private const val PHRASE_THRESHOLD = 0.45
    private const val TERM_THRESHOLD = 0.3
    private const val TRANSPOSED_SIMILARITY = 0.9
    private const val SHORTEST_FUZZY_TERM = 3
    private const val VARIANT_LIMIT = 6
    private const val PAIR_VARIANT_LIMIT = 3
    private const val MAX_MISSING_CHARACTERS = 2
    private const val MAX_EXTRA_CHARACTERS = 10
    private const val TITLE_LIMIT = 120
    private const val PATTERN_LIMIT = 63
    private const val PROMINENCE_SPAN = 2_000
    private const val DEPTH_PENALTY = 0.3

    private val fuse = Fuse(location = 0, distance = 100, threshold = PHRASE_THRESHOLD, isCaseSensitive = true, tokenize = true)
    private val wordFuse = Fuse(location = 0, distance = 8, threshold = TERM_THRESHOLD, isCaseSensitive = true)

    private val documents: List<SearchDocument> by lazy {
        PrayerLibrary.all.map { prayer ->
            val title = SearchText.normalized(prayer.title.take(TITLE_LIMIT))
            val labels = SearchText.normalized((listOf(prayer.collection, prayer.section, prayer.author) + prayer.tags).joinToString(" "))
            val body = SearchText.normalized(prayer.text)
            val words = "$title $labels $body".split(' ').filter { it.isNotEmpty() }
            SearchDocument(
                title, labels, body,
                words.toSet(),
                words.zipWithNext { a, b -> "$a $b" }.toSet(),
                fragments("$title $labels", FRAGMENT_LENGTH),
            )
        }
    }

    private val knownTerms: Set<String> by lazy { documents.flatMapTo(HashSet()) { it.terms } }

    private val termsBySpellingKey: Map<String, List<String>> by lazy {
        val index = HashMap<String, MutableList<String>>()
        for (term in knownTerms) for (key in fragments(term, SPELLING_KEY_LENGTH)) index.getOrPut(key) { mutableListOf() } += term
        index
    }

    fun prewarm() {
        termsBySpellingKey.size
    }

    private class Spelling(val term: String, val similarity: Double)
    private class Placement(val prominence: Double, val inBody: Boolean)
    private class Scored(val index: Int, val score: Double, val matchedBody: Boolean)

    fun rank(query: String, isCancelled: () -> Boolean = { false }): List<SearchHit> {
        val queryTokens = SearchText.tokens(query.trim())
        if (queryTokens.isEmpty()) return emptyList()

        val spellings = queryTokens.map(::variants)
        val corrected = queryTokens.zip(spellings).joinToString(" ") { (token, options) -> options.firstOrNull()?.term ?: token }
        val queryCarriesMeaning = queryTokens.any(WordIndex::carriesMeaning)
        val weights = queryTokens.map { if (WordIndex.carriesMeaning(it)) 1.0 else CONNECTIVE_WEIGHT }
        val normalized = queryTokens.joinToString(" ").take(PATTERN_LIMIT)
        val queryFragments = fragments(normalized, FRAGMENT_LENGTH)
        val pattern = fuse.createPattern(normalized)

        val scored = mutableListOf<Scored>()
        documents.forEachIndexed { index, document ->
            if (index % 64 == 0 && isCancelled()) return emptyList()
            val found = spellings.map { options -> options.firstOrNull { it.term in document.terms } }
            val coverage = coverage(found, weights)
            val anchors = found.filterNotNull().filter { !queryCarriesMeaning || WordIndex.carriesMeaning(it.term) }
            if (anchors.isEmpty() && document.fragments.intersect(queryFragments).isEmpty()) return@forEachIndexed

            val title = relevance(pattern, document.title)
            val labels = relevance(pattern, document.labels)
            val placement = if (anchors.isEmpty()) null else placement(anchors, document.body)
            val body = coverage * (placement?.prominence ?: 0.0)
            val phrase = adjacency(spellings, document)

            var score = title * TITLE_WEIGHT + labels * LABEL_WEIGHT + body * BODY_WEIGHT + phrase * PHRASE_WEIGHT
            if (contains(normalized, document.title)) score += EXACT_TITLE_BONUS
            if (contains(normalized, document.labels)) score += EXACT_LABEL_BONUS
            score *= maxOf(coverage, FAINT_COVERAGE).pow(COVERAGE_EXPONENT)
            if (score <= 0) return@forEachIndexed
            scored += Scored(index, score, placement?.inBody == true)
        }

        return scored.sortedByDescending { it.score }.take(RESULT_LIMIT).map { entry ->
            val prayer = PrayerLibrary.all[entry.index]
            SearchHit(prayer, if (entry.matchedBody) ExcerptFinder.excerpt(corrected, prayer.text, prayer.id) else null)
        }
    }

    private fun variants(token: String): List<Spelling> {
        if (token in knownTerms) {
            val exact = Spelling(token, 1.0)
            if (!WordIndex.carriesMeaning(token)) return listOf(exact)
            return listOf(exact) + neighbours(token, token)
        }
        val swaps = transpositions(token).filter { it in knownTerms }.map { Spelling(it, TRANSPOSED_SIMILARITY) }
        return swaps + neighbours(token, null)
    }

    private fun transpositions(token: String): List<String> {
        if (token.length <= 1) return emptyList()
        return (0 until token.length - 1).map { index ->
            val letters = token.toCharArray()
            val swap = letters[index]
            letters[index] = letters[index + 1]
            letters[index + 1] = swap
            String(letters)
        }
    }

    private fun neighbours(token: String, exact: String?): List<Spelling> {
        if (token.length < SHORTEST_FUZZY_TERM) return emptyList()
        val pattern = wordFuse.createPattern(token) ?: return emptyList()
        val candidates = HashSet<String>()
        for (key in fragments(token, SPELLING_KEY_LENGTH)) candidates += termsBySpellingKey[key].orEmpty()
        val found = mutableListOf<Spelling>()
        for (term in candidates) {
            if (term == exact || !plausibleLength(term, token)) continue
            val result = wordFuse.search(pattern, term) ?: continue
            found += Spelling(term, 1 - result)
        }
        return found.sortedByDescending { it.similarity }.take(VARIANT_LIMIT)
    }

    private fun plausibleLength(term: String, token: String) =
        term.length + MAX_MISSING_CHARACTERS >= token.length && term.length <= token.length + MAX_EXTRA_CHARACTERS

    private fun fragments(value: String, length: Int): Set<String> {
        val found = HashSet<String>()
        for (word in value.split(' ').filter { it.isNotEmpty() }) {
            if (word.length <= length) {
                found += word
                continue
            }
            for (start in 0..word.length - length) found += word.substring(start, start + length)
        }
        return found
    }

    private fun coverage(found: List<Spelling?>, weights: List<Double>): Double {
        var total = 0.0
        var possible = 0.0
        for ((match, weight) in found.zip(weights)) {
            possible += weight
            total += (match?.similarity ?: 0.0) * weight
        }
        return if (possible > 0) total / possible else 0.0
    }

    private fun adjacency(spellings: List<List<Spelling>>, document: SearchDocument): Double {
        if (spellings.size <= 1) return 0.0
        var joined = 0
        for (offset in 0 until spellings.size - 1) {
            val leading = spellings[offset].take(PAIR_VARIANT_LIMIT)
            val trailing = spellings[offset + 1].take(PAIR_VARIANT_LIMIT)
            if (leading.any { first -> trailing.any { "${first.term} ${it.term}" in document.pairs } }) joined++
        }
        return joined.toDouble() / (spellings.size - 1)
    }

    private fun placement(anchors: List<Spelling>, body: String): Placement? {
        if (body.isEmpty()) return null
        var earliest = Int.MAX_VALUE
        var meaningful = false
        for (match in anchors) {
            val at = body.indexOf(match.term)
            if (at < 0) continue
            if (WordIndex.carriesMeaning(match.term)) meaningful = true
            earliest = minOf(earliest, at)
        }
        if (earliest == Int.MAX_VALUE) return Placement(1 - DEPTH_PENALTY, false)
        val depth = minOf(1.0, earliest.toDouble() / PROMINENCE_SPAN)
        return Placement(1 - depth * DEPTH_PENALTY, meaningful)
    }

    private fun contains(query: String, value: String) = value.isNotEmpty() && value.contains(query)

    private fun relevance(pattern: Fuse.Pattern?, value: String): Double {
        if (value.isEmpty()) return 0.0
        val result = fuse.search(pattern, value) ?: return 0.0
        return 1 - result
    }
}

object ExcerptFinder {
    private const val LEADING_CONTEXT = 110
    private const val TRAILING_CONTEXT = 190
    private val cache = HashMap<Long, WordIndex>()

    fun excerpt(query: String, text: String, textID: Long? = null): TextExcerpt? {
        val words = if (textID != null) synchronized(cache) {
            if (cache.size >= 80 && textID !in cache) cache.clear()
            cache.getOrPut(textID) { WordIndex(text) }
        } else WordIndex(text)
        val match = locate(query, words) ?: return null
        return snippet(match, text)
    }

    private fun locate(query: String, words: WordIndex): IntRange? {
        val terms = WordIndex.tokens(query).map { it.text }
        if (terms.isEmpty()) return null
        if (terms.size == 1) {
            if (!WordIndex.carriesMeaning(terms[0])) return null
            val hit = words.positions(terms[0]).firstOrNull() ?: return null
            return words.sourceRange(hit..hit)
        }
        val run = words.longestRun(terms)
        val window = words.tightestWindow(terms)
        val strongest = listOfNotNull(run, window).maxByOrNull { it.terms }
        val chosen = if (strongest != null && strongest.terms >= 2) strongest else words.rarestTerm(terms) ?: strongest
        chosen ?: return null
        return words.sourceRange(chosen.range)
    }

    private fun snippet(match: IntRange, text: String): TextExcerpt {
        val start = boundaryBefore(match.first, text)
        val end = boundaryAfter(match.last + 1, text)
        var snippet = text.substring(start, end).replace('\n', ' ')
        var highlightStart = match.first - start
        if (start > 0) {
            snippet = "…$snippet"
            highlightStart += 1
        }
        if (end < text.length) snippet += "…"
        val highlightEnd = minOf(highlightStart + (match.last + 1 - match.first), snippet.length)
        return TextExcerpt(snippet, highlightStart until maxOf(highlightStart, highlightEnd), match)
    }

    private fun boundaryBefore(index: Int, text: String): Int {
        val floor = maxOf(0, index - LEADING_CONTEXT)
        var cursor = index
        while (cursor > floor) {
            if (isSentenceEnd(text[cursor - 1])) return skippingSpace(cursor, text)
            cursor--
        }
        if (floor <= 0) return 0
        var wordStart = floor
        while (wordStart < index && !text[wordStart].isWhitespace()) wordStart++
        return skippingSpace(wordStart, text)
    }

    private fun boundaryAfter(index: Int, text: String): Int {
        val ceiling = minOf(text.length, index + TRAILING_CONTEXT)
        var cursor = index
        while (cursor < ceiling) {
            if (isSentenceEnd(text[cursor])) return cursor + 1
            cursor++
        }
        if (ceiling >= text.length) return text.length
        var wordEnd = ceiling
        while (wordEnd > index && !text[wordEnd - 1].isWhitespace()) wordEnd--
        return wordEnd
    }

    private fun skippingSpace(index: Int, text: String): Int {
        var cursor = index
        while (cursor < text.length && text[cursor].isWhitespace()) cursor++
        return cursor
    }

    private fun isSentenceEnd(c: Char) = c == '.' || c == '!' || c == '?' || c == '\n'
}

class WordIndex(text: String) {
    data class Word(val text: String, val start: Int, val end: Int)
    data class Match(val range: IntRange, val terms: Int)

    val words: List<Word> = tokens(text)
    private val positionsByWord: Map<String, List<Int>> =
        HashMap<String, MutableList<Int>>().also { map -> words.forEachIndexed { i, w -> map.getOrPut(w.text) { mutableListOf() } += i } }

    fun positions(term: String): List<Int> = positionsByWord[term].orEmpty()

    fun sourceRange(range: IntRange): IntRange? {
        if (range.first < 0 || range.last >= words.size) return null
        return words[range.first].start until words[range.last].end
    }

    fun longestRun(terms: List<String>): Match? {
        if (terms.size < 2) return null
        val candidates = mutableListOf<List<String>>()
        for (length in terms.size downTo 2) for (offset in 0..terms.size - length) candidates += terms.subList(offset, offset + length)
        val ranked = candidates.filter(::saysSomething).sortedWith(
            compareByDescending<List<String>> { run -> run.count(::carriesMeaning) }.thenByDescending { it.size }
        )
        for (run in ranked) {
            val start = firstRun(run) ?: continue
            return Match(start..start + run.size - 1, run.count(::carriesMeaning))
        }
        return null
    }

    fun tightestWindow(terms: List<String>): Match? {
        val meaningful = terms.filter(::carriesMeaning).toSet()
        if (meaningful.size < 2) return null
        val hits = mutableListOf<Pair<Int, String>>()
        for (term in meaningful) for (position in positions(term).take(OCCURRENCE_LIMIT)) hits += position to term
        if (hits.size <= 1) return null
        hits.sortBy { it.first }
        val counts = HashMap<String, Int>()
        var best: IntRange? = null
        var bestScore = 0
        var low = 0
        for (high in hits.indices) {
            counts[hits[high].second] = (counts[hits[high].second] ?: 0) + 1
            while (hits[high].first - hits[low].first > WINDOW_WORDS) {
                val term = hits[low].second
                val left = counts.getValue(term) - 1
                if (left == 0) counts.remove(term) else counts[term] = left
                low++
            }
            if (counts.size > bestScore) {
                bestScore = counts.size
                best = hits[low].first..hits[high].first
            }
        }
        if (bestScore < 2 || best == null) return null
        return Match(best, bestScore)
    }

    fun rarestTerm(terms: List<String>): Match? {
        val present = terms.filter(::carriesMeaning).toSet()
            .map { it to positions(it) }
            .filter { it.second.isNotEmpty() && it.second.size <= RARE_OCCURRENCES }
        val rarest = present.minByOrNull { it.second.size } ?: return null
        val first = rarest.second.first()
        return Match(first..first, 1)
    }

    private fun firstRun(run: List<String>): Int? {
        val first = run.firstOrNull() ?: return null
        for (start in positions(first)) {
            if (start + run.size > words.size) break
            var offset = 1
            while (offset < run.size && words[start + offset].text == run[offset]) offset++
            if (offset == run.size) return start
        }
        return null
    }

    companion object {
        private const val RARE_OCCURRENCES = 3
        private const val OCCURRENCE_LIMIT = 400
        private const val WINDOW_WORDS = 24
        private val marks = Regex("\\p{M}+")

        private val connectives = setOf(
            "the", "and", "but", "for", "not", "all", "any", "are", "was", "who", "you", "our",
            "its", "his", "her", "him", "one", "out", "own", "may", "can", "has", "had", "did",
            "that", "this", "with", "from", "unto", "into", "upon", "they", "them", "their",
            "have", "hath", "been", "were", "shall", "will", "which", "what", "when", "then",
            "than", "thou", "thee", "thy", "your", "yours", "there", "here", "such", "some",
            "every", "each", "also", "very", "more", "most", "doth", "hast", "whom", "would",
        )

        private val apostrophes = setOf('’', '‘', 'ʻ', 'ʼ', '\'', '`', '´')

        fun tokens(text: String): List<Word> {
            val words = mutableListOf<Word>()
            val current = StringBuilder()
            var start = 0
            fun flush(end: Int) {
                if (current.isEmpty()) return
                words += Word(current.toString(), start, end)
                current.clear()
            }
            text.forEachIndexed { offset, c ->
                when {
                    c.isLetterOrDigit() -> {
                        if (current.isEmpty()) start = offset
                        current.append(fold(c))
                    }
                    Character.getType(c) == Character.NON_SPACING_MARK.toInt() && current.isNotEmpty() -> {}
                    c in apostrophes && current.isNotEmpty() -> {}
                    else -> flush(offset)
                }
            }
            flush(text.length)
            return words
        }

        private fun fold(c: Char): String {
            if (c.code < 128) return if (c in 'A'..'Z') (c + 32).toString() else c.toString()
            return marks.replace(Normalizer.normalize(c.toString(), Normalizer.Form.NFKD), "").lowercase()
        }

        fun saysSomething(run: List<String>): Boolean {
            val meaningful = run.count(::carriesMeaning)
            return meaningful >= 2 || (meaningful == 1 && run.size >= 3)
        }

        fun carriesMeaning(term: String): Boolean = term.length > 2 && term !in connectives
    }
}
