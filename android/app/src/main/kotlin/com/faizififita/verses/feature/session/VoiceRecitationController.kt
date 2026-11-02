package com.faizififita.verses.feature.session

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class VoiceRecitationController(context: Context) {
    enum class State { Idle, PreparingModel, Listening, MicDenied, Failed }

    var state by mutableStateOf(State.Idle)
        private set
    var cursorIndex by mutableStateOf<Int?>(null)
        private set
    var onWordsMatched: (List<Int>) -> Unit = {}
    var onMiss: (Int) -> Unit = {}
    var onWordShown: (Int) -> Unit = {}
    var onCompleted: () -> Unit = {}

    private val capture = AudioCapture(context)
    private var listener: ConformerRecitation? = null
    private var owed = mutableSetOf<Int>()
    private var reached = 0
    private var wordCount = 0
    private val misses = HashMap<Int, Int>()

    val isListening: Boolean get() = state == State.Listening

    fun prepare() {
        ConformerRecitation.preload()
    }

    fun denyMicrophone() {
        state = State.MicDenied
    }

    suspend fun start(words: List<String>, hiddenIndices: List<Int>, from: Int) {
        ConformerRecitation.trace("start words=${words.size} from=$from hidden=${hiddenIndices.size}")
        if (hiddenIndices.isEmpty()) return
        if (state != State.Idle && state != State.Failed && state != State.MicDenied) return
        state = State.PreparingModel
        try {
            val listener = ConformerRecitation.make(
                words, hiddenIndices, from,
                onCredits = { credit(it) },
                onFlash = { flash(it) },
            )
            if (state != State.PreparingModel) {
                listener.finish()
                return
            }
            this.listener = listener
            owed = hiddenIndices.toMutableSet()
            misses.clear()
            reached = from
            wordCount = words.size
            cursorIndex = from
            withContext(Dispatchers.Default) { capture.start(listener) }
            if (state != State.PreparingModel) return
            state = State.Listening
        } catch (error: Throwable) {
            ConformerRecitation.trace("start FAILED $error")
            state = State.Failed
            teardown()
        }
    }

    fun updateHiddenIndices(hiddenIndices: List<Int>) {
        val listener = listener ?: return
        if (state != State.Listening) return
        listener.updateHidden(hiddenIndices)
        owed = hiddenIndices.toMutableSet()
        if (owed.isEmpty()) stop()
    }

    fun stop() {
        if (state == State.Idle) return
        if (state != State.MicDenied) state = State.Idle
        teardown()
    }

    private fun credit(indices: List<Int>) {
        indices.maxOrNull()?.let { reached = maxOf(reached, it + 1) }
        val fresh = indices.filter { it in owed }
        if (fresh.isNotEmpty()) {
            owed.removeAll(fresh.toSet())
            onWordsMatched(fresh)
        }
        advance()
    }

    private fun advance() {
        if (state != State.Listening) return
        cursorIndex = minOf(reached, wordCount - 1)
        if (owed.isEmpty()) {
            stop()
            onCompleted()
        }
    }

    private fun flash(index: Int) {
        if (state != State.Listening || index !in owed) return
        onMiss(index)
        misses[index] = (misses[index] ?: 0) + 1
        if ((misses[index] ?: 0) < MISSES_BEFORE_SHOWING) return
        owed.remove(index)
        listener?.updateHidden(owed.toList())
        onWordShown(index)
        advance()
    }

    private fun teardown() {
        listener?.finish()
        listener = null
        capture.stop()
        cursorIndex = null
    }

    companion object {
        private const val MISSES_BEFORE_SHOWING = 2
    }
}
