package com.faizififita.verses.feature.browse

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Cancel
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.EditNote
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.faizififita.verses.feature.onboarding.CompletesTourStep
import com.faizififita.verses.feature.onboarding.LocalTour
import com.faizififita.verses.feature.onboarding.TourStep
import com.faizififita.verses.logic.BrowseRoute
import com.faizififita.verses.logic.FuzzySearch
import com.faizififita.verses.logic.Prayer
import com.faizififita.verses.logic.PrayerLibrary
import com.faizififita.verses.logic.SearchHit
import com.faizififita.verses.theme.AppTextToken
import com.faizififita.verses.theme.EmptyNote
import com.faizififita.verses.theme.IconSize
import com.faizififita.verses.theme.LocalFontScale
import com.faizififita.verses.theme.OptionSection
import com.faizififita.verses.theme.PassageCard
import com.faizififita.verses.theme.Radius
import com.faizififita.verses.theme.Screen
import com.faizififita.verses.theme.ScreenHeader
import com.faizififita.verses.theme.Spacing
import com.faizififita.verses.theme.Theme
import com.faizififita.verses.theme.Typography
import com.faizififita.verses.theme.card
import com.faizififita.verses.theme.haptic
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.withContext

@Composable
fun BrowseScreen(
    focusSection: String?,
    onBack: () -> Unit,
    onRoute: (BrowseRoute) -> Unit,
    onPreview: (Long, IntRange?) -> Unit,
    onPasteOwn: () -> Unit,
) {
    val tour = LocalTour.current
    var query by rememberSaveable { mutableStateOf("") }
    var results by remember { mutableStateOf<List<SearchHit>>(emptyList()) }
    var searching by remember { mutableStateOf(false) }
    val trimmed = query.trim()
    val choosingTourPassage = tour != null && tour.step.ordinal <= TourStep.PickPrayer.ordinal
    val list = rememberLazyListState()

    CompletesTourStep(TourStep.OpenBrowse)

    LaunchedEffect(Unit) { withContext(Dispatchers.Default) { FuzzySearch.prewarm() } }

    LaunchedEffect(trimmed) {
        if (trimmed.isEmpty()) {
            results = emptyList()
            searching = false
            return@LaunchedEffect
        }
        searching = true
        delay(120)
        val ranked = withContext(Dispatchers.Default) { FuzzySearch.rank(trimmed) { !isActive } }
        results = ranked
        searching = false
    }

    LaunchedEffect(focusSection) {
        val target = focusSection ?: return@LaunchedEffect
        val index = PrayerLibrary.collections.indexOfFirst { collection ->
            collection.name == target || collection.sections.any { it.name == target }
        }
        if (index >= 0) list.animateScrollToItem(index + 1)
    }

    Screen(header = { ScreenHeader("Writings", onBack = onBack) }) {
        SearchField(query) { query = it }
        LazyColumn(
            state = list,
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 16.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            when {
                trimmed.isEmpty() -> {
                    item(key = "paste") { PasteOwnRow(onPasteOwn) }
                    items(PrayerLibrary.collections, key = { it.name }) { collection ->
                        CollectionCard(
                            collection,
                            initiallyExpanded = !choosingTourPassage || collection.name == PrayerLibrary.HIDDEN_WORDS_COLLECTION,
                            focusSection = focusSection,
                            onRoute = onRoute,
                        )
                    }
                }
                searching -> item {
                    Box(Modifier.fillMaxWidth().padding(top = 40.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = Theme.muted, strokeWidth = 2.dp, modifier = Modifier.size(24.dp))
                    }
                }
                results.isEmpty() -> item { EmptyNote("No prayers match “$trimmed”.") }
                else -> item {
                    Column(Modifier.fillMaxWidth().card(Radius.group)) {
                        results.forEachIndexed { index, hit ->
                            if (index > 0) RowDivider()
                            SearchHitRow(hit) { onPreview(hit.prayer.id, hit.excerpt?.rangeInText) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SearchField(query: String, onChange: (String) -> Unit) {
    val scale = LocalFontScale.current
    Row(
        Modifier
            .padding(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 12.dp)
            .fillMaxWidth()
            .card(Radius.control)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(Icons.Outlined.Search, null, tint = Theme.muted, modifier = Modifier.size(IconSize.nav))
        Box(Modifier.weight(1f)) {
            if (query.isEmpty()) Text("Search prayers and writings", style = Typography.body.style(scale), color = Theme.faint)
            BasicTextField(
                query,
                onChange,
                singleLine = true,
                textStyle = Typography.body.style(scale).copy(color = Theme.ink),
                cursorBrush = SolidColor(Theme.accent),
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.None, autoCorrectEnabled = false),
                modifier = Modifier.fillMaxWidth(),
            )
        }
        if (query.isNotEmpty()) {
            Icon(
                Icons.Outlined.Cancel, "Clear", tint = Theme.muted,
                modifier = Modifier.size(IconSize.nav).haptic { onChange("") },
            )
        }
    }
}

@Composable
private fun PasteOwnRow(onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().card(Radius.group).haptic(onClick = onClick).padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(Icons.Outlined.EditNote, null, tint = Theme.accent, modifier = Modifier.size(IconSize.nav))
        Text("Paste your own text", style = Typography.body.style(LocalFontScale.current), color = Theme.muted)
    }
}

@Composable
private fun CollectionCard(
    collection: PrayerLibrary.Collection,
    initiallyExpanded: Boolean,
    focusSection: String?,
    onRoute: (BrowseRoute) -> Unit,
) {
    Column(Modifier.fillMaxWidth().card(Radius.group)) {
        DisclosureNode(collection.name, font = Typography.passageTitle, color = Theme.ink, initiallyExpanded = initiallyExpanded || collection.name == focusSection) {
            for (section in collection.sections) {
                RowDivider(0.dp, 0.dp)
                val only = section.categories.singleOrNull()
                if (only != null) {
                    LinkRow(section.name, "${section.prayerCount}", Typography.caption, Theme.muted, 0.3f, 20.dp) {
                        onRoute(BrowseRoute.Category(section.name, only.name))
                    }
                } else {
                    DisclosureNode(
                        section.name,
                        subtitle = "${section.prayerCount}",
                        font = Typography.caption,
                        color = Theme.muted,
                        tracking = 0.3f,
                        indent = 4.dp,
                        initiallyExpanded = section.name == focusSection,
                    ) {
                        section.categories.forEachIndexed { index, category ->
                            if (index > 0) RowDivider(32.dp)
                            LinkRow(category.name, "${category.prayers.size}", Typography.body, Theme.ink, 0f, 32.dp) {
                                onRoute(BrowseRoute.Category(section.name, category.name))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DisclosureNode(
    title: String,
    subtitle: String? = null,
    font: AppTextToken,
    color: Color,
    tracking: Float = 0f,
    indent: Dp = 0.dp,
    initiallyExpanded: Boolean = false,
    content: @Composable () -> Unit,
) {
    var expanded by rememberSaveable(title) { mutableStateOf(initiallyExpanded) }
    val rotation by animateFloatAsState(if (expanded) 90f else 0f, label = "disclosure")
    val scale = LocalFontScale.current
    Column {
        Row(
            Modifier
                .fillMaxWidth()
                .haptic { expanded = !expanded }
                .padding(start = 16.dp + indent, end = 16.dp, top = 14.dp, bottom = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(title, style = font.style(scale, tracking), color = color, modifier = Modifier.weight(1f))
            if (subtitle != null) Text(subtitle, style = Typography.footnote.style(scale), color = Theme.faint)
            Icon(Icons.Outlined.ChevronRight, null, tint = Theme.faint, modifier = Modifier.size(IconSize.row).rotate(rotation))
        }
        AnimatedVisibility(expanded, enter = expandVertically() + fadeIn(), exit = shrinkVertically() + fadeOut()) {
            Column { content() }
        }
    }
}

@Composable
private fun LinkRow(title: String, count: String, font: AppTextToken, color: Color, tracking: Float, start: Dp, onClick: () -> Unit) {
    val scale = LocalFontScale.current
    Row(
        Modifier.fillMaxWidth().haptic(onClick = onClick).padding(start = start, end = 16.dp, top = 13.dp, bottom = 13.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(title, style = font.style(scale, tracking), color = color, maxLines = 2, modifier = Modifier.weight(1f))
        Text(count, style = Typography.footnote.style(scale), color = Theme.faint)
        Icon(Icons.Outlined.ChevronRight, null, tint = Theme.faint, modifier = Modifier.size(IconSize.row))
    }
}

@Composable
fun RowDivider(start: Dp = Spacing.lg, end: Dp = Spacing.lg) {
    HorizontalDivider(Modifier.padding(start = start, end = end), color = Theme.hairline)
}

@Composable
fun PrayerRow(prayer: Prayer, showSection: Boolean = false, onClick: () -> Unit) {
    PassageCard(
        title = prayer.title,
        author = prayer.author,
        section = if (showSection) prayer.section else null,
        detail = "${prayer.wordCount} words",
        modifier = Modifier.haptic(onClick = onClick),
    )
}

@Composable
private fun SearchHitRow(hit: SearchHit, onClick: () -> Unit) {
    val excerpt = hit.excerpt ?: return PrayerRow(hit.prayer, showSection = true, onClick = onClick)
    val scale = LocalFontScale.current
    val accent = Theme.accent
    val snippet = remember(excerpt, accent) {
        buildAnnotatedString {
            append(excerpt.snippet)
            val range = excerpt.highlightInSnippet
            if (range.last < excerpt.snippet.length && !range.isEmpty()) addStyle(SpanStyle(color = accent), range.first, range.last + 1)
        }
    }
    Column(
        Modifier.fillMaxWidth().haptic(onClick = onClick).padding(horizontal = Spacing.lg, vertical = Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Spacing.xs),
    ) {
        Text(snippet, style = Typography.excerpt.style(scale), color = Theme.ink, maxLines = 3, overflow = TextOverflow.Ellipsis)
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            Text(hit.prayer.title, style = Typography.footnote.style(scale), color = Theme.faint, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
            Text("·", style = Typography.footnote.style(scale), color = Theme.faint)
            Text(hit.prayer.section, style = Typography.footnote.style(scale), color = Theme.faint, maxLines = 1)
        }
    }
}

@Composable
fun CategoryScreen(section: String, name: String, onBack: () -> Unit, onPrayer: (Prayer) -> Unit) {
    val category = PrayerLibrary.category(name, section)
    Screen(header = { ScreenHeader(name, onBack = onBack) }) {
        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = Spacing.lg, end = Spacing.lg, bottom = Spacing.lg)) {
            item {
                OptionSection {
                    category?.prayers?.forEachIndexed { index, prayer ->
                        if (index > 0) RowDivider()
                        PrayerRow(prayer) { onPrayer(prayer) }
                    }
                }
            }
        }
    }
}
