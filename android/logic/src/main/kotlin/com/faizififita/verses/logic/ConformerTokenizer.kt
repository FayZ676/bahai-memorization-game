package com.faizififita.verses.logic

import kotlinx.serialization.Serializable
import java.text.Normalizer

@Serializable
data class ConformerVocabulary(val blank: Int, val pieces: List<String>, val scores: List<Float>)

class ConformerTokenizer(vocabulary: ConformerVocabulary) {
    val blank = vocabulary.blank
    private val pieceIDs: Map<String, Int>
    private val scores = vocabulary.scores.toFloatArray()
    private val longestPiece: Int
    private val unknownID = 0
    private val unknownScore: Float

    init {
        val ids = HashMap<String, Int>()
        vocabulary.pieces.forEachIndexed { id, piece ->
            if (id != 0 && !piece.startsWith("<")) ids[piece] = id
        }
        pieceIDs = ids
        longestPiece = vocabulary.pieces.maxOfOrNull { it.codePointCount(0, it.length) } ?: 1
        unknownScore = (vocabulary.scores.minOrNull() ?: 0f) - 10
    }

    fun tokenize(word: String): List<Int> {
        val normalized = fold(word)
        if (normalized.isEmpty()) return emptyList()
        val scalars = ("▁$normalized").codePoints().toArray()
        val count = scalars.size
        val best = FloatArray(count + 1) { Float.NEGATIVE_INFINITY }
        val piece = IntArray(count + 1) { -1 }
        val from = IntArray(count + 1)
        best[0] = 0f
        for (start in 0 until count) {
            if (best[start] == Float.NEGATIVE_INFINITY) continue
            var coveredSingle = false
            val text = StringBuilder()
            for (end in (start + 1)..minOf(count, start + longestPiece)) {
                text.appendCodePoint(scalars[end - 1])
                val id = pieceIDs[text.toString()] ?: continue
                if (end == start + 1) coveredSingle = true
                val score = best[start] + scores[id]
                if (score > best[end]) {
                    best[end] = score
                    piece[end] = id
                    from[end] = start
                }
            }
            if (!coveredSingle) {
                val score = best[start] + unknownScore
                if (score > best[start + 1]) {
                    best[start + 1] = score
                    piece[start + 1] = unknownID
                    from[start + 1] = start
                }
            }
        }
        val ids = mutableListOf<Int>()
        var position = count
        while (position > 0) {
            ids += piece[position]
            position = from[position]
        }
        val merged = mutableListOf<Int>()
        for (id in ids.asReversed()) {
            if (!(id == unknownID && merged.lastOrNull() == unknownID)) merged += id
        }
        return merged
    }

    companion object {
        private val marks = Regex("\\p{M}+")

        fun fold(word: String): String {
            val compatible = Normalizer.normalize(word, Normalizer.Form.NFKC)
            val stripped = marks.replace(Normalizer.normalize(compatible, Normalizer.Form.NFD), "")
            return stripped.lowercase().filter { it.isLetter() || it == '\'' }
        }
    }
}
