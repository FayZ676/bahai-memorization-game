package com.faizififita.verses.logic

class ConformerFrames(val classes: Int, val blank: Int) {
    var values = FloatArray(0)
        private set
    var peaks = FloatArray(0)
        private set
    var speech = BooleanArray(0)
        private set
    var count = 0
        private set

    fun write(row: FloatArray, rowOffset: Int, index: Int) {
        if (index >= count) grow(index + 1)
        var peak = Float.NEGATIVE_INFINITY
        val offset = index * classes
        for (column in 0 until classes) {
            val value = row[rowOffset + column]
            values[offset + column] = value
            if (value > peak) peak = value
        }
        peaks[index] = peak
        speech[index] = row[rowOffset + blank] < peak
    }

    private fun grow(newCount: Int) {
        if (newCount > peaks.size) {
            val capacity = maxOf(newCount, peaks.size * 2, 64)
            values = values.copyOf(capacity * classes)
            peaks = peaks.copyOf(capacity)
            speech = speech.copyOf(capacity)
        }
        for (index in count until newCount) {
            values.fill(0f, index * classes, (index + 1) * classes)
            peaks[index] = 0f
            speech[index] = false
        }
        count = newCount
    }
}

class ConformerAligner(words: List<String>, tokenizer: ConformerTokenizer, private val frameSeconds: Double) {
    data class Placement(val gop: Double, val worst: Double, val start: Double, val end: Double)

    class Alignment(val score: Double, val placements: Map<Int, Placement?>)

    val recitable: List<Int>
    private val pieceCounts: IntArray
    private val token: IntArray
    private val wordOf: IntArray
    private val first: IntArray
    private val allowsJump: BooleanArray
    private val isFirst: BooleanArray
    private val isEntry: BooleanArray
    private val closingPiece: IntArray
    private val closingBlank: IntArray
    private val blank = tokenizer.blank
    private val garbage = 2.0
    private val skip = 20.0
    private val restart = 10.0
    private val flatStart = 20.0

    init {
        val tokenized = words.map(tokenizer::tokenize)
        recitable = words.indices.filter { tokenized[it].isNotEmpty() }
        pieceCounts = recitable.map { tokenized[it].size }.toIntArray()
        val token = mutableListOf<Int>()
        val wordOf = mutableListOf<Int>()
        val first = mutableListOf<Int>()
        val allowsJump = mutableListOf<Boolean>()
        val closingPiece = mutableListOf<Int>()
        val closingBlank = mutableListOf<Int>()
        recitable.forEachIndexed { position, index ->
            val pieces = tokenized[index]
            first += token.size
            for (state in 0 until 2 * pieces.size + 1) {
                val isPiece = state % 2 == 1
                token += if (isPiece) pieces[state / 2] else -1
                wordOf += position
                allowsJump += isPiece && state >= 3 && pieces[state / 2] != pieces[state / 2 - 1]
            }
            closingPiece += token.size - 2
            closingBlank += token.size - 1
        }
        val isFirst = BooleanArray(token.size)
        val isEntry = BooleanArray(token.size)
        for (start in first) {
            isFirst[start] = true
            isEntry[start] = true
            isEntry[start + 1] = true
        }
        this.token = token.toIntArray()
        this.wordOf = wordOf.toIntArray()
        this.first = first.toIntArray()
        this.allowsJump = allowsJump.toBooleanArray()
        this.isFirst = isFirst
        this.isEntry = isEntry
        this.closingPiece = closingPiece.toIntArray()
        this.closingBlank = closingBlank.toIntArray()
    }

    fun align(frames: ConformerFrames, through: Int, final: Boolean, forbidding: Int? = null): Alignment {
        val bigT = through
        val bigW = recitable.size
        if (bigT <= 0 || bigW <= 0) return Alignment(IMPOSSIBLE, emptyMap())
        return align(frames, bigT, final, forbidding ?: -1)
    }

    private fun emit(frames: ConformerFrames, forbidden: Int, t: Int, s: Int): Double {
        if (wordOf[s] == forbidden) return IMPOSSIBLE
        val column = if (token[s] < 0) blank else token[s]
        return frames.values[t * frames.classes + column].toDouble()
    }

