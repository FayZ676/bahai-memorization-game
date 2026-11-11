package com.faizififita.verses.feature.session

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationState
import androidx.compose.animation.core.animateDecay
import androidx.compose.animation.core.DecayAnimationSpec
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animate
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.calculateTargetValue
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.rememberSplineBasedDecay
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.FlingBehavior
import androidx.compose.foundation.gestures.ScrollScope
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.DragInteraction
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.ErrorOutline
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.MoreHoriz
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material.icons.automirrored.outlined.Send
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.faizififita.verses.feature.onboarding.LocalTour
import com.faizififita.verses.feature.onboarding.TourStep
import com.faizififita.verses.feature.onboarding.ClearsTourButton
import com.faizififita.verses.feature.onboarding.CompletesTourStep
import com.faizififita.verses.logic.Passage
import com.faizififita.verses.logic.Difficulty
import com.faizififita.verses.store.AppStore
import com.faizififita.verses.support.Feedback
import com.faizififita.verses.support.ReviewPrompt
import com.faizififita.verses.theme.IconButton
import com.faizififita.verses.theme.LocalFontScale
import com.faizififita.verses.theme.Motion
import com.faizififita.verses.theme.Radius
import com.faizififita.verses.theme.ScreenHeader
import com.faizififita.verses.theme.Spacing
import com.faizififita.verses.theme.Theme
import com.faizififita.verses.theme.Typography
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.sin

private const val PAGE_TOP_MARGIN = 18
private const val FOLLOW_THRESHOLD = 0.7f
private const val RAIL_SAMPLES = 48
private const val TIP_HEIGHT = 40
private const val SNAP_REACH = 0.3f

@Stable
private class Highlights {
    var recited by mutableStateOf(emptySet<Int>())
        private set
    var batchPlace by mutableStateOf(emptyMap<Int, Int>())
        private set
    var flashing by mutableStateOf<Int?>(null)
    var shakes by mutableIntStateOf(0)
    private var setAside = emptySet<Int>()

    fun clear() {
        recited = emptySet()
        batchPlace = emptyMap()
        setAside = emptySet()
    }

    fun putAside(index: Int) {
        recited = recited - index
        setAside = setAside + index
    }

    fun recite(indices: List<Int>) {
        val fresh = (indices.toSet() - recited).sorted()
        batchPlace = batchPlace + fresh.withIndex().associate { (place, index) -> index to place }
        recited = recited + fresh
    }

    fun unattempted(passage: Passage, from: Int) = passage.recitableIndices(from).filter { it !in recited && it !in setAside }
}

