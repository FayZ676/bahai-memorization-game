package com.faizififita.verses

import android.app.Activity
import android.os.Bundle
import android.util.Log
import com.faizififita.verses.feature.session.ConformerRecitation
import com.faizififita.verses.logic.ConformerAligner
import com.faizififita.verses.logic.ConformerSession
import com.faizififita.verses.logic.ConformerTracker
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

class BenchActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Thread { run() }.start()
    }

    private fun run() {
        val takes = File(filesDir, "takes")
        val loaded = runBlocking { ConformerRecitation.preload().await() }
        val tokenizer = loaded.tokenizer
        val output = linkedMapOf<String, JsonObject>()
        var windows = 0
        var nanos = 0L
        val timed = ConformerSession.Predictor { chunk ->
            val started = System.nanoTime()
            loaded.predictor.predict(chunk).also {
                windows++
                nanos += System.nanoTime() - started
            }
        }
        val stems = takes.listFiles().orEmpty().map { it.name }.filter { it.endsWith(".wav") }.map { it.removeSuffix(".wav") }.sorted()
        for (stem in stems) {
            val take = Json.parseToJsonElement(File(takes, "$stem.json").readText()).jsonObject
            val words = take["words"]!!.jsonArray.map { it.jsonPrimitive.content }
            val start = take["startIndex"]?.jsonPrimitive?.intOrNull ?: 0
            val audio = readWav(File(takes, "$stem.wav"))
            val session = ConformerSession(words, words.indices.toSet(), start, tokenizer, tokenizer.blank + 1)
            val credited = HashMap<Int, Double>()
            val flashes = mutableListOf<JsonObject>()
            var heard = 0
            val clock = System.nanoTime()
            while (heard <= audio.size) {
                val done = heard == audio.size
                val update = if (done) session.finish(timed) else {
                    val chunk = audio.copyOfRange(heard, minOf(heard + 1024, audio.size))
                    heard += chunk.size
                    session.append(chunk, timed)
                }
                val at = (heard + if (done) ConformerTracker.LOOKAHEAD_SAMPLES else 0).toDouble() / ConformerTracker.SAMPLE_RATE
                for (index in update.credits) credited.putIfAbsent(index, at)
                update.flashed?.let { flashes += JsonObject(mapOf("index" to JsonPrimitive(it), "movedOn" to JsonPrimitive(false), "at" to JsonPrimitive(at))) }
                if (done) break
            }
            val recitable = ConformerAligner(words, tokenizer, ConformerTracker.FRAME_SECONDS).recitable
            output[stem] = JsonObject(mapOf(
                "words" to JsonObject(recitable.associate { index ->
                    index.toString() to (credited[index]?.let { at ->
                        JsonObject(listOf("worst", "gop", "start", "end", "credited_at").associateWith { JsonPrimitive(if (it == "worst" || it == "gop") 0.0 else at) })
                    } ?: JsonNull)
                }),
                "heard" to JsonPrimitive(""),
                "hidden" to JsonArray(recitable.map(::JsonPrimitive)),
                "misses" to JsonArray(flashes),
            ))
            Log.i("BENCH", "$stem credited ${credited.size}/${recitable.size} in ${(System.nanoTime() - clock) / 1_000_000} ms, audio ${audio.size / 16} ms")
        }
        File(filesDir, "bench-android.json").writeText(JsonObject(output).toString())
        Log.i("BENCH", "done: $windows windows, ${nanos / windows.coerceAtLeast(1) / 1_000_000} ms per window")
    }

    private fun readWav(file: File): FloatArray {
        val bytes = ByteBuffer.wrap(file.readBytes()).order(ByteOrder.LITTLE_ENDIAN)
        bytes.position(12)
        var format = 0
        var bits = 0
        var channels = 1
        while (bytes.remaining() >= 8) {
            val id = ByteArray(4).also { bytes.get(it) }.decodeToString()
            val size = bytes.int
            val body = bytes.position()
            if (id == "fmt ") {
                format = bytes.short.toInt()
                channels = bytes.short.toInt()
                bytes.int
                bytes.int
                bytes.short
                bits = bytes.short.toInt()
            } else if (id == "data") {
                return FloatArray(size / (bits / 8) / channels) {
                    val offset = body + it * channels * (bits / 8)
                    if (format == 3) bytes.getFloat(offset) else bytes.getShort(offset) / 32768f
                }
            }
            bytes.position(body + size + (size and 1))
        }
        error("no data in $file")
    }
}
