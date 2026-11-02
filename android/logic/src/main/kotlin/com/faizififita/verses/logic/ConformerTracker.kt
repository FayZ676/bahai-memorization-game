package com.faizififita.verses.logic

import kotlin.math.ceil
import kotlin.math.floor

class ConformerTracker(
    words: List<String>,
    tokenizer: ConformerTokenizer,
    classes: Int,
    val quietSeconds: Double = 2.0,
) {
    data class Credit(val index: Int, val placement: ConformerAligner.Placement, val creditedAt: Double)

    class Update(val credits: List<Credit> = emptyList(), val flashed: Int? = null)

    val aligner = ConformerAligner(words, tokenizer, FRAME_SECONDS)
    var hidden: Set<Int> = aligner.recitable.toSet()
    val frames = ConformerFrames(classes, tokenizer.blank)
    private val creditMap = LinkedHashMap<Int, Credit>()
    val credits: Map<Int, Credit> get() = creditMap
    private val flashedAt = HashMap<Int, Double>()
    private var latest: ConformerAligner.Alignment? = null

    private val order: List<Int> get() = aligner.recitable

    fun absorb(window: FloatArray, start: Int, end: Int, ready: Int) {
        val first = start / SAMPLES_PER_FRAME
        val windowFrames = window.size / frames.classes
        val refreshFrom = if (start == 0) first else first + KEPT_FRAMES
        val until = minOf(ready, first + windowFrames)
        if (refreshFrom >= until) return
        for (index in refreshFrom until until) {
            frames.write(window, (index - first) * frames.classes, index)
        }
    }

    fun step(ready: Int, now: Double, done: Boolean): Update {
        val credited = commit(ready, now, done)
        if (done) return Update(credited)
        val owed = owedWord() ?: return Update(credited)
        if (!heardThenQuiet(owed, ready)) return Update(credited)
        flashedAt[order[owed]] = ready * FRAME_SECONDS
        return Update(credited, order[owed])
    }

    fun commit(ready: Int, now: Double, done: Boolean): List<Credit> {
        if (ready <= 0 || frames.count < ready) return emptyList()
        val limit = ready * FRAME_SECONDS - (if (done) 0.0 else GUARD_SECONDS)
        val alignment = aligner.align(frames, ready, done)
        latest = alignment
        val lastCreditEnd = creditMap.values.maxOfOrNull { it.placement.end } ?: 0.0
        val freshAudioFrom = if (done) lastCreditEnd - FRAME_SECONDS / 2 else Double.NEGATIVE_INFINITY
        val fresh = mutableListOf<Credit>()
        aligner.recitable.forEachIndexed { position, index ->
            if (creditMap.containsKey(index)) return@forEachIndexed
            val placement = alignment.placements[index] ?: return@forEachIndexed
            if (placement.end > limit ||
                placement.worst < THRESHOLD ||
                !heardSpeech(placement) ||
                placement.start < freshAudioFrom ||
                overlapsCredited(placement)
            ) return@forEachIndexed
            if (!done && !confirmedByPause(position, placement, lastCreditEnd, ready)) {
                val without = aligner.align(frames, ready, false, position)
                if (alignment.score - without.score < EVIDENCE) return@forEachIndexed
            }
            val credit = Credit(index, placement, now)
            creditMap[index] = credit
            fresh += credit
        }
        return fresh
    }

    private fun heardSpeech(placement: ConformerAligner.Placement): Boolean {
        val first = maxOf(0, floor(placement.start / FRAME_SECONDS).toInt() - SPEECH_MARGIN)
        val last = minOf(frames.count - 1, ceil(placement.end / FRAME_SECONDS).toInt() + SPEECH_MARGIN)
        if (first > last) return false
        return (first..last).any { frames.speech[it] }
    }

    private fun confirmedByPause(position: Int, placement: ConformerAligner.Placement, lastCreditEnd: Double, ready: Int): Boolean =
        position > 0 &&
            creditMap.containsKey(order[position - 1]) &&
            placement.start >= lastCreditEnd &&
            quietAfter(placement, ready)

    private fun quietAfter(placement: ConformerAligner.Placement, ready: Int): Boolean {
        val first = ceil(placement.end / FRAME_SECONDS).toInt() + SPEECH_MARGIN
        val heard = minOf(ready, frames.count)
        val heardThrough = heard * FRAME_SECONDS
        if (heardThrough - placement.end < PAUSE_SECONDS || first >= heard) return false
        return (first until heard).none { frames.speech[it] }
    }

    private fun overlapsCredited(placement: ConformerAligner.Placement): Boolean =
        creditMap.values.any {
            minOf(placement.end, it.placement.end) - maxOf(placement.start, it.placement.start) > FRAME_SECONDS / 2
        }

    private fun owedWord(): Int? =
        order.indexOfFirst { it in hidden && !creditMap.containsKey(it) }.takeIf { it >= 0 }

    private fun heardThenQuiet(position: Int, ready: Int): Boolean {
        var anchor = reachedEnd(position) ?: return false
        anchor = maxOf(anchor, flashedAt[order[position]] ?: 0.0)
        var spoken = 0
        var lastSpoken = 0.0
        var frame = ceil(anchor / FRAME_SECONDS).toInt()
        val heard = minOf(ready, frames.count)
        while (frame < heard) {
            if (frames.speech[frame]) {
                spoken++
                lastSpoken = (frame + 1) * FRAME_SECONDS
            }
            frame++
        }
        val heardThrough = ready * FRAME_SECONDS
        return spoken >= SPEECH_FRAMES_FOR_FLASH && heardThrough - lastSpoken >= quietSeconds
    }

    private fun reachedEnd(position: Int): Double? {
        for (previous in position - 1 downTo 0) {
            val index = order[previous]
            creditMap[index]?.let { return it.placement.end }
            if (index in hidden) return null
            val placement = latest?.placements?.get(index) ?: return null
            if (placement.worst < THRESHOLD) return null
            return placement.end
        }
        return 0.0
    }

    companion object {
        const val SAMPLE_RATE = 16_000
        const val WINDOW_SAMPLES = 96_000
        const val HOP_SAMPLES = 4_000
        const val LOOKAHEAD_SAMPLES = 4_000
        const val SAMPLES_PER_FRAME = 640
        const val FRAME_SECONDS = 0.04
        const val KEPT_FRAMES = 2 * SAMPLE_RATE / SAMPLES_PER_FRAME
        const val GUARD_SECONDS = 0.1
        const val THRESHOLD = -7.67
        const val EVIDENCE = 7.0
        const val SPEECH_FRAMES_FOR_FLASH = 3
        const val SPEECH_MARGIN = 2
        const val PAUSE_SECONDS = 0.6

        fun windowStart(endingAt: Int): Int = maxOf(0, endingAt - WINDOW_SAMPLES) / SAMPLES_PER_FRAME * SAMPLES_PER_FRAME

        fun totalFrames(samples: Int): Int {
            val melFrames = samples / 160
            val halved = if (melFrames > 0) (melFrames - 1) / 2 + 1 else 0
            return if (halved > 0) (halved - 1) / 2 + 1 else 0
        }
    }
}
