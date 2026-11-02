package com.faizififita.verses.logic

import kotlin.math.abs

class Fuse(
    private val location: Int = 0,
    private val distance: Int = 100,
    private val threshold: Double = 0.6,
    private val isCaseSensitive: Boolean = false,
    private val tokenize: Boolean = false,
) {
    class Pattern(val text: String, val length: Int, val mask: Long, val alphabet: Map<Char, Long>)

    fun createPattern(from: String): Pattern? {
        val pattern = if (isCaseSensitive) from else from.lowercase()
        if (pattern.isEmpty()) return null
        val alphabet = HashMap<Char, Long>()
        pattern.forEachIndexed { i, c -> alphabet[c] = (alphabet[c] ?: 0L) or (1L shl (pattern.length - i - 1)) }
        return Pattern(pattern, pattern.length, 1L shl (pattern.length - 1), alphabet)
    }

    fun search(pattern: Pattern?, text: String): Double? {
        pattern ?: return null
        if (!tokenize) return score(pattern, text).takeIf { it != 1.0 }
        val words = pattern.text.split(' ').filter { it.isNotEmpty() }.mapNotNull(::createPattern)
        val total = words.fold(score(pattern, text)) { sum, word -> sum + score(word, text) }
        return (total / (words.size + 1)).takeIf { it != 1.0 }
    }

    private fun calculate(length: Int, e: Int, x: Int, loc: Int): Double {
        val accuracy = e.toDouble() / length
        val proximity = abs(x - loc)
        if (distance == 0) return if (proximity != 0) 1.0 else accuracy
        return accuracy + proximity.toDouble() / distance
    }

    private fun indexOf(text: String, pattern: String, from: Int?): Int? {
        from ?: return null
        if (text.length < from) return null
        return text.indexOf(pattern, from).takeIf { it >= 0 }
    }

    private fun score(pattern: Pattern, source: String): Double {
        val text = if (isCaseSensitive) source else source.lowercase()
        val textLength = text.length
        if (pattern.text == text) return 0.0
        var threshold = this.threshold
        var bestLocation = indexOf(text, pattern.text, location)
        var index = indexOf(text, pattern.text, bestLocation)
        while (index != null) {
            threshold = minOf(threshold, calculate(pattern.length, 0, index, location))
            bestLocation = index + pattern.length
            index = indexOf(text, pattern.text, bestLocation)
        }
        var score = 1.0
        var binMax = pattern.length + textLength
        var lastBits = LongArray(0)
        for (i in 0 until pattern.length) {
            var binMin = 0
            var binMid = binMax
            while (binMin < binMid) {
                if (calculate(pattern.length, i, location, location + binMid) <= threshold) binMin = binMid
                else binMax = binMid
                binMid = (binMax - binMin) / 2 + binMin
            }
            binMax = binMid
            var start = maxOf(1, location - binMid + 1)
            val finish = minOf(location + binMid, textLength) + pattern.length
            val bits = LongArray(finish + 2)
            bits[finish + 1] = (1L shl i) - 1
            if (start > finish) continue
            var j = finish
            while (j >= start) {
                val current = j - 1
                val charMatch = if (current < textLength) pattern.alphabet[text[current]] ?: 0L else 0L
                bits[j] = ((bits[j + 1] shl 1) or 1L) and charMatch
                if (i > 0) {
                    val after = lastBits.getOrElse(j + 1) { 0L }
                    val here = lastBits.getOrElse(j) { 0L }
                    bits[j] = bits[j] or (((after or here) shl 1) or 1L) or after
                }
                if (bits[j] and pattern.mask != 0L) {
                    score = calculate(pattern.length, i, location, current)
                    if (score <= threshold) {
                        threshold = score
                        if (current > location) start = maxOf(1, 2 * location - current)
                        else break
                    }
                }
                j--
            }
            if (calculate(pattern.length, i + 1, location, location) > threshold) break
            lastBits = bits
        }
        return score
    }
}
