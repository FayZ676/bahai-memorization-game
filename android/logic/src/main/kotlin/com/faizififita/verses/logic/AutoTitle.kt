package com.faizififita.verses.logic

object AutoTitle {
    const val WORD_LIMIT = 8

    fun from(text: String): String {
        val words = text.split(Regex("\\s+")).filter { it.isNotEmpty() }
        val opening = words.take(WORD_LIMIT).joinToString(" ")
        if (words.size <= WORD_LIMIT) return opening
        return opening.trim(',', ';', ':') + "…"
    }

    fun from(heading: String, text: String): String {
        val name = unnumbered(heading)
        if (name.isEmpty() || text.startsWith(name)) return from(text)
        return from(name)
    }

    private fun unnumbered(heading: String): String =
        heading.dropWhile { it.isDigit() }.dropWhile { it == '.' || it == ' ' }.trim(' ')
}