@Composable
fun SessionScreen(
    store: AppStore,
    passageID: String,
    onBack: () -> Unit,
    onFullText: () -> Unit,
    onEdit: () -> Unit,
    onReportIssue: () -> Unit,
    onFeedback: () -> Unit,
) {
    val context = LocalContext.current
    val density = LocalDensity.current
    val scope = rememberCoroutineScope()
    val tour = LocalTour.current
    val passage = store.passage(passageID) ?: return
    LaunchedEffect(passageID) { store.markPracticed(passageID) }
    val voice = remember { VoiceRecitationController(context.applicationContext) }
    val highlights = remember { Highlights() }
    val hint = remember { SessionHint() }
    val scroll = rememberScrollState()
    var focused by remember { mutableStateOf(false) }
    var chromeCleared by remember { mutableStateOf(false) }
    var armedParagraph by remember { mutableStateOf<Int?>(null) }
    var startWord by remember { mutableIntStateOf(0) }
    var celebration by remember { mutableIntStateOf(0) }
    var headerHeight by remember { mutableFloatStateOf(0f) }
    var controlsHeight by remember { mutableFloatStateOf(0f) }
    var viewportHeight by remember { mutableFloatStateOf(0f) }
    var menuOpen by remember { mutableStateOf(false) }
    var optionsOpen by remember { mutableStateOf(false) }
    var micAlert by remember { mutableStateOf(false) }
    var painting by remember { mutableStateOf(false) }
    var paintTarget by remember { mutableStateOf<Boolean?>(null) }
    var cascading by remember { mutableStateOf(false) }
    var cascadeJob by remember { mutableStateOf<Job?>(null) }
    var pendingStart by remember { mutableStateOf<(() -> Unit)?>(null) }

    val fontScale = LocalFontScale.current
    val measurer = rememberTextMeasurer(cacheSize = 512)
    val pageStyle = Typography.recite.style(fontScale)
    val current by rememberUpdatedState(passage)

    CompletesTourStep(TourStep.OpenPassage)
    ClearsTourButton(with(density) { controlsHeight.toDp() } + Spacing.xs)

    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        val start = pendingStart
        pendingStart = null
        if (granted) start?.invoke() else voice.denyMicrophone()
    }

    LaunchedEffect(Unit) {
        voice.onWordsMatched = { indices ->
            highlights.recite(indices)
            tour?.complete(TourStep.Recite)
        }
        voice.onMiss = { index ->
            highlights.flashing = index
            highlights.shakes += 1
            Feedback.recitationMiss()
            tour?.complete(TourStep.Recite)
            scope.launch {
                delay(600)
                if (highlights.flashing == index) highlights.flashing = null
            }
        }
        voice.onWordShown = { index ->
            if (index in current.hiddenWords) store.toggleWord(current, index)
        }
        voice.onCompleted = {
            Feedback.sessionComplete()
            highlights.clear()
            if (startWord == 0 && store.passage(passageID)?.isMemorized == true) {
                celebration += 1
                val shown = celebration
                scope.launch {
                    delay(Motion.CELEBRATION_DWELL)
                    if (celebration == shown) celebration = 0
                }
                if (ReviewPrompt.shouldAsk(store.memorizedPassageIDs.size, store.settings)) {
                    scope.launch {
                        delay(ReviewPrompt.DELAY_AFTER_CELEBRATION)
                        store.markReviewRequested()
                        (context as? Activity)?.let { ReviewPrompt.request(it) }
                    }
                }
            }
        }
        voice.prepare()
    }

    LaunchedEffect(passage.hiddenWords) {
        voice.updateHiddenIndices(highlights.unattempted(passage, startWord))
    }

    LaunchedEffect(voice.state) {
        if (focused && voice.state != VoiceRecitationController.State.PreparingModel && voice.state != VoiceRecitationController.State.Listening) {
            focused = false
        }
    }

    LaunchedEffect(focused) {
        tour?.isPaused = focused
        chromeCleared = false
        if (focused) {
            delay(Motion.FOCUS.toLong())
            chromeCleared = focused
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            voice.stop()
            tour?.isPaused = false
        }
    }

    fun cascade(mutate: () -> Unit) {
        cascadeJob?.cancel()
        cascading = true
        mutate()
        cascadeJob = scope.launch {
            delay(120)
            cascading = false
        }
    }

    fun ripple(indices: Set<Int>) {
        if (indices.isEmpty()) return
        val count = passage.words.size
        Feedback.cascadeRipple(indices.map { Motion.cascadeDelay(it, count) + Motion.FADE / 1000.0 })
    }

    fun toggleWord(index: Int) {
        val wasHidden = index in current.hiddenWords
        store.toggleWord(current, index)
        if (wasHidden) Feedback.reveal() else Feedback.hideTick()
        tour?.complete(TourStep.HideWord, onlyIfCurrent = true)
    }

    fun stopRecitation() {
        if (!focused) return
        focused = false
        voice.stop()
    }

    BoxWithConstraints(Modifier.fillMaxSize().background(Theme.bg)) {
        val widthDp = maxWidth.value
        val metrics = remember(widthDp, fontScale, density.density) { ReadingMetrics.of(widthDp, fontScale, density.density) }
        val layoutWidth = constraints.maxWidth - metrics.textMargin * 2
        val layout = remember(passage.text, layoutWidth, metrics, pageStyle, density.fontScale) {
            PageLayout(passage.words, passage.paragraphs, layoutWidth, metrics, measurer, pageStyle)
        }
        val topInset = with(density) { PAGE_TOP_MARGIN.dp.toPx() } + headerHeight
        val statusTop = WindowInsets.statusBars.getTop(density).toFloat()
        val collapse by animateFloatAsState(if (focused) headerHeight - statusTop else 0f, Motion.focus(), label = "collapse")
        val chromeAlpha by animateFloatAsState(if (focused) 0f else 1f, Motion.focus(), label = "chrome")
        val tolerance = layout.lineHeight * 0.6f
        val scrollTop = scroll.value.toFloat()
        val bottomPadding = controlsHeight + with(density) { Spacing.xxl.toPx() }
        val contentHeight = topInset + layout.height + with(density) { TIP_HEIGHT.dp.toPx() } + bottomPadding
        val maxScrollTop = maxOf(contentHeight - viewportHeight, 0f)

        fun focusedParagraph(): Int = armedParagraph ?: layout.paragraphIndex(scroll.value.toFloat(), tolerance) ?: 0

        fun scrollTo(target: Float, duration: Int = Motion.SCROLL) {
            scope.launch { scroll.animateScrollTo(target.coerceIn(0f, maxScrollTop).toInt(), tween(duration, easing = Motion.easeInOut)) }
        }

        fun scrollToParagraph(paragraph: Int) = scrollTo(layout.paragraphs[paragraph].frame.top)

        fun beginRecitation(paragraph: Int) {
            if (paragraph !in layout.paragraphs.indices) return
            val start = layout.paragraphs[paragraph].words.first
            startWord = start
            val remaining = current.recitableIndices(start)
            if (remaining.isEmpty()) return
            highlights.clear()
            focused = true
            scrollToParagraph(paragraph)
            scope.launch { voice.start(current.words, remaining, start) }
        }

        fun onRecite() {
            when (voice.state) {
                VoiceRecitationController.State.Listening -> stopRecitation()
                VoiceRecitationController.State.PreparingModel -> {}
                VoiceRecitationController.State.MicDenied -> micAlert = true
                else -> {
                    val paragraph = focusedParagraph()
                    val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
                    if (granted) beginRecitation(paragraph)
                    else {
                        pendingStart = { beginRecitation(paragraph) }
                        permission.launch(Manifest.permission.RECORD_AUDIO)
                    }
                }
            }
        }

        fun paint(at: Offset) {
            val index = layout.wordIndex(Offset(at.x - metrics.textMargin, at.y - topInset)) ?: return
            val hidden = index in current.hiddenWords
            val target = paintTarget ?: !hidden
            paintTarget = target
            if (hidden != target) toggleWord(index)
        }

        fun tapWhileReciting(at: Offset) {
            val index = layout.wordIndex(Offset(at.x - metrics.textMargin, at.y + scroll.value + collapse - topInset))
            if (index == null) {
                Feedback.tap()
                stopRecitation()
                return
            }
            ConformerRecitation.trace("tapped $index")
            when {
                index in highlights.recited -> {
                    Feedback.hideTick()
                    highlights.putAside(index)
                }
                index in current.hiddenWords -> {
                    if (voice.reveal(index)) Feedback.reveal() else toggleWord(index)
                }
                else -> {
                    if (voice.hasPassed(index)) highlights.putAside(index)
                    toggleWord(index)
                }
            }
        }

        val cursorIndex = if (voice.isListening && chromeCleared) voice.cursorIndex else null
        LaunchedEffect(cursorIndex) {
            val index = cursorIndex ?: return@LaunchedEffect
            if (index !in layout.wordFrames.indices) return@LaunchedEffect
            val frame = layout.wordFrames[index].rect
            val onScreen = topInset - collapse + frame.top - scroll.value
            val comfortable = onScreen >= 0 && onScreen + frame.height <= viewportHeight * FOLLOW_THRESHOLD
            if (comfortable) return@LaunchedEffect
            scrollTo(maxOf(topInset - collapse + frame.top - frame.height, 0f), 350)
        }

        val decay = rememberSplineBasedDecay<Float>()
        val tops = layout.paragraphs.map { it.frame.top }
        val fling = remember(tops, viewportHeight, maxScrollTop, focused) {
            ParagraphSnap(scroll, decay, tops.filter { it <= maxScrollTop + 1 }, viewportHeight * SNAP_REACH, active = !focused)
        }

        LaunchedEffect(scroll) {
            scroll.interactionSource.interactions.collect {
                if (it is DragInteraction.Start && !painting) armedParagraph = null
            }
        }

        Box(
            Modifier
                .fillMaxSize()
                .onSizeChanged { viewportHeight = it.height.toFloat() }
                .verticalScroll(scroll, enabled = !painting, flingBehavior = fling)
        ) {
            val drawnTop = scrollTop - viewportHeight - topInset
            val drawnBottom = scrollTop + viewportHeight * 2.5f - topInset
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(with(density) { contentHeight.toDp() })
                    .graphicsLayer { translationY = -collapse }
                    .pointerInput(layout, topInset, focused) {
                        if (focused) return@pointerInput
                        detectTapGestures { offset ->
                            if (painting) return@detectTapGestures
                            menuOpen = false
                            layout.wordIndex(Offset(offset.x - metrics.textMargin, offset.y - topInset))?.let { toggleWord(it) }
                        }
                    }
                    .pointerInput(layout, topInset, focused) {
                        if (focused) return@pointerInput
                        detectDragGesturesAfterLongPress(
                            onDragStart = {
                                painting = true
                                paintTarget = null
                                Feedback.flip()
                                paint(it)
                            },
                            onDragEnd = {
                                paintTarget = null
                                scope.launch { delay(80); painting = false }
                            },
                            onDragCancel = {
                                paintTarget = null
                                painting = false
                            },
                        ) { change, _ ->
                            change.consume()
                            paint(change.position)
                        }
                    }
            ) {
                layout.paragraphs.forEachIndexed { index, paragraph ->
                    if (paragraph.frame.bottom < drawnTop || paragraph.frame.top > drawnBottom) return@forEachIndexed
                    key(index) {
                        PageParagraph(
                            passage = passage,
                            layout = layout,
                            index = index,
                            highlights = highlights,
                            focused = focused,
                            difficulty = store.settings.difficulty,
                            cascading = cascading,
                            modifier = Modifier.offset { IntOffset(metrics.textMargin.toInt(), (topInset + paragraph.frame.top).toInt()) },
                        )
                    }
                }
                val start = if (focused) layout.paragraphIndex(startWord) else armedParagraph ?: layout.paragraphIndex(scrollTop, tolerance)
                layout.paragraphs.forEachIndexed { index, paragraph ->
                    if (paragraph.frame.bottom < drawnTop || paragraph.frame.top > drawnBottom) return@forEachIndexed
                    ParagraphMarker(
                        isStart = index == start,
                        modifier = Modifier
                            .offset {
                                val markerSize = 30.dp.toPx()
                                IntOffset(
                                    ((metrics.textMargin - markerSize) / 2).toInt(),
                                    (topInset + paragraph.frame.top + (layout.lineHeight - markerSize) / 2).toInt(),
                                )
                            }
                            .alpha(chromeAlpha),
                        enabled = !focused,
                    ) {
                        tour?.complete(TourStep.StartAnywhere, onlyIfCurrent = true)
                        armedParagraph = index
                        scrollToParagraph(index)
                    }
                }
                RecitationCursor(
                    target = cursorIndex?.takeIf { it in layout.wordFrames.indices }?.let { layout.wordFrames[it].rect },
                    modifier = Modifier.offset { IntOffset(metrics.textMargin.toInt(), topInset.toInt()) },
                )
                com.faizififita.verses.theme.InfoNote(
                    Typography.micro,
                    color = Theme.faint,
                    text = "Tap and glide over words to show or hide them",
                    modifier = Modifier
                        .offset { IntOffset(metrics.textMargin.toInt(), (topInset + layout.height + 20.dp.toPx()).toInt()) }
                        .alpha(chromeAlpha),
                )
            }
        }

        val fadeHeight = with(density) { (controlsHeight / 2).toDp() } + Spacing.lg
        Box(
            Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .height(fadeHeight)
                .alpha(chromeAlpha)
                .background(Brush.verticalGradient(listOf(Theme.bg.copy(alpha = 0f), Theme.bg)))
        )

        if (menuOpen) {
            Box(Modifier.fillMaxSize().pointerInput(Unit) { detectTapGestures { menuOpen = false } })
        }

        Column(
            Modifier
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .padding(start = Spacing.lg, end = Spacing.lg, bottom = Spacing.xs)
                .onSizeChanged { controlsHeight = it.height.toFloat() }
                .alpha(chromeAlpha)
                .shadow(18.dp, RoundedCornerShape(Radius.panel), clip = false, ambientColor = Theme.shadow.copy(alpha = 0.08f), spotColor = Theme.shadow.copy(alpha = 0.08f))
                .background(Theme.raised, RoundedCornerShape(Radius.panel))
                .border(1.dp, Theme.hairline, RoundedCornerShape(Radius.panel))
                .padding(top = Spacing.xxs, bottom = Spacing.sm),
            verticalArrangement = Arrangement.spacedBy(Spacing.xxs),
        ) {
            RecitationBar(
                voiceState = voice.state,
                canHideWords = passage.hiddenWords.size < passage.wordCount,
                hideCount = store.settings.randomHideCount,
                menuOpen = menuOpen,
                hint = hint,
                onToggleMenu = { menuOpen = it },
                onChooseCount = { count -> store.updateSettings { it.copy(randomHideCount = count) } },
                onHideWords = { count ->
                    if (!focused) {
                        val words = layout.paragraphs[focusedParagraph()].words.toSet()
                        var hidden = emptySet<Int>()
                        cascade { hidden = store.hideRandomWords(current, count, words) }
                        ripple(hidden)
                        if (hidden.isEmpty()) hint.show("Every word in this paragraph is already hidden.")
                        else tour?.complete(TourStep.HideMany, onlyIfCurrent = true)
                    }
                },
                onRecite = ::onRecite,
            )
            val pageHeight = topInset + layout.height
            HeatRail(
                density = remember(layout, passage.hiddenWords) { layout.density(passage.hiddenWords, RAIL_SAMPLES) },
                center = if (pageHeight > 0) (scrollTop + viewportHeight / 2) / pageHeight else 0f,
                onSeek = { fraction, settled ->
                    tour?.complete(TourStep.StartAnywhere, onlyIfCurrent = true)
                    armedParagraph = null
                    var target = (fraction * pageHeight - viewportHeight / 2).coerceIn(0f, maxScrollTop)
                    if (!settled) {
                        scope.launch { scroll.scrollTo(target.toInt()) }
                    } else {
                        tops.filter { it <= maxScrollTop + 1 }.minByOrNull { abs(it - target) }
                            ?.takeIf { abs(it - target) <= viewportHeight * SNAP_REACH }
                            ?.let { target = it }
                        scrollTo(target, 300)
                    }
                },
                modifier = Modifier.padding(horizontal = Spacing.lg),
            )
        }

        Box(
            Modifier
                .align(Alignment.TopCenter)
                .fillMaxWidth()
                .onSizeChanged { headerHeight = it.height.toFloat() }
                .alpha(chromeAlpha)
                .background(Theme.bg)
                .statusBarsPadding()
        ) {
            ScreenHeader(
                title = passage.title,
                onBack = if (focused) null else onBack,
                onTitleTap = if (focused) null else onFullText,
                trailing = {
                    Box {
                        IconButton(Icons.Outlined.MoreHoriz, "Options", enabled = !focused) { optionsOpen = true }
                        OptionsMenu(
                            open = optionsOpen,
                            onDismiss = { optionsOpen = false },
                            onEdit = {
                                optionsOpen = false
                                stopRecitation()
                                highlights.clear()
                                onEdit()
                            },
                            onHideAll = {
                                optionsOpen = false
                                if (passage.hiddenWords.size >= passage.wordCount) hint.show("Every word is already hidden.")
                                else {
                                    val changing = passage.words.indices.toSet() - passage.hiddenWords
                                    ripple(changing)
                                    cascade { store.setAllWords(current, true) }
                                }
                            },
                            onShowAll = {
                                optionsOpen = false
                                if (passage.hiddenWords.isEmpty()) hint.show("Every word is already showing.")
                                else {
                                    ripple(passage.hiddenWords)
                                    cascade { store.setAllWords(current, false) }
                                }
                            },
                            difficulty = store.settings.difficulty,
                            onChooseDifficulty = { difficulty ->
                                optionsOpen = false
                                store.updateSettings { it.copy(difficulty = difficulty) }
                            },
                            onReportIssue = { optionsOpen = false; onReportIssue() },
                            onFeedback = { optionsOpen = false; onFeedback() },
                        )
                    }
                },
            )
        }

        if (focused) {
            Box(
                Modifier
                    .fillMaxSize()
                    .semantics { contentDescription = "Stop reciting" }
                    .pointerInput(layout, topInset, metrics) {
                        detectTapGestures { tapWhileReciting(it) }
                    }
            )
        }

        MemorizedMoment(visible = celebration > 0, title = passage.title) { celebration = 0 }
    }

    if (micAlert) {
        AlertDialog(
            onDismissRequest = { micAlert = false },
            title = { Text("Microphone Access Needed") },
            text = { Text("Allow microphone access in Settings to practice by reciting.") },
            confirmButton = {
                TextButton(onClick = {
                    Feedback.tap()
                    micAlert = false
                    context.startActivity(
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null))
                    )
                }) { Text("Open Settings", color = Theme.accent) }
            },
            dismissButton = {
                TextButton(onClick = { Feedback.tap(); micAlert = false }) { Text("Cancel", color = Theme.muted) }
            },
            containerColor = Theme.raised,
            titleContentColor = Theme.ink,
            textContentColor = Theme.muted,
        )
    }
}

