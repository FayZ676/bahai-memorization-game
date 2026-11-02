package com.faizififita.verses.feature.browse

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.faizififita.verses.feature.onboarding.CompletesTourStep
import com.faizififita.verses.feature.onboarding.TourStep
import com.faizififita.verses.logic.Passage
import com.faizififita.verses.logic.PrayerLibrary
import com.faizififita.verses.store.AppStore
import com.faizififita.verses.theme.Colophon
import com.faizififita.verses.theme.IconButton
import com.faizififita.verses.theme.InfoNote
import com.faizififita.verses.theme.LocalFontScale
import com.faizififita.verses.theme.Radius
import com.faizififita.verses.theme.Screen
import com.faizififita.verses.theme.ScreenHeader
import com.faizififita.verses.theme.Spacing
import com.faizififita.verses.theme.Theme
import com.faizififita.verses.theme.Typography
import com.faizififita.verses.theme.card

private const val MAX_BLOCK_LENGTH = 1200
private const val LINE_GAP = 4

private data class TextBlock(val text: String, val range: IntRange) {
    fun localRange(textRange: IntRange): IntRange? {
        val lower = maxOf(range.first, textRange.first)
        val upper = minOf(range.last + 1, textRange.last + 1)
        if (lower >= upper) return null
        return (lower - range.first) until (upper - range.first)
    }

    companion object {
        fun split(text: String): List<TextBlock> {
            val blocks = mutableListOf<TextBlock>()
            val pending = mutableListOf<String>()
            var pendingLength = 0
            var blockStart = 0
            var cursor = 0
            fun flush() {
                if (pending.isEmpty()) return
                blocks += TextBlock(pending.joinToString("\n"), blockStart until cursor)
                pending.clear()
                pendingLength = 0
                blockStart = cursor
            }
            for (line in text.split("\n")) {
                pending += line
                pendingLength += line.length
                cursor += line.length + 1
                if (pendingLength >= MAX_BLOCK_LENGTH) flush()
            }
            flush()
            return blocks
        }
    }
}

