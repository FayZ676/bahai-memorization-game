package com.faizififita.verses.support

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

object FeedbackForm {
    const val PROBLEM = "Problem"
    const val IDEA = "Idea"

    private const val FORM_ID = "1FAIpQLSe3wZs_Ya_cS4kcqYBTX-fOsLi9MpvD9S90RwKAfWqBt5uEiA"
    private const val KIND = "entry.1700380398"
    private const val MESSAGE = "entry.611281190"
    private const val EMAIL = "entry.1243171085"

    suspend fun submit(kind: String, message: String, email: String): Boolean = withContext(Dispatchers.IO) {
        val fields = mapOf(
            KIND to kind,
            MESSAGE to "$message\n\n———\n${AppInfo.diagnostics}",
            EMAIL to email,
        ).filterValues { it.isNotEmpty() }
        val body = fields.entries.joinToString("&") { "${it.key}=${URLEncoder.encode(it.value, "UTF-8")}" }
        runCatching {
            val connection = URL("https://docs.google.com/forms/d/e/$FORM_ID/formResponse").openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.connectTimeout = 15_000
            connection.readTimeout = 15_000
            connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
            connection.outputStream.use { it.write(body.toByteArray()) }
            val status = connection.responseCode
            connection.disconnect()
            status in 200..299
        }.getOrDefault(false)
    }
}