private class ParagraphSnap(
    private val scroll: ScrollState,
    private val decay: DecayAnimationSpec<Float>,
    private val tops: List<Float>,
    private val reach: Float,
    private val active: Boolean,
) : FlingBehavior {
    override suspend fun ScrollScope.performFling(initialVelocity: Float): Float {
        val start = scroll.value.toFloat()
        val natural = decay.calculateTargetValue(start, initialVelocity)
        val nearest = if (active) tops.minByOrNull { abs(it - natural) }?.takeIf { abs(it - natural) <= reach } else null
        if (nearest == null) return decayFling(initialVelocity)
        val target = nearest.coerceIn(0f, scroll.maxValue.toFloat())
        if (abs(target - start) < 0.5f) return 0f
        var previous = start
        animate(start, target, initialVelocity, spring(Spring.DampingRatioNoBouncy, Spring.StiffnessLow)) { value, _ ->
            scrollBy(value - previous)
            previous = value
        }
        return 0f
    }

    private suspend fun ScrollScope.decayFling(initialVelocity: Float): Float {
        if (abs(initialVelocity) < 1f) return initialVelocity
        var left = initialVelocity
        var last = 0f
        AnimationState(0f, initialVelocity).animateDecay(decay) {
            val delta = value - last
            val consumed = scrollBy(delta)
            last = value
            left = velocity
            if (abs(delta - consumed) > 0.5f) cancelAnimation()
        }
        return left
    }
}