@Composable
fun WritingReader(heading: String, author: String?, attribution: String?, text: String, highlight: IntRange?) {
    val scale = LocalFontScale.current
    val blocks = remember(text) { TextBlock.split(text) }
    val list = rememberLazyListState()
    val accent = Theme.accent
    val verse = Typography.verse.style(scale).copy(lineHeight = (Typography.verse.size * scale * 1.08f * 1.25f + LINE_GAP).sp)
    val initial = Typography.verseInitial.style(scale)

    LaunchedEffect(highlight) {
        val range = highlight ?: return@LaunchedEffect
        val index = blocks.indexOfFirst { it.localRange(range) != null }
        if (index >= 0) list.scrollToItem(index + 1)
    }

    LazyColumn(
        state = list,
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(LINE_GAP.dp),
    ) {
        item {
            Column(Modifier.padding(bottom = (16 - LINE_GAP).dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                if (heading.isNotEmpty()) Text(heading, style = Typography.heading.style(scale), color = Theme.ink)
                if (attribution != null) Text(attribution, style = Typography.footnote.style(scale), color = Theme.faint)
            }
        }
        itemsIndexed(blocks) { index, block ->
            val annotated = remember(block, highlight, accent, scale) {
                buildAnnotatedString {
                    append(block.text)
                    highlight?.let(block::localRange)?.let { local ->
                        addStyle(SpanStyle(background = accent.copy(alpha = 0.22f)), local.first, local.last + 1)
                    }
                    if (index == 0) {
                        block.text.take(3).indexOfFirst { it.isLetter() }.takeIf { it >= 0 }?.let { at ->
                            addStyle(initial.toSpanStyle(), at, at + 1)
                        }
                    }
                }
            }
            Text(annotated, style = verse, color = Theme.ink, modifier = Modifier.fillMaxWidth())
        }
        if (author != null) item { Box(Modifier.padding(top = (16 - LINE_GAP).dp)) { Colophon(author) } }
    }
}

@Composable
fun PrayerPreviewScreen(store: AppStore, prayerID: Long, highlight: IntRange?, onBack: () -> Unit, onAdded: () -> Unit, onOpenExisting: (Passage) -> Unit) {
    val prayer = PrayerLibrary.prayer(prayerID) ?: return
    CompletesTourStep(TourStep.PickPrayer)
    Screen(header = {
        ScreenHeader("Preview", onBack = onBack, trailing = {
            IconButton(Icons.Outlined.VisibilityOff, "Memorize", tint = Theme.accent) {
                val existing = store.passageForPrayer(prayer.id)
                if (existing != null) return@IconButton onOpenExisting(existing)
                store.createPassage(
                    title = prayer.title,
                    text = Passage.paragraphsOf(prayer.text).joinToString("\n"),
                    author = prayer.author,
                    section = prayer.deepestSection,
                    sourceID = prayer.id,
                )
                onAdded()
            }
        })
    }) {
        WritingReader(prayer.heading, prayer.author, prayer.path, prayer.text, highlight)
    }
}

@Composable
fun PassageTextScreen(store: AppStore, passageID: String, onBack: () -> Unit) {
    val passage = store.passage(passageID) ?: return
    Screen(header = { ScreenHeader(passage.title, onBack = onBack) }) {
        WritingReader("", passage.author, passage.sourcePath, passage.text.replace("\n", "\n\n"), null)
    }
}

@Composable
fun ImportScreen(store: AppStore, editingID: String?, onBack: () -> Unit, onCreated: () -> Unit) {
    val editing = editingID?.let(store::passage)
    var title by rememberSaveable { mutableStateOf(editing?.title ?: "") }
    var content by rememberSaveable { mutableStateOf(editing?.text ?: "") }
    val trimmedTitle = title.trim()
    val paragraphs = Passage.paragraphsOf(content)
    val valid = trimmedTitle.isNotEmpty() && paragraphs.isNotEmpty()
    val scale = LocalFontScale.current

    Screen(header = {
        ScreenHeader(if (editing == null) "Import" else "Edit", onBack = onBack, trailing = {
            IconButton(
                if (editing == null) Icons.Outlined.Add else Icons.Outlined.Check,
                if (editing == null) "Add" else "Save",
                tint = if (valid) Theme.accent else Theme.disabled,
                enabled = valid,
            ) {
                if (editing != null) {
                    store.updatePassage(editing, trimmedTitle, paragraphs.joinToString("\n"))
                    onBack()
                } else {
                    store.createPassage(trimmedTitle, paragraphs.joinToString("\n"))
                    onCreated()
                }
            }
        })
    }) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).imePadding().padding(start = 16.dp, end = 16.dp, bottom = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                Text("Title", style = Typography.label.style(scale), color = Theme.muted)
                Field(title, { title = it }, "Title", Typography.body.style(scale), KeyboardCapitalization.Words, singleLine = true)
            }
            InfoNote(Typography.caption, text = "Every line of text becomes its own paragraph.")
            Field(
                content, { content = it },
                "In the name of God, the Most Glorious.\nGlory be to Thee, O Lord my God.\nI bear witness to Thy unity and Thy oneness.",
                Typography.verse.style(scale), KeyboardCapitalization.Sentences, singleLine = false,
                modifier = Modifier.heightIn(min = 320.dp),
            )
        }
    }
}

@Composable
fun Field(
    value: String,
    onChange: (String) -> Unit,
    placeholder: String,
    style: androidx.compose.ui.text.TextStyle,
    capitalization: KeyboardCapitalization,
    singleLine: Boolean,
    modifier: Modifier = Modifier,
    keyboardType: androidx.compose.ui.text.input.KeyboardType = androidx.compose.ui.text.input.KeyboardType.Text,
) {
    Box(modifier.fillMaxWidth().card(Radius.control).padding(12.dp)) {
        if (value.isEmpty()) Text(placeholder, style = style, color = Theme.faint)
        BasicTextField(
            value,
            onChange,
            singleLine = singleLine,
            textStyle = style.copy(color = Theme.ink),
            cursorBrush = SolidColor(Theme.accent),
            keyboardOptions = KeyboardOptions(capitalization = capitalization, keyboardType = keyboardType),
            modifier = Modifier.fillMaxWidth().then(if (singleLine) Modifier else Modifier.heightIn(min = 296.dp)),
        )
    }
}
