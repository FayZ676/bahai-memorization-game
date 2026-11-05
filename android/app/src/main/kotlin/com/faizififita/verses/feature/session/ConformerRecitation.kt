package com.faizififita.verses.feature.session

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.faizififita.verses.BuildConfig
import com.faizififita.verses.logic.ConformerSession
import com.faizififita.verses.logic.ConformerTokenizer
import com.faizififita.verses.logic.ConformerTracker
import com.faizififita.verses.logic.ConformerVocabulary
import kotlinx.coroutines.CompletableDeferred
import kotlinx.serialization.json.Json
import java.io.File
import java.nio.FloatBuffer
import java.util.concurrent.Executors

class ConformerRecitation private constructor(
    private val loaded: Loaded,
    words: List<String>,
    hidden: List<Int>,
    start: Int,
    private val onCredits: (List<Int>) -> Unit,
    private val onFlash: (Int) -> Unit,
) {
    internal class Loaded(private val environment: OrtEnvironment, private val model: OrtSession, val tokenizer: ConformerTokenizer) {
        private val input = FloatBuffer.allocate(ConformerTracker.WINDOW_SAMPLES)
        private val shape = longArrayOf(1, ConformerTracker.WINDOW_SAMPLES.toLong())
        val predictor = ConformerSession.Predictor(::predict)

        private fun predict(chunk: FloatArray): FloatArray? = runCatching {
            input.clear()
            input.put(chunk, 0, minOf(chunk.size, input.capacity()))
            input.flip()
            OnnxTensor.createTensor(environment, input, shape).use { tensor ->
                model.run(mapOf("audio" to tensor)).use { result ->
                    val output = (result[0] as OnnxTensor).floatBuffer
                    FloatArray(output.remaining()).also { output.get(it) }
                }
            }
        }.onFailure { trace("prediction failed $it") }.getOrNull()
    }

    private val queue = Executors.newSingleThreadExecutor { Thread(it, "conformer-recitation").apply { priority = Thread.MAX_PRIORITY - 1 } }
    private val main = Handler(Looper.getMainLooper())
    private val session = ConformerSession(words, hidden.toSet(), start, loaded.tokenizer, loaded.tokenizer.blank + 1)
    private val predictor = loaded.predictor
    private var closed = false

    @Synchronized
    fun append(chunk: FloatArray) {
        if (closed) return
        queue.execute { listen(false) { session.append(chunk, predictor) } }
    }

    @Synchronized
    fun updateHidden(hidden: List<Int>) {
        if (closed) return
        queue.execute { session.setHidden(hidden.toSet()) }
    }

    @Synchronized
    fun finish() {
        if (closed) return
        closed = true
        queue.execute { listen(true) { session.finish(predictor) } }
        queue.shutdown()
    }

    private fun listen(done: Boolean, work: () -> ConformerSession.Update) {
        val started = System.nanoTime()
        val update = work()
        if (update.hops == 0) return
        trace("hop done=$done took=${(System.nanoTime() - started) / 1_000_000}ms credited=${update.credits} flashed=${update.flashed ?: "-"}")
        val credited = update.credits.toList()
        if (credited.isNotEmpty()) main.post { onCredits(credited) }
        update.flashed?.let { flashed -> main.post { onFlash(flashed) } }
    }

    companion object {
        private lateinit var context: Context
        private var loading: CompletableDeferred<Loaded>? = null
        private val loader = Executors.newSingleThreadExecutor()

        fun install(context: Context) {
            this.context = context.applicationContext
        }

        @Synchronized
        internal fun preload(): CompletableDeferred<Loaded> {
            loading?.let { return it }
            val deferred = CompletableDeferred<Loaded>()
            loading = deferred
            loader.execute {
                runCatching {
                    val started = System.nanoTime()
                    val vocabulary = Json.decodeFromString(
                        ConformerVocabulary.serializer(),
                        context.assets.open("conformer-vocabulary.json").bufferedReader().use { it.readText() },
                    )
                    val environment = OrtEnvironment.getEnvironment()
                    val options = OrtSession.SessionOptions().apply {
                        setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
                        setIntraOpNumThreads(threads())
                    }
                    val model = environment.createSession(modelFile().absolutePath, options)
                    trace("model loaded in ${(System.nanoTime() - started) / 1_000_000}ms")
                    Loaded(environment, model, ConformerTokenizer(vocabulary))
                }.onSuccess(deferred::complete).onFailure {
                    trace("model failed $it")
                    synchronized(this) { loading = null }
                    deferred.completeExceptionally(it)
                }
            }
            return deferred
        }

        suspend fun make(
            words: List<String>,
            hidden: List<Int>,
            start: Int,
            onCredits: (List<Int>) -> Unit,
            onFlash: (Int) -> Unit,
        ): ConformerRecitation = ConformerRecitation(preload().await(), words, hidden, start, onCredits, onFlash)

        private fun threads(): Int = Runtime.getRuntime().availableProcessors().coerceIn(2, 4)

        private fun modelFile(): File {
            val target = File(context.noBackupFilesDir, "conformer-${BuildConfig.VERSION_CODE}.onnx")
            if (target.exists()) return target
            context.noBackupFilesDir.listFiles { file -> file.name.startsWith("conformer-") }?.forEach { it.delete() }
            val partial = File(target.parentFile, "${target.name}.partial")
            context.assets.open("conformer.onnx").use { source -> partial.outputStream().use { source.copyTo(it, 1 shl 20) } }
            partial.renameTo(target)
            return target
        }

        fun trace(message: String) {
            if (BuildConfig.DEBUG) Log.d("RECITE", message)
        }
    }
}