@Composable
private fun PageParagraph(
    passage: Passage,
    layout: PageLayout,
    index: Int,
    highlights: Highlights,
    focused: Boolean,
    difficulty: Difficulty,
    cascading: Boolean,
    modifier: Modifier,
) {
    val paragraph = layout.paragraphs[index]
    val density = LocalDensity.current
    Box(modifier.size(with(density) { paragraph.frame.width.toDp() }, with(density) { paragraph.frame.height.toDp() })) {
        for (word in paragraph.words) {
            val hidden = word in passage.hiddenWords
            val recited = word in highlights.recited
            key(word) {
                Word(
                    token = passage.words[word],
                    frame = layout.wordFrames[word],
                    top = paragraph.frame.top,
                    style = layout.style,
                    concealed = focused && hidden && !recited,
                    difficulty = difficulty,
                    dimmed = !focused && hidden,
                    recited = recited,
                    sweeping = focused && hidden && recited,
                    sweepDelayMillis = (highlights.batchPlace[word] ?: 0) * Motion.SWEEP_STAGGER,
                    flashing = highlights.flashing == word,
                    shakes = if (highlights.flashing == word) highlights.shakes else 0,
                    staggerMillis = if (cascading) (Motion.cascadeDelay(word, passage.words.size) * 1000).toInt() else 0,
                )
            }
        }
    }
}

