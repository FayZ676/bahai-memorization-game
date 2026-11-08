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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
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
    var flashing by mutableStateOf<Int?>(null)
    var shakes by mutableIntStateOf(0)
    private var setAside = emptySet<Int>()

    fun clear() {
        recited = emptySet()
        setAside = emptySet()
    }

    fun putAside(index: Int) {
        recited = recited - index
        setAside = setAside + index
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
            highlights.recited = highlights.recited + indices
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
                    dimmed = !focused && hidden,
                    recited = recited,
                    flashing = highlights.flashing == word,
                    shakes = if (highlights.flashing == word) highlights.shakes else 0,
                    staggerMillis = if (cascading) (Motion.cascadeDelay(word, passage.words.size) * 1000).toInt() else 0,
                )
            }
        }
    }
}

@Composable
private fun Word(
    token: String,
    frame: WordFrame,
    top: Float,
    style: androidx.compose.ui.text.TextStyle,
    concealed: Boolean,
    dimmed: Boolean,
    recited: Boolean,
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
    val pulse = remember { Animatable(1f) }
    LaunchedEffect(recited) {
        if (!recited) return@LaunchedEffect
        pulse.animateTo(1.07f, tween(120, easing = Motion.easeOut))
        pulse.animateTo(1f, spring(0.7f, 300f))
    }
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
    val text = remember(parts, coreColor, coreAlpha, ink) {
        buildAnnotatedString {
            withStyle(SpanStyle(color = ink)) { append(parts.lead) }
            withStyle(SpanStyle(color = coreColor.copy(alpha = coreColor.alpha * coreAlpha))) { append(parts.core) }
            withStyle(SpanStyle(color = ink)) { append(parts.trail) }
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
                scaleX = pulse.value
                scaleY = pulse.value
                translationX = with(density) { 4.dp.toPx() } * sin(shake.value * PI.toFloat() * 3)
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
                if (lineAlpha > 0f && frame.coreWidth > 0f) {
                    val y = size.height - size.height * 0.2f
                    drawRect(
                        Brush.horizontalGradient(
                            0f to lineColor.copy(alpha = 0.5f * lineAlpha),
                            0.14f to lineColor.copy(alpha = lineAlpha),
                            0.86f to lineColor.copy(alpha = lineAlpha),
                            1f to lineColor.copy(alpha = 0.5f * lineAlpha),
                            startX = frame.coreStart,
                            endX = frame.coreStart + frame.coreWidth,
                        ),
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
    val leading = remember { Animatable(0f) }
    val trailing = remember { Animatable(0f) }
    val top = remember { Animatable(0f) }
    val height = remember { Animatable(0f) }
    val visible = remember { Animatable(0f) }
    LaunchedEffect(target) {
        if (target == null) {
            visible.animateTo(0f, tween(220, easing = Motion.easeOut))
            return@LaunchedEffect
        }
        val side = with(density) { 4.dp.toPx() } * fontScale
        val above = with(density) { 6.dp.toPx() } * fontScale
        val below = with(density) { 2.dp.toPx() } * fontScale
        val boxLeft = target.left - side
        val boxRight = target.right + side
        val boxTop = target.top + above
        val boxHeight = target.height - above - below
        if (visible.value < 0.01f) {
            leading.snapTo(boxLeft); trailing.snapTo(boxRight); top.snapTo(boxTop); height.snapTo(boxHeight)
            visible.animateTo(1f, tween(200, easing = Motion.easeOut))
            return@LaunchedEffect
        }
        val fast = spring<Float>(0.86f, 1750f)
        val slow = spring<Float>(0.9f, 815f)
        val lineBreak = spring<Float>(0.86f, 685f)
        if (abs(boxTop - top.value) >= 1f) {
            launch { leading.animateTo(boxLeft, lineBreak) }
            launch { trailing.animateTo(boxRight, lineBreak) }
            launch { top.animateTo(boxTop, lineBreak) }
            launch { height.animateTo(boxHeight, lineBreak) }
            return@LaunchedEffect
        }
        val forward = boxLeft >= leading.value
        launch { leading.animateTo(boxLeft, if (forward) fast else slow) }
        launch { trailing.animateTo(boxRight, if (forward) slow else fast) }
        launch { height.animateTo(boxHeight, fast) }
    }
    val accent = Theme.accent
    Canvas(modifier.size(1.dp)) {
        if (visible.value <= 0f) return@Canvas
        val width = maxOf(trailing.value - leading.value, 4.dp.toPx())
        val radius = CornerRadius(Radius.word.toPx())
        drawRoundRect(accent.copy(alpha = 0.12f * visible.value), Offset(leading.value, top.value), Size(width, height.value), radius)
        drawRoundRect(accent.copy(alpha = visible.value), Offset(leading.value, top.value), Size(width, height.value), radius, style = Stroke(1.5.dp.toPx()))
    }
}

@Composable
private fun OptionsMenu(
    open: Boolean,
    onDismiss: () -> Unit,
    onEdit: () -> Unit,
    onHideAll: () -> Unit,
    onShowAll: () -> Unit,
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
        MenuItem("Report Issue", Icons.Outlined.ErrorOutline, onReportIssue)
        MenuItem("Send Feedback", Icons.AutoMirrored.Outlined.Send, onFeedback)
    }
}

@Composable
private fun MenuItem(title: String, icon: androidx.compose.ui.graphics.vector.ImageVector, onClick: () -> Unit) {
    DropdownMenuItem(
        text = { Text(title, style = Typography.body.style(LocalFontScale.current), color = Theme.ink) },
        trailingIcon = { Icon(icon, null, tint = Theme.muted, modifier = Modifier.size(18.dp)) },
        onClick = {
            Feedback.tap()
            onClick()
        },
    )
}
