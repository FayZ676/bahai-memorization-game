package com.faizififita.verses.feature.session

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import com.faizififita.verses.BuildConfig
import com.faizififita.verses.logic.ConformerTracker
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

class AudioCapture(private val context: Context) {
    private val audioManager = context.getSystemService(AudioManager::class.java)
    private val focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANT)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()
        )
        .build()
    @Volatile private var running = false
    private var thread: Thread? = null

    @SuppressLint("MissingPermission")
    fun start(listener: ConformerRecitation) {
        stop()
        replay()?.let { return startReplay(it, listener) }
        val rate = ConformerTracker.SAMPLE_RATE
        val minimum = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_FLOAT)
        val record = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            rate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_FLOAT,
            maxOf(minimum, CHUNK_SAMPLES * 4 * 4),
        )
        check(record.state == AudioRecord.STATE_INITIALIZED) { "microphone unavailable" }
        audioManager?.requestAudioFocus(focus)
        record.startRecording()
        running = true
        thread = Thread({
            val buffer = FloatArray(CHUNK_SAMPLES)
            try {
                while (running) {
                    val read = record.read(buffer, 0, buffer.size, AudioRecord.READ_BLOCKING)
                    if (read > 0) listener.append(buffer.copyOf(read))
                }
            } finally {
                record.stop()
                record.release()
            }
        }, "audio-capture").apply {
            priority = Thread.MAX_PRIORITY
            start()
        }
    }

    private fun startReplay(samples: FloatArray, listener: ConformerRecitation) {
        running = true
        thread = Thread({
            var at = 0
            while (running && at < samples.size) {
                listener.append(samples.copyOfRange(at, minOf(at + CHUNK_SAMPLES, samples.size)))
                at += CHUNK_SAMPLES
                Thread.sleep(100)
            }
        }, "audio-replay").apply { start() }
    }

    fun stop() {
        running = false
        thread = null
        audioManager?.abandonAudioFocusRequest(focus)
    }

    private fun replay(): FloatArray? {
        if (!BuildConfig.DEBUG) return null
        val file = File(context.filesDir, "replay.raw").takeIf { it.exists() } ?: return null
        val bytes = ByteBuffer.wrap(file.readBytes()).order(ByteOrder.LITTLE_ENDIAN)
        return FloatArray(bytes.remaining() / 4) { bytes.float }
    }

    companion object {
        const val CHUNK_SAMPLES = ConformerTracker.SAMPLE_RATE / 10
    }
}