private const val SWEEP_SOFTNESS = 0.6f

@Composable
private fun Word(
    token: String,
    frame: WordFrame,
    top: Float,
    style: androidx.compose.ui.text.TextStyle,
    concealed: Boolean,
    difficulty: Difficulty,
    dimmed: Boolean,
    recited: Boolean,
    sweeping: Boolean,
    sweepDelayMillis: Int,
    flashing: Boolean,
    shakes: Int,
    staggerMillis: Int,
) {
    val parts = remember(token) { WordParts.of(token) }
    val coreAlpha by animateFloatAsState(
        if (concealed) 0f else 1f,
        if (recited && !concealed) Motion.reveal() else Motion.fade(staggerMillis),
        label = "core",
    )
    val lineAlpha by animateFloatAsState(
        if (concealed) 1f else 0f,
        if (concealed) tween(Motion.FADE, Motion.LINE_FADE_DELAY + staggerMillis, Motion.easeInOut)
        else if (recited) Motion.reveal() else tween(180, easing = Motion.easeInOut),
        label = "line",
    )
    val coreColor by animateColorAsState(if (dimmed) Theme.hiddenInk else Theme.ink, Motion.fade(staggerMillis), label = "dim")
    val sweep by animateFloatAsState(if (sweeping) 1f else 0f, if (sweeping) Motion.sweep(sweepDelayMillis) else snap(), label = "sweep")
    val shake = remember { Animatable(0f) }
    LaunchedEffect(shakes) {
        if (shakes == 0) return@LaunchedEffect
        shake.snapTo(0f)
        shake.animateTo(1f, tween(300, easing = LinearEasing))
    }
    val ink = Theme.ink
    val lineColor = when {
        flashing -> Theme.warn
        recited -> Theme.accent
        else -> Theme.faint
    }
    val highlight by animateColorAsState(if (flashing) Theme.warn.copy(alpha = 0.2f) else Color.Transparent, tween(300), label = "flash")
    val punctuation = if (difficulty == Difficulty.Blank) ink.copy(alpha = ink.alpha * coreAlpha) else ink
    val text = remember(parts, coreColor, coreAlpha, punctuation) {
        buildAnnotatedString {
            withStyle(SpanStyle(color = if (parts.lead == "-") ink else punctuation)) { append(parts.lead) }
            withStyle(SpanStyle(color = coreColor.copy(alpha = coreColor.alpha * coreAlpha))) { append(parts.core) }
            withStyle(SpanStyle(color = punctuation)) { append(parts.trail) }
        }
    }
    val density = LocalDensity.current
    Text(
        text,
        style = style,
        softWrap = false,
        maxLines = 1,
        modifier = Modifier
            .offset { IntOffset(frame.rect.left.toInt(), (frame.rect.top - top).toInt()) }
            .graphicsLayer {
                translationX = with(density) { 4.dp.toPx() } * sin(shake.value * PI.toFloat() * 3)
                compositingStrategy = if (sweeping) CompositingStrategy.Offscreen else CompositingStrategy.Auto
            }
            .drawWithContent {
                drawContent()
                if (sweeping) {
                    val edge = sweep * (1 + SWEEP_SOFTNESS) - SWEEP_SOFTNESS
                    drawRect(
                        Brush.horizontalGradient(
                            listOf(Color.Black, Color.Transparent),
                            startX = edge * size.width,
                            endX = (edge + SWEEP_SOFTNESS) * size.width,
                        ),
                        blendMode = BlendMode.DstIn,
                    )
                }
            }
            .drawBehind {
                if (highlight.alpha > 0f) {
                    drawRoundRect(
                        highlight,
                        Offset(-5.dp.toPx(), -3.dp.toPx()),
                        Size(size.width + 10.dp.toPx(), size.height + 6.dp.toPx()),
                        CornerRadius(Radius.word.toPx()),
                    )
                }
                if (lineAlpha > 0f && frame.coreWidth > 0f && difficulty == Difficulty.Lines) {
                    val y = size.height - size.height * 0.2f
                    drawRect(
                        lineColor.copy(alpha = lineAlpha),
                        Offset(frame.coreStart, y),
                        Size(frame.coreWidth, 1.dp.toPx()),
                    )
                }
            },
    )
}

