package com.faizififita.verses.logic

class ConformerSession(
    private val words: List<String>,
    hidden: Set<Int>,
    start: Int = 0,
    private val tokenizer: ConformerTokenizer,
    private val classes: Int,
    private val span: Int = WORD_SPAN,
) {
    private class Window(val start: Int, val end: Int, val ready: Int, val done: Boolean)

    class Update(val credits: MutableList<Int> = mutableListOf(), var flashed: Int? = null, var hops: Int = 0) {
        fun merge(other: Update) {
            credits += other.credits
            other.flashed?.let { flashed = it }
            hops += other.hops
        }
    }

    fun interface Predictor {
        fun predict(chunk: FloatArray): FloatArray?
    }

    var hidden: Set<Int> = hidden
        private set
    var anchorWord = start.coerceIn(0, words.size)
        private set
    var anchorSample = 0
        private set
    private var processedEnd = 0
    private var audio = FloatArray(ConformerTracker.WINDOW_SAMPLES * 2)
    private var audioCount = 0
    private var audioStart = 0
    private var nextHop = ConformerTracker.HOP_SAMPLES
    private val chunk = FloatArray(ConformerTracker.WINDOW_SAMPLES)
    private var tracker = makeTracker()

    private val heard: Int get() = audioStart + audioCount

    fun setHidden(hidden: Set<Int>) {
        this.hidden = hidden
        tracker.hidden = localHidden()
    }

    fun append(samples: FloatArray, predictor: Predictor): Update {
        if (audioCount + samples.size > audio.size) audio = audio.copyOf(maxOf(audio.size * 2, audioCount + samples.size))
        samples.copyInto(audio, audioCount)
        audioCount += samples.size
        val update = Update()
        while (heard >= nextHop) {
            val end = nextHop
            nextHop += ConformerTracker.HOP_SAMPLES
            update.merge(listen(end, false, predictor))
        }
        return update
    }

    fun finish(predictor: Predictor): Update {
        if (heard <= 0) return Update()
        return listen(heard + ConformerTracker.LOOKAHEAD_SAMPLES, true, predictor)
    }

    private fun windows(endingAt: Int, done: Boolean): List<Window> {
        val localEnd = endingAt - anchorSample
        val ends = mutableListOf<Int>()
        var next = processedEnd + ConformerTracker.HOP_SAMPLES
        while (next < localEnd) {
            ends += next
            next += ConformerTracker.HOP_SAMPLES
        }
        ends += localEnd
        return ends.mapIndexed { number, local ->
            val last = number == ends.size - 1
            val ready = if (last && done) ConformerTracker.totalFrames(heard - anchorSample)
            else maxOf(0, (local - ConformerTracker.LOOKAHEAD_SAMPLES) / ConformerTracker.SAMPLES_PER_FRAME)
            Window(anchorSample + ConformerTracker.windowStart(local), anchorSample + local, ready, last && done)
        }
    }

    private fun listen(through: Int, done: Boolean, predictor: Predictor): Update {
        val update = Update(hops = 1)
        for (window in windows(through, done)) {
            val available = maxOf(0, minOf(window.end, heard) - window.start)
            val first = window.start - audioStart
            for (offset in chunk.indices) {
                chunk[offset] = if (offset < available) audio[first + offset] else 0f
            }
            val rows = predictor.predict(chunk) ?: continue
            tracker.absorb(rows, window.start - anchorSample, window.end - anchorSample, window.ready)
            val step = step(window, window.end.toDouble() / ConformerTracker.SAMPLE_RATE)
            update.credits += step.credits
            step.flashed?.let { update.flashed = it }
        }
        forgetAudio(anchorSample)
        return update
    }

    private fun forgetAudio(before: Int) {
        if (before <= audioStart) return
        val drop = minOf(before - audioStart, audioCount)
        audio.copyInto(audio, 0, drop, audioCount)
        audioCount -= drop
        audioStart = before
    }

    private fun step(window: Window, now: Double): Update {
        val local = tracker.step(window.ready, now, window.done)
        processedEnd = window.end - anchorSample
        val update = Update(
            credits = local.credits.map { it.index + anchorWord }.toMutableList(),
            flashed = local.flashed?.let { it + anchorWord },
        )
        if (!window.done) advance(window.end)
        return update
    }

    private fun localHidden(): Set<Int> {
        val upper = minOf(anchorWord + span, words.size)
        return hidden.filter { it >= anchorWord && it < upper }.map { it - anchorWord }.toSet()
    }

    private fun makeTracker(): ConformerTracker {
        val upper = minOf(anchorWord + span, words.size)
        return ConformerTracker(words.subList(anchorWord, upper), tokenizer, classes).also {
            it.hidden = localHidden()
        }
    }

    private fun advance(end: Int) {
        val credits = tracker.credits
        val crowded = end - anchorSample > LONGEST_AUDIO
        val last = credits.keys.maxOrNull()
        if (last == null) {
            if (crowded) restart(anchorWord, end - ConformerTracker.WINDOW_SAMPLES)
            return
        }
        var cut = last + 1 - KEEP_BACK
        while (cut > 0 && !credits.containsKey(cut - 1)) cut--
        if (crowded && cut == 0) cut = last + 1
        if (!(cut >= ADVANCE_AFTER || (crowded && cut > 0))) return
        val anchor = credits[cut - 1] ?: return
        val sample = anchorSample + (anchor.placement.end * ConformerTracker.SAMPLE_RATE).toInt()
        restart(anchorWord + cut, maxOf(sample, end - ConformerTracker.WINDOW_SAMPLES))
    }

    private fun restart(word: Int, sample: Int) {
        anchorWord = word
        anchorSample = maxOf(sample, anchorSample)
        processedEnd = 0
        tracker = makeTracker()
    }

    companion object {
        const val WORD_SPAN = 64
        const val ADVANCE_AFTER = 24
        const val KEEP_BACK = 8
        const val LONGEST_AUDIO = 45 * ConformerTracker.SAMPLE_RATE
    }
}