    private fun align(frames: ConformerFrames, bigT: Int, final: Boolean, forbidden: Int): Alignment {
        val bigW = recitable.size
        val bigN = token.size
        val impossible = IMPOSSIBLE
        val values = frames.values
        val peaks = frames.peaks
        val classes = frames.classes
        val blankColumn = blank

        var current = DoubleArray(bigN) { impossible }
        var upcoming = DoubleArray(bigN) { impossible }
        val g = DoubleArray(bigW + 1) { impossible }
        val x = DoubleArray(bigW) { impossible }
        val a = DoubleArray(bigW + 1) { impossible }
        val r = DoubleArray(bigW) { impossible }
        val back = DoubleArray(bigW) { impossible }
        val backSource = IntArray(bigW)
        val code = ByteArray(bigT * bigN)
        val entrySource = IntArray(bigT * bigW)
        val aFrom = BooleanArray(bigT * (bigW + 1))
        val xState = IntArray(bigT * bigW)
        val gFromX = BooleanArray(bigT * (bigW + 1))

        var t = 0
        while (t < bigT) {
            val gemit = peaks[t].toDouble() - garbage
            val source = t * bigW
            val xs = t * bigW
            val af = t * (bigW + 1)
            if (t == 0) {
                var w = 0
                while (w < bigW) {
                    x[w] = impossible
                    xState[xs + w] = closingPiece[w]
                    r[w] = if (w == 0) 0.0 else -flatStart
                    entrySource[source + w] = 0
                    w++
                }
                var j = 0
                while (j <= bigW) {
                    a[j] = if (j == 0) 0.0 else impossible
                    aFrom[af + j] = true
                    j++
                }
            } else {
                var w = 0
                while (w < bigW) {
                    val pieceScore = current[closingPiece[w]]
                    val blankScore = current[closingBlank[w]]
                    if (blankScore > pieceScore) {
                        x[w] = blankScore
                        xState[xs + w] = closingBlank[w]
                    } else {
                        x[w] = pieceScore
                        xState[xs + w] = closingPiece[w]
                    }
                    w++
                }
                a[0] = g[0]
                aFrom[af] = true
                var j = 1
                while (j <= bigW) {
                    a[j] = if (x[j - 1] > g[j]) x[j - 1] else g[j]
                    aFrom[af + j] = g[j] >= x[j - 1]
                    j++
                }
                var run = impossible
                var runSource = 0
                j = 0
                while (j < bigW) {
                    if (a[j] >= run - skip) {
                        run = a[j]
                        runSource = j
                    } else {
                        run -= skip
                    }
                    r[j] = run
                    entrySource[source + j] = runSource
                    j++
                }
                j = bigW - 1
                while (j >= 0) {
                    val later = if (j + 1 < bigW) back[j + 1] else impossible
                    if (a[j + 1] >= later) {
                        back[j] = a[j + 1]
                        backSource[j] = j + 1
                    } else {
                        back[j] = later
                        backSource[j] = if (j + 1 < bigW) backSource[j + 1] else bigW
                    }
                    j--
                }
                j = 0
                while (j < bigW) {
                    val jumped = back[j] - restart
                    if (jumped > r[j]) {
                        r[j] = jumped
                        entrySource[source + j] = backSource[j]
                    }
                    j++
                }
            }

            val row = t * classes
            val blankValue = values[row + blankColumn].toDouble()
            val choices = t * bigN
            var s = 0
            while (s < bigN) {
                var best = current[s]
                var choice: Byte = 0
                if (s >= 1 && !isFirst[s] && current[s - 1] > best) {
                    best = current[s - 1]
                    choice = 1
                }
                if (s >= 2 && allowsJump[s] && current[s - 2] > best) {
                    best = current[s - 2]
                    choice = 2
                }
                if (isEntry[s]) {
                    val entry = r[wordOf[s]]
                    if (entry > best) {
                        best = entry
                        choice = 3
                    }
                }
                val piece = token[s]
                val emitted = if (wordOf[s] == forbidden) impossible
                else if (piece < 0) blankValue
                else values[row + piece].toDouble()
                upcoming[s] = best + emitted
                code[choices + s] = choice
                s++
            }

            val fromX = t * (bigW + 1)
            var j = bigW
            while (j >= 0) {
                val stay = g[j]
                val fromWord = if (j == 0) (if (t == 0) 0.0 else impossible) else x[j - 1]
                g[j] = gemit + (if (fromWord > stay) fromWord else stay)
                gFromX[fromX + j] = fromWord > stay
                j--
            }
            val swap = current
            current = upcoming
            upcoming = swap
            t++
        }

        val lastChoice = IntArray(bigW)
        for (w in 0 until bigW) {
            val pieceScore = current[closingPiece[w]]
            val blankScore = current[closingBlank[w]]
            x[w] = maxOf(pieceScore, blankScore)
            lastChoice[w] = if (blankScore > pieceScore) closingBlank[w] else closingPiece[w]
        }
        var end = 0
        var score = Double.NEGATIVE_INFINITY
        for (j in 0..bigW) {
            val reached = if (j == 0) g[0] else maxOf(x[j - 1], g[j])
            val tail = reached - (if (final) skip else 0.0) * (bigW - j).toDouble()
            if (tail > score) {
                score = tail
                end = j
            }
        }

        val pathT = Array(bigW) { mutableListOf<Int>() }
        val pathS = Array(bigW) { mutableListOf<Int>() }
        var inGarbage = end == 0 || g[end] >= x[end - 1]
        var state = if (inGarbage) end else lastChoice[end - 1]
        t = bigT - 1
        while (t >= 0) {
            if (inGarbage) {
                if (t == 0) break
                if (gFromX[t * (bigW + 1) + state]) {
                    if (state > 0) {
                        inGarbage = false
                        state = xState[t * bigW + state - 1]
                    } else {
                        state = 0
                    }
                }
                t--
                continue
            }
            pathT[wordOf[state]] += t
            pathS[wordOf[state]] += state
            when (code[t * bigN + state].toInt()) {
                0 -> {}
                1 -> state -= 1
                2 -> state -= 2
                else -> {
                    val entry = entrySource[t * bigW + wordOf[state]]
                    if (t == 0) {
                        t = -1
                        continue
                    }
                    if (aFrom[t * (bigW + 1) + entry] || entry == 0) {
                        inGarbage = true
                        state = entry
                    } else {
                        state = xState[t * bigW + entry - 1]
                    }
                }
            }
            t--
        }

        val placements = HashMap<Int, Placement?>()
        recitable.forEachIndexed { position, index ->
            val steps = pathT[position].indices.reversed().map { pathT[position][it] to pathS[position][it] }
            val segments = mutableListOf<MutableList<Pair<Int, Int>>>()
            for (step in steps) {
                val previous = segments.lastOrNull()?.lastOrNull()
                if (previous != null && step.first == previous.first + 1) segments.last() += step
                else segments += mutableListOf(step)
            }
            val expected = (0 until pieceCounts[position]).map { first[position] + 1 + 2 * it }.toSet()
            var best: Placement? = null
            for (segment in segments) {
                val pieces = segment.filter { token[it.second] >= 0 }
                val low = pieces.firstOrNull()?.first ?: continue
                val high = pieces.last().first
                val span = segment.filter { it.first in low..high }
                val gop = span.sumOf { emit(frames, forbidden, it.first, it.second) - peaks[it.first] } / span.size
                val perPiece = LinkedHashMap<Int, MutableList<Double>>()
                for (step in pieces) {
                    perPiece.getOrPut(step.second) { mutableListOf() } += emit(frames, forbidden, step.first, step.second) - peaks[step.first]
                }
                var worst = perPiece.values.minOfOrNull { it.sum() / it.size } ?: Double.NEGATIVE_INFINITY
                if (perPiece.keys != expected) worst = Double.NEGATIVE_INFINITY
                val candidate = Placement(gop, worst, low * frameSeconds, (high + 1) * frameSeconds)
                if (best == null || candidate.worst > best.worst) best = candidate
            }
            placements[index] = best
        }
        return Alignment(score, placements)
    }

    companion object {
        private const val IMPOSSIBLE = -1e30
    }
}