@Composable
private fun ParagraphMarker(isStart: Boolean, modifier: Modifier, enabled: Boolean, onTap: () -> Unit) {
    val color by animateColorAsState(if (isStart) Theme.accent else Theme.faint.copy(alpha = 0.45f), tween(200), label = "marker")
    Box(
        modifier
            .size(30.dp)
            .semantics { contentDescription = "Start here" }
            .pointerInput(enabled) {
                if (!enabled) return@pointerInput
                detectTapGestures {
                    Feedback.tap()
                    onTap()
                }
            },
        contentAlignment = Alignment.Center,
    ) {
        Text("¶", style = Typography.callout.style(LocalFontScale.current), color = color)
    }
}

@Composable
private fun RecitationCursor(target: androidx.compose.ui.geometry.Rect?, modifier: Modifier) {
    val density = LocalDensity.current
    val fontScale = LocalFontScale.current
    val context = LocalContext.current
    val reduceMotion = remember {
        Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    }
    val x = remember { Animatable(0f) }
    val top = remember { Animatable(0f) }
    val height = remember { Animatable(0f) }
    val visible = remember { Animatable(0f) }
    val pulse = remember { Animatable(1f) }
    LaunchedEffect(target) {
        if (target == null) {
            visible.animateTo(0f, tween(220, easing = Motion.easeOut))
            return@LaunchedEffect
        }
        val unit = with(density) { 1.dp.toPx() } * fontScale
        val width = with(density) { CARET_WIDTH.toPx() }
        val above = 6 * unit
        val below = 2 * unit
        val caretX = target.left - 3 * unit - width / 2
        val caretTop = target.top + above
        val caretHeight = target.height - above - below
        launch {
            pulse.snapTo(1f)
            if (reduceMotion) return@launch
            delay(Motion.CARET_HOLD.toLong())
            while (true) {
                pulse.animateTo(0f, tween(Motion.CARET_PULSE, easing = Motion.easeInOut))
                pulse.animateTo(1f, tween(Motion.CARET_PULSE, easing = Motion.easeInOut))
            }
        }
        if (visible.value < 0.01f || abs(caretTop - top.value) >= 1f) {
            x.snapTo(caretX); top.snapTo(caretTop); height.snapTo(caretHeight)
            if (visible.value < 1f) visible.animateTo(1f, tween(200, easing = Motion.easeOut))
            return@LaunchedEffect
        }
        val glide = spring<Float>(0.88f, 1200f)
        launch { x.animateTo(caretX, glide) }
        launch { height.animateTo(caretHeight, glide) }
    }
    val accent = Theme.accent
    Canvas(modifier.size(1.dp)) {
        val alpha = visible.value * pulse.value
        if (alpha <= 0f) return@Canvas
        val width = CARET_WIDTH.toPx()
        val radius = 1.dp.toPx()
        val left = x.value
        val right = x.value + width
        val bottom = top.value + height.value
        drawIntoCanvas { canvas ->
            for ((blur, strength) in listOf(10.dp.toPx() to 0.35f, 4.dp.toPx() to 0.85f)) {
                val glow = android.graphics.Paint().apply {
                    isAntiAlias = true
                    color = accent.copy(alpha = strength * alpha).toArgb()
                    maskFilter = android.graphics.BlurMaskFilter(blur, android.graphics.BlurMaskFilter.Blur.NORMAL)
                }
                canvas.nativeCanvas.drawRoundRect(left, top.value, right, bottom, radius, radius, glow)
            }
        }
        drawRoundRect(accent.copy(alpha = alpha), Offset(left, top.value), Size(width, height.value), CornerRadius(radius))
    }
}

