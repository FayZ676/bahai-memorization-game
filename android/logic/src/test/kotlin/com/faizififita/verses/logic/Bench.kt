package com.faizififita.verses.logic

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.int
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

fun loadTokenizer(path: String): ConformerTokenizer =
    ConformerTokenizer(Json.decodeFromString(ConformerVocabulary.serializer(), File(path).readText()))

fun readWav(file: File): FloatArray {
    val bytes = ByteBuffer.wrap(file.readBytes()).order(ByteOrder.LITTLE_ENDIAN)
    bytes.position(12)
    var format = 0
    var bits = 0
    var channels = 1
    while (bytes.remaining() >= 8) {
        val id = ByteArray(4).also { bytes.get(it) }.decodeToString()
        val size = bytes.int
        val body = bytes.position()
        when (id) {
            "fmt " -> {
                format = bytes.short.toInt()
                channels = bytes.short.toInt()
                bytes.int
                bytes.int
                bytes.short
                bits = bytes.short.toInt()
            }
            "data" -> {
                val frames = size / (bits / 8) / channels
                return FloatArray(frames) {
                    val offset = body + it * channels * (bits / 8)
                    if (format == 3) bytes.getFloat(offset) else bytes.getShort(offset) / 32768f
                }
            }
        }
        bytes.position(body + size + (size and 1))
    }
    error("no data chunk in $file")
}

class OnnxPredictor(path: String) : ConformerSession.Predictor {
    private val environment = OrtEnvironment.getEnvironment()
    private val session = environment.createSession(path, OrtSession.SessionOptions().apply {
        setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
    })
    var calls = 0
        private set
    var nanos = 0L
        private set

    override fun predict(chunk: FloatArray): FloatArray {
        val started = System.nanoTime()
        OnnxTensor.createTensor(environment, FloatBuffer.wrap(chunk), longArrayOf(1, chunk.size.toLong())).use { input ->
            session.run(mapOf("audio" to input)).use { result ->
                val output = (result[0] as OnnxTensor).floatBuffer
                val rows = FloatArray(output.remaining())
                output.get(rows)
                calls++
                nanos += System.nanoTime() - started
                return rows
            }
        }
    }
}

fun main(arguments: Array<String>) {
    val takes = File(arguments.getOrElse(0) { "Tools/RecitationBench/takes" })
    val model = arguments.getOrElse(1) { "android/app/src/main/assets/conformer.onnx" }
    val vocabulary = arguments.getOrElse(2) { "MemorizationGame/Resources/conformer-vocabulary.json" }
    val out = File(arguments.getOrElse(3) { "build/bench-kotlin.json" })
    val tokenizer = loadTokenizer(vocabulary)
    val predictor = OnnxPredictor(model)
    val stems = takes.listFiles()!!.map { it.name }
        .filter { it.startsWith("bench-") && it.endsWith(".wav") }
        .map { it.removeSuffix(".wav") }
        .sorted()
    val output = linkedMapOf<String, JsonObject>()
    for (stem in stems) {
        val take = Json.parseToJsonElement(File(takes, "$stem.json").readText()).jsonObject
        val words = take["words"]!!.jsonArray.map { it.jsonPrimitive.content }
        val start = take["startIndex"]?.jsonPrimitive?.intOrNull ?: 0
        val audio = readWav(File(takes, "$stem.wav"))
        val session = ConformerSession(words, words.indices.toSet(), start, tokenizer, tokenizer.blank + 1)
        val credited = HashMap<Int, Double>()
        val flashes = mutableListOf<JsonObject>()
        val clock = System.nanoTime()
        var heard = 0
        while (heard <= audio.size) {
            val done = heard == audio.size
            val update = if (done) {
                session.finish(predictor)
            } else {
                val chunk = audio.copyOfRange(heard, minOf(heard + 1024, audio.size))
                heard += chunk.size
                session.append(chunk, predictor)
            }
            val at = (heard + if (done) ConformerTracker.LOOKAHEAD_SAMPLES else 0).toDouble() / ConformerTracker.SAMPLE_RATE
            for (index in update.credits) credited.putIfAbsent(index, at)
            update.flashed?.let {
                flashes += JsonObject(mapOf("index" to JsonPrimitive(it), "movedOn" to JsonPrimitive(false), "at" to JsonPrimitive(at)))
            }
            if (done) break
        }
        val recitable = ConformerAligner(words, tokenizer, ConformerTracker.FRAME_SECONDS).recitable
        val scored = recitable.associate { index ->
            index.toString() to (credited[index]?.let { at ->
                JsonObject(listOf("worst", "gop", "start", "end", "credited_at").associateWith {
                    JsonPrimitive(if (it == "worst" || it == "gop") 0.0 else at)
                })
            } ?: JsonNull)
        }
        output[stem] = JsonObject(mapOf(
            "words" to JsonObject(scored),
            "heard" to JsonPrimitive(""),
            "hidden" to JsonArray(recitable.map(::JsonPrimitive)),
            "misses" to JsonArray(flashes),
        ))
        println("$stem credited ${credited.size}/${recitable.size} in ${(System.nanoTime() - clock) / 1_000_000} ms")
    }
    out.parentFile?.mkdirs()
    out.writeText(Json { prettyPrint = true }.encodeToString(JsonObject.serializer(), JsonObject(output)))
    println("model ${File(model).name}: ${predictor.calls} windows, ${predictor.nanos / predictor.calls.coerceAtLeast(1) / 1_000_000} ms per window")
    println("wrote ${out.path}")
}
