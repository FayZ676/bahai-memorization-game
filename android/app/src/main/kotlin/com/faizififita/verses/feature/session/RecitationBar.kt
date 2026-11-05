package com.faizififita.verses.feature.session

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.GraphicEq
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.MicOff
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.faizififita.verses.support.Feedback
import com.faizififita.verses.theme.Motion
import com.faizififita.verses.theme.Spacing
import com.faizififita.verses.theme.Theme
import com.faizififita.verses.theme.Typography
import com.faizififita.verses.theme.haptic
import com.faizififita.verses.theme.LocalFontScale
import com.faizififita.verses.theme.Radius
import kotlinx.coroutines.delay

class SessionHint {
    var message by mutableStateOf<String?>(null)
        private set
    var standing by mutableStateOf("")
        private set
    private var token by mutableStateOf(0)

    fun show(text: String) {
        token += 1
        message = text
        standing = text
    }

    fun dismiss() {
        token += 1
        message = null
    }

    @Composable
    fun AutoDismiss() {
        LaunchedEffect(token) {
            if (message == null) return@LaunchedEffect
            delay(2400)
            message = null
        }
    }
}

private val HIDE_COUNTS = listOf(2, 4, 6, 8, 10)
private val BUTTON_HEIGHT = 46.dp
private val OPTION_DIAMETER = 44.dp

@Composable
fun RecitationBar(
    voiceState: VoiceRecitationController.State,
    canHideWords: Boolean,
    hideCount: Int,
    menuOpen: Boolean,
    hint: SessionHint,
    onToggleMenu: (Boolean) -> Unit,
    onChooseCount: (Int) -> Unit,
    onHideWords: (Int) -> Unit,
    onRecite: () -> Unit,
) {
    hint.AutoDismiss()
    val labelStyle = Typography.body.weight(FontWeight.Medium).style(LocalFontScale.current)
    Box(Modifier.fillMaxWidth().padding(start = Spacing.lg, end = Spacing.lg, top = Spacing.md, bottom = Spacing.sm)) {
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Box(Modifier.weight(1f)) {
                val tint by animateColorAsState(
                    when {
                        menuOpen -> Theme.accent
                        canHideWords -> Theme.muted
                        else -> Theme.disabled
                    },
                    Motion.settle(), label = "hideTint",
                )
                Row(
                    Modifier
                        .fillMaxWidth()
                        .height(BUTTON_HEIGHT)
                        .clip(RoundedCornerShape(50))
                        .background(if (menuOpen) Theme.accent.copy(alpha = 0.1f) else Color.Transparent)
                        .semantics { contentDescription = "Hide words, $hideCount at a time" }
                        .pointerInput(menuOpen, canHideWords, hideCount) {
                            detectTapGestures(
                                onLongPress = {
                                    Feedback.hide()
                                    hint.dismiss()
                                    onToggleMenu(true)
                                },
                                onTap = {
                                    Feedback.tap()
                                    when {
                                        menuOpen -> onToggleMenu(false)
                                        !canHideWords -> hint.show("Every word is already hidden.")
                                        else -> onHideWords(hideCount)
                                    }
                                },
                            )
                        },
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Outlined.VisibilityOff, null, tint = tint, modifier = Modifier.size(17.dp))
                    Box(Modifier.width(Spacing.sm))
                    AnimatedContent(hideCount, transitionSpec = { fadeIn(Motion.settle()) togetherWith fadeOut(Motion.settle()) }, label = "count") {
                        Text("Hide $it", style = labelStyle, color = tint)
                    }
                }
                CountPopUp(open = menuOpen, selected = hideCount) {
                    onChooseCount(it)
                    onToggleMenu(false)
                }
            }
            ReciteButton(voiceState, labelStyle, Modifier.weight(1f)) {
                Feedback.tap()
                if (menuOpen) onToggleMenu(false) else onRecite()
            }
        }
        HintBubble(hint)
    }
}