private val CARET_WIDTH = 2.5.dp

@Composable
private fun OptionsMenu(
    open: Boolean,
    onDismiss: () -> Unit,
    onEdit: () -> Unit,
    onHideAll: () -> Unit,
    onShowAll: () -> Unit,
    difficulty: Difficulty,
    onChooseDifficulty: (Difficulty) -> Unit,
    onReportIssue: () -> Unit,
    onFeedback: () -> Unit,
) {
    DropdownMenu(
        expanded = open,
        onDismissRequest = onDismiss,
        containerColor = Theme.raised,
        shape = RoundedCornerShape(Radius.group),
    ) {
        MenuItem("Edit Passage", Icons.Outlined.Edit, onEdit)
        HorizontalDivider(color = Theme.hairline)
        MenuItem("Hide Every Word", Icons.Outlined.VisibilityOff, onHideAll)
        MenuItem("Show Every Word", Icons.Outlined.Visibility, onShowAll)
        HorizontalDivider(color = Theme.hairline)
        Text(
            "Difficulty",
            style = Typography.footnote.style(LocalFontScale.current),
            color = Theme.faint,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
        )
        for (option in Difficulty.entries) {
            MenuItem(option.label, if (option == difficulty) Icons.Outlined.Check else null) { onChooseDifficulty(option) }
        }
        HorizontalDivider(color = Theme.hairline)
        MenuItem("Report Issue", Icons.Outlined.ErrorOutline, onReportIssue)
        MenuItem("Send Feedback", Icons.AutoMirrored.Outlined.Send, onFeedback)
    }
}

@Composable
private fun MenuItem(title: String, icon: androidx.compose.ui.graphics.vector.ImageVector?, onClick: () -> Unit) {
    DropdownMenuItem(
        text = { Text(title, style = Typography.body.style(LocalFontScale.current), color = Theme.ink) },
        trailingIcon = { if (icon != null) Icon(icon, null, tint = Theme.muted, modifier = Modifier.size(18.dp)) },
        onClick = {
            Feedback.tap()
            onClick()
        },
    )
}
