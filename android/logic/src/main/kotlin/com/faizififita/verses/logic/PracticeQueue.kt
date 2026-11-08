package com.faizififita.verses.logic

import java.time.Instant
import java.time.ZoneId
import java.time.temporal.ChronoUnit

object PracticeQueue {
    fun next(passages: List<Passage>): Passage? =
        passages
            .filter { !it.isArchived }
            .minWithOrNull(compareBy<Passage>({ it.lastPracticed ?: Long.MIN_VALUE }, { it.dateAdded }))
}

object PracticeAge {
    fun days(lastPracticed: Long?, now: Long, zone: ZoneId = ZoneId.systemDefault()): Long? {
        val practiced = lastPracticed ?: return null
        val then = Instant.ofEpochMilli(practiced).atZone(zone).toLocalDate()
        val today = Instant.ofEpochMilli(now).atZone(zone).toLocalDate()
        return ChronoUnit.DAYS.between(then, today).coerceAtLeast(0)
    }

    fun label(lastPracticed: Long?, now: Long, zone: ZoneId = ZoneId.systemDefault()): String =
        when (val days = days(lastPracticed, now, zone)) {
            null -> "Not practiced yet"
            0L -> "Practiced today"
            1L -> "Practiced yesterday"
            else -> "$days days since practice"
        }
}