@Composable
private fun HintBubble(hint: SessionHint) {
    var height by remember { mutableFloatStateOf(0f) }
    val visible = hint.message != null
    val alpha by animateFloatAsState(if (visible) 1f else 0f, Motion.settle(), label = "hint")
    val scale by animateFloatAsState(if (visible) 1f else 0.94f, Motion.settle(), label = "hintScale")
    Box(
        Modifier
            .fillMaxWidth()
            .wrapContentSize(Alignment.TopCenter)
            .offset { IntOffset(0, -height.toInt()) }
            .onSizeChanged { height = it.height.toFloat() }
            .alpha(alpha)
            .then(Modifier.padding(0.dp))
    ) {
        Row(
            Modifier
                .width(264.dp)
                .shadow(10.dp * alpha, RoundedCornerShape(Radius.control), ambientColor = Theme.shadow.copy(alpha = 0.08f))
                .clip(RoundedCornerShape(Radius.control))
                .background(Theme.rowBg)
                .border(1.dp, Theme.hairline, RoundedCornerShape(Radius.control))
                .padding(horizontal = 14.dp, vertical = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
        ) {
            Icon(Icons.Outlined.Info, null, tint = Theme.muted, modifier = Modifier.padding(top = 2.dp).size(13.dp * scale))
            Text(hint.standing, style = Typography.caption.style(LocalFontScale.current), color = Theme.muted)
        }
    }
}

@Composable
private fun CountPopUp(open: Boolean, selected: Int, onChoose: (Int) -> Unit) {
    var height by remember { mutableFloatStateOf(0f) }
    AnimatedVisibility(
        visible = open,
        enter = fadeIn(tween(200)) + scaleIn(tween(260), initialScale = 0.8f, transformOrigin = androidx.compose.ui.graphics.TransformOrigin(0.5f, 1f)),
        exit = fadeOut(tween(160)) + scaleOut(tween(200), targetScale = 0.8f, transformOrigin = androidx.compose.ui.graphics.TransformOrigin(0.5f, 1f)),
        modifier = Modifier
            .fillMaxWidth()
            .wrapContentSize(Alignment.TopCenter)
            .offset { IntOffset(0, -height.toInt() - 8.dp.roundToPx()) }
            .onSizeChanged { height = it.height.toFloat() },
    ) {
        Column(
            Modifier
                .shadow(12.dp, RoundedCornerShape(50), ambientColor = Theme.shadow.copy(alpha = 0.09f))
                .clip(RoundedCornerShape(50))
                .background(Theme.surface)
                .border(1.dp, Theme.hairline, RoundedCornerShape(50))
                .padding(Spacing.xxs),
            verticalArrangement = Arrangement.spacedBy(Spacing.xxs),
        ) {
            for (count in HIDE_COUNTS.reversed()) {
                val isSelected = count == selected
                Box(
                    Modifier
                        .size(OPTION_DIAMETER)
                        .clip(CircleShape)
                        .background(if (isSelected) Theme.accent.copy(alpha = 0.18f) else Color.Transparent)
                        .haptic { onChoose(count) },
                    contentAlignment = Alignment.Center,
                ) {
                    Text("$count", style = Typography.button.style(LocalFontScale.current), color = if (isSelected) Theme.accent else Theme.navIcon)
                }
            }
        }
    }
}

@Composable
private fun ReciteButton(state: VoiceRecitationController.State, labelStyle: androidx.compose.ui.text.TextStyle, modifier: Modifier, onTap: () -> Unit) {
    val unavailable = state == VoiceRecitationController.State.MicDenied
    val active = state == VoiceRecitationController.State.Listening
    val tint = if (unavailable) Theme.disabled else Theme.accent
    Row(
        modifier
            .height(BUTTON_HEIGHT)
            .clip(RoundedCornerShape(50))
            .background(if (unavailable) Theme.bg else Theme.accent.copy(alpha = 0.1f))
            .semantics { contentDescription = "Recite aloud. Tap away from the words to stop." }
            .pointerInput(Unit) { detectTapGestures(onTap = { onTap() }) },
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        when {
            state == VoiceRecitationController.State.PreparingModel ->
                CircularProgressIndicator(color = Theme.accent, strokeWidth = 2.dp, modifier = Modifier.size(15.dp))
            active -> {
                val pulse by rememberInfiniteTransition(label = "wave").animateFloat(
                    0.45f, 1f, infiniteRepeatable(tween(600), RepeatMode.Reverse), label = "wavePulse",
                )
                Icon(Icons.Outlined.GraphicEq, null, tint = tint, modifier = Modifier.size(17.dp).alpha(pulse))
            }
            else -> Icon(if (unavailable) Icons.Outlined.MicOff else Icons.Outlined.Mic, null, tint = tint, modifier = Modifier.size(17.dp))
        }
        Box(Modifier.width(Spacing.sm))
        Text(if (active) "Listening" else "Recite", style = labelStyle, color = tint)
    }
}

@Composable
fun HeatRail(
    density: List<Double>,
    center: Float,
    onSeek: (Float, Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    var width by remember { mutableFloatStateOf(0f) }
    var dragging by remember { mutableStateOf(false) }
    val accent = Theme.accent
    val track = Theme.ink.copy(alpha = 0.08f)
    val raised = Theme.raised
    Canvas(
        modifier
            .fillMaxWidth()
            .height(28.dp)
            .onSizeChanged { width = it.width.toFloat() }
            .semantics { contentDescription = "Progress through the prayer. Drag to move through it." }
            .pointerInput(Unit) {
                detectTapGestures { offset ->
                    Feedback.scrub()
                    if (width > 0) onSeek((offset.x / width).coerceIn(0f, 1f), true)
                }
            }
            .pointerInput(Unit) {
                detectDragGestures(
                    onDragStart = {
                        dragging = true
                        Feedback.scrub()
                        if (width > 0) onSeek((it.x / width).coerceIn(0f, 1f), false)
                    },
                    onDragEnd = { dragging = false },
                    onDragCancel = { dragging = false },
                ) { change, _ ->
                    if (width > 0) onSeek((change.position.x / width).coerceIn(0f, 1f), !dragging)
                    if (change.changedToUp()) onSeek((change.position.x / width).coerceIn(0f, 1f), true)
                }
            },
    ) {
        val trackHeight = 6.dp.toPx()
        val top = (size.height - trackHeight) / 2
        val radius = CornerRadius(trackHeight / 2)
        drawRoundRect(track, Offset(0f, top), Size(size.width, trackHeight), radius)
        if (density.size > 1) {
            val stops = density.mapIndexed { index, value ->
                index.toFloat() / (density.size - 1) to accent.copy(alpha = PageLayout.heatOpacity(value))
            }.toTypedArray()
            drawRoundRect(Brush.horizontalGradient(*stops), Offset(0f, top), Size(size.width, trackHeight), radius)
        }
        val diameter = 14.dp.toPx()
        val x = (size.width - diameter) * center.coerceIn(0f, 1f) + diameter / 2
        drawCircle(raised, diameter / 2, Offset(x, size.height / 2))
        drawCircle(accent, diameter / 2 - 1.dp.toPx(), Offset(x, size.height / 2), style = Stroke(if (dragging) 2.dp.toPx() else 1.5.dp.toPx()))
    }
}

private fun androidx.compose.ui.input.pointer.PointerInputChange.changedToUp() = !pressed && previousPressed
