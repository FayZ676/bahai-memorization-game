package com.faizififita.verses.feature.library

import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material.icons.outlined.Archive
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Unarchive
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.faizififita.verses.logic.Passage
import com.faizififita.verses.logic.Percent
import com.faizififita.verses.store.AppStore
import com.faizififita.verses.support.Feedback
import com.faizififita.verses.theme.IconButton
import com.faizififita.verses.theme.IconSize
import com.faizififita.verses.theme.LocalFontScale
import com.faizififita.verses.theme.PassageCard
import com.faizififita.verses.theme.Radius
import com.faizififita.verses.theme.Screen
import com.faizififita.verses.theme.ScreenHeader
import com.faizififita.verses.theme.Spacing
import com.faizififita.verses.theme.Theme
import com.faizififita.verses.theme.Typography
import com.faizififita.verses.theme.card
import com.faizififita.verses.theme.haptic

private const val DELETE_TITLE_WORD_LIMIT = 6

@Composable
fun LibraryScreen(
    store: AppStore,
    onSettings: () -> Unit,
    onBrowse: () -> Unit,
    onOpen: (Passage) -> Unit,
) {
    var pendingDelete by rememberSaveable { mutableStateOf<String?>(null) }
    var showsArchived by rememberSaveable { mutableStateOf(false) }

    Screen(header = {
        ScreenHeader(
            title = "Library",
            leading = { IconButton(Icons.Outlined.Settings, "Settings", tint = Theme.accent, onClick = onSettings) },
            trailing = { IconButton(Icons.AutoMirrored.Outlined.MenuBook, "Writings", tint = Theme.accent, onClick = onBrowse) },
        )
    }) {
        if (store.passages.isEmpty()) {
            EmptyLibrary(onBrowse)
        } else {
            LazyColumn(
                Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = Spacing.lg, end = Spacing.lg, bottom = Spacing.xxl),
                verticalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                items(store.activePassages, key = { it.id }) { passage ->
                    PassageRow(store, passage, Modifier.animateItem(), onOpen) { pendingDelete = it.id }
                }
                val archived = store.archivedPassages
                if (archived.isNotEmpty()) {
                    item(key = "archived-header") {
                        ArchivedHeader(archived.size, showsArchived, Modifier.animateItem()) { showsArchived = !showsArchived }
                    }
                    if (showsArchived) {
                        items(archived, key = { it.id }) { passage ->
                            PassageRow(store, passage, Modifier.animateItem(), onOpen) { pendingDelete = it.id }
                        }
                    }
                }
                item { Spacer(Modifier.navigationBarsPadding()) }
            }
        }
    }

    val deleting = pendingDelete?.let(store::passage)
    if (deleting != null) {
        AlertDialog(
            onDismissRequest = { pendingDelete = null },
            title = { Text("Delete this passage?") },
            text = { Text("“${shortened(deleting.title)}” and all its progress will be removed. This can't be undone.") },
            confirmButton = {
                TextButton(onClick = {
                    Feedback.tap()
                    store.deletePassage(deleting)
                    pendingDelete = null
                }) { Text("Delete", color = Theme.warn) }
            },
            dismissButton = {
                TextButton(onClick = { Feedback.tap(); pendingDelete = null }) { Text("Cancel", color = Theme.muted) }
            },
            containerColor = Theme.raised,
            titleContentColor = Theme.ink,
            textContentColor = Theme.muted,
        )
    }
}

private fun shortened(title: String): String {
    val words = title.split(" ")
    if (words.size <= DELETE_TITLE_WORD_LIMIT) return title
    return words.take(DELETE_TITLE_WORD_LIMIT).joinToString(" ") + "…"
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PassageRow(store: AppStore, passage: Passage, modifier: Modifier, onOpen: (Passage) -> Unit, onDelete: (Passage) -> Unit) {
    val state = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            when (value) {
                SwipeToDismissBoxValue.EndToStart -> onDelete(passage)
                SwipeToDismissBoxValue.StartToEnd -> {
                    Feedback.tap()
                    store.setArchived(passage, !passage.isArchived)
                }
                SwipeToDismissBoxValue.Settled -> {}
            }
            false
        },
    )
    SwipeToDismissBox(
        state = state,
        modifier = modifier.clip(RoundedCornerShape(Radius.card)),
        backgroundContent = {
            val toArchive = state.dismissDirection == SwipeToDismissBoxValue.StartToEnd
            Box(
                Modifier
                    .fillMaxSize()
                    .background(if (toArchive) Theme.faint else Theme.warn)
                    .padding(horizontal = Spacing.xl),
                contentAlignment = if (toArchive) Alignment.CenterStart else Alignment.CenterEnd,
            ) {
                Icon(
                    when {
                        !toArchive -> Icons.Outlined.Delete
                        passage.isArchived -> Icons.Outlined.Unarchive
                        else -> Icons.Outlined.Archive
                    },
                    when {
                        !toArchive -> "Delete"
                        passage.isArchived -> "Unarchive"
                        else -> "Archive"
                    },
                    tint = Theme.bg,
                )
            }
        },
    ) {
        PassageCard(
            title = passage.title,
            author = passage.author,
            section = passage.section,
            detail = Percent.label(passage.hiddenFraction),
            modifier = Modifier.card().haptic { onOpen(passage) },
        )
    }
}

@Composable
private fun ArchivedHeader(count: Int, expanded: Boolean, modifier: Modifier, onToggle: () -> Unit) {
    val rotation by animateFloatAsState(if (expanded) 90f else 0f, label = "chevron")
    val scale = LocalFontScale.current
    Row(
        modifier
            .fillMaxWidth()
            .haptic(onClick = onToggle)
            .padding(start = Spacing.xs, end = Spacing.xs, top = Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Icon(Icons.Outlined.Archive, null, tint = Theme.faint, modifier = Modifier.size(IconSize.small))
        Text("Archived", style = Typography.label.weight(androidx.compose.ui.text.font.FontWeight.Normal).style(scale), color = Theme.faint)
        Text("$count", style = Typography.footnote.style(scale), color = Theme.faint)
        Spacer(Modifier.weight(1f))
        Icon(Icons.Outlined.ChevronRight, null, tint = Theme.faint, modifier = Modifier.size(IconSize.row).rotate(rotation))
    }
}

@Composable
private fun EmptyLibrary(onBrowse: () -> Unit) {
    Column(
        Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        IconButton(Icons.AutoMirrored.Outlined.MenuBook, "Writings", tint = Theme.accent, size = 96.dp, iconSize = 34.dp, onClick = onBrowse)
        Spacer(Modifier.height(Spacing.xl))
        Text(
            "Choose a prayer to get started",
            style = Typography.body.style(LocalFontScale.current),
            color = Theme.faint,
            textAlign = TextAlign.Center,
        )
    }
}
