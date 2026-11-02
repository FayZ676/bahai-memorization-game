package com.faizififita.verses.feature.session

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.Constraints
import kotlin.math.ceil
import kotlin.math.exp

data class ReadingMetrics(
    val textMargin: Float,
    val maxStretchPerGap: Float,
    val wordSpacing: Float,
    val lineSpacing: Float,
    val paragraphSpacing: Float,
) {
    companion object {
        fun of(widthDp: Float, fontScale: Float, density: Float): ReadingMetrics {
            val narrow = widthDp < 390
            return ReadingMetrics(
                textMargin = (if (narrow) 30f else 42f) * density,
                maxStretchPerGap = (if (narrow) 1.5f else 2.5f) * fontScale,
                wordSpacing = 7f * fontScale * density,
                lineSpacing = 4f * fontScale * density,
                paragraphSpacing = 26f * fontScale * density,
            )
        }
    }
}

data class WordParts(val lead: String, val core: String, val trail: String) {
    companion object {
        fun of(token: String): WordParts {
            fun isCore(c: Char) = c.isLetter() || c == '\'' || c == '’' || Character.getType(c) == Character.NON_SPACING_MARK.toInt()
            var i = 0
            while (i < token.length && !isCore(token[i])) i++
            var j = token.length
            while (j > i && !isCore(token[j - 1])) j--
            return WordParts(token.substring(0, i), token.substring(i, j), token.substring(j))
        }
    }
}

class WordFrame(val rect: Rect, val coreStart: Float, val coreWidth: Float)

class PageLayout(
    words: List<String>,
    ranges: List<IntRange>,
    val width: Float,
    val metrics: ReadingMetrics,
    measurer: TextMeasurer,
    val style: TextStyle,
) {
    class Paragraph(val words: IntRange, val frame: Rect)

    val wordFrames: List<WordFrame>
    val paragraphs: List<Paragraph>
    val height: Float
    val lineHeight: Float

    init {
        lineHeight = ceil(measurer.measure("Ag", style).size.height.toFloat())
        val frames = arrayOfNulls<WordFrame>(words.size)
        val paragraphs = mutableListOf<Paragraph>()
        val widthCache = HashMap<String, Float>()
        fun measure(text: String): Float =
            if (text.isEmpty()) 0f else widthCache.getOrPut(text) {
                ceil(measurer.measure(text, style, constraints = Constraints(), softWrap = false, maxLines = 1).size.width.toFloat())
            }
        var top = 0f
        for (range in ranges) {
            if (range.isEmpty()) continue
            if (paragraphs.isNotEmpty()) top += metrics.paragraphSpacing
            val parts = range.map { WordParts.of(words[it]) }
            val leads = parts.map { measure(it.lead) }
            val cores = parts.map { measure(it.core) }
            val widths = parts.indices.map { leads[it] + cores[it] + measure(parts[it].trail) }
            val units = units(range, words)
            val unitWidths = units.map { unit -> unit.sumOf { widths[it].toDouble() }.toFloat() }
            val rows = mutableListOf<MutableList<Int>>()
            var row = mutableListOf<Int>()
            var rowWidth = 0f
            unitWidths.forEachIndexed { unit, unitWidth ->
                val added = if (row.isEmpty()) unitWidth else rowWidth + metrics.wordSpacing + unitWidth
                if (added > width && row.isNotEmpty()) {
                    rows += row
                    row = mutableListOf()
                    rowWidth = unitWidth
                } else {
                    rowWidth = added
                }
                row += unit
            }
            if (row.isNotEmpty()) rows += row
            var y = top
            rows.forEachIndexed { rowNumber, items ->
                val used = items.sumOf { unitWidths[it].toDouble() }.toFloat() + metrics.wordSpacing * (items.size - 1)
                val gap = gap(width - used, items.size, rowNumber == rows.size - 1)
                var x = 0f
                for (unit in items) {
                    for (offset in units[unit]) {
                        frames[range.first + offset] = WordFrame(Rect(x, y, x + widths[offset], y + lineHeight), leads[offset], cores[offset])
                        x += widths[offset]
                    }
                    x += gap
                }
                y += lineHeight + metrics.lineSpacing
            }
            val height = rows.size * lineHeight + metrics.lineSpacing * maxOf(rows.size - 1, 0)
            paragraphs += Paragraph(range, Rect(0f, top, width, top + height))
            top += height
        }
        wordFrames = frames.map { it ?: WordFrame(Rect.Zero, 0f, 0f) }
        this.paragraphs = paragraphs
        height = top
    }

    fun wordIndex(point: Offset): Int? {
        val paragraph = paragraphs.firstOrNull { it.frame.inflate(SLOP_X, SLOP_Y).contains(point) } ?: return null
        return paragraph.words
            .filter { wordFrames[it].rect.inflate(SLOP_X, SLOP_Y).contains(point) }
            .minByOrNull { squaredDistance(point, wordFrames[it].rect) }
    }

    fun paragraphIndex(containing: Int): Int? = paragraphs.indexOfFirst { containing in it.words }.takeIf { it >= 0 }

    fun paragraphIndex(atTop: Float, tolerance: Float): Int? =
        paragraphs.indexOfFirst { it.frame.top >= atTop - tolerance }.takeIf { it >= 0 }
            ?: paragraphs.indexOfLast { it.frame.top <= atTop }.takeIf { it >= 0 }

    fun density(hidden: Set<Int>, samples: Int): List<Double> {
        if (height <= 0 || samples <= 0 || wordFrames.isEmpty()) return emptyList()
        val hiddenCount = DoubleArray(samples)
        val total = DoubleArray(samples)
        wordFrames.forEachIndexed { index, frame ->
            val bucket = minOf((frame.rect.center.y / height * samples).toInt(), samples - 1).coerceAtLeast(0)
            total[bucket] += 1.0
            if (index in hidden) hiddenCount[bucket] += 1.0
        }
        val raw = DoubleArray(samples) { if (total[it] > 0) hiddenCount[it] / total[it] else -1.0 }
        for (index in raw.indices) {
            if (raw[index] >= 0) continue
            val before = (index - 1 downTo 0).map { raw[it] }.firstOrNull { it >= 0 }
            val after = (index + 1 until samples).map { raw[it] }.firstOrNull { it >= 0 }
            raw[index] = ((before ?: after ?: 0.0) + (after ?: before ?: 0.0)) / 2
        }
        return raw.indices.map { index ->
            val window = (maxOf(0, index - 1)..minOf(raw.size - 1, index + 1)).map { raw[it] }
            window.sum() / window.size
        }
    }

    private fun units(range: IntRange, words: List<String>): List<List<Int>> {
        val units = mutableListOf<MutableList<Int>>()
        range.forEachIndexed { offset, index ->
            if (words[index].startsWith("-") && words[index].length > 1 && units.isNotEmpty()) units.last() += offset
            else units += mutableListOf(offset)
        }
        return units
    }

    private fun gap(slack: Float, items: Int, lastRow: Boolean): Float {
        if (lastRow || items <= 1 || slack <= 0) return metrics.wordSpacing
        return metrics.wordSpacing + minOf(slack / (items - 1), metrics.wordSpacing * metrics.maxStretchPerGap)
    }

    private fun Rect.inflate(dx: Float, dy: Float) = Rect(left - dx, top - dy, right + dx, bottom + dy)

    private fun squaredDistance(point: Offset, frame: Rect): Float {
        val dx = maxOf(frame.left - point.x, 0f, point.x - frame.right)
        val dy = maxOf(frame.top - point.y, 0f, point.y - frame.bottom)
        return dx * dx + dy * dy
    }

    private val SLOP_X = 3.5f * metrics.wordSpacing / 7f
    private val SLOP_Y = 6f * metrics.wordSpacing / 7f

    companion object {
        fun heatOpacity(heat: Double): Float {
            val x = heat.coerceIn(0.0, 1.0)
            if (x <= 0) return 0f
            val k = 2.5
            val eased = (exp(k * x) - 1) / (exp(k) - 1)
            return (0.16 + 0.84 * eased).toFloat()
        }
    }
}
