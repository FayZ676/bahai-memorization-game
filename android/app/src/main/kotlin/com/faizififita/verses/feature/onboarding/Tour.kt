package com.faizififita.verses.feature.onboarding

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.InlineTextContent
import androidx.compose.foundation.text.appendInlineContent
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBackIos
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material.icons.outlined.ChevronLeft
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.EmojiEvents
import androidx.compose.material.icons.outlined.Mail
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.QuestionMark
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.Placeholder
import androidx.compose.ui.text.PlaceholderVerticalAlign
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import com.faizififita.verses.support.Feedback
import com.faizififita.verses.theme.InfoNote
import com.faizififita.verses.theme.LocalFontScale
import com.faizififita.verses.theme.PrimaryButton
import com.faizififita.verses.theme.Spacing
import com.faizififita.verses.theme.Theme
import com.faizififita.verses.theme.Typography
import com.faizififita.verses.theme.animatedAlpha
import com.faizififita.verses.theme.card
import com.faizififita.verses.theme.haptic
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private sealed interface Piece {
    data class Words(val text: String, val bold: Boolean = false) : Piece
    data class Symbol(val icon: ImageVector) : Piece
}

private fun w(text: String) = Piece.Words(text)
private fun b(text: String) = Piece.Words(text, bold = true)
private fun s(icon: ImageVector) = Piece.Symbol(icon)

data class TourNote(val icon: ImageVector, val text: String)

enum class TourStep(val title: String, private val pieces: List<Piece>) {
    OpenBrowse("Browsing Prayers", listOf(w("Tap the "), s(Icons.AutoMirrored.Outlined.MenuBook), w(" button to browse Prayers and Writings."))),
    PickPrayer("Choosing a Passage", listOf(w("Choose any one of "), b("The Hidden Words"), w(". They are short, and a good place to begin."))),
    AddPrayer("Memorizing a Prayer", listOf(w("Tap the "), s(Icons.Outlined.VisibilityOff), w(" button to add the prayer to your Memorization Library."))),
    OpenPassage("Open a Memorization", listOf(w("Tap the prayer to start memorizing it."))),
    HideMany("Hiding Words (Option 1)", listOf(w("Tap the "), s(Icons.Outlined.VisibilityOff), w(" button to hide a handful of words in the paragraph marked with ¶. Press and hold the button to choose how many words it should hide."))),
    HideWord("Hiding Words (Option 2)", listOf(w("You can also tap a word directly to hide it. Hidden words look faded, and disappear while you recite. Tap one again to bring it back. Press, hold, and glide over multiple words to hide or reveal them at once."))),
    Recite("Reciting Words", listOf(w("Tap the "), s(Icons.Outlined.Mic), w(" Recite button and say the prayer out loud. Everything else fades away while you recite. Tap the page when you want to stop."))),
    StartAnywhere("Starting Anywhere", listOf(w("Practice starts at the paragraph at the top of the screen. Scroll to any paragraph, or tap the ¶ beside it, to start there. The bar under the buttons is the whole prayer, brighter where more words are hidden. Tap or drag it to jump."))),
    Achievements("Earning Achievements", listOf(w("Certain prayers earn an achievement once every word is hidden. Tap the "), s(Icons.AutoMirrored.Outlined.ArrowBackIos), w(" button to return to your Library, then tap the "), s(Icons.Outlined.EmojiEvents), w(" button to see them all."))),
    Finished("That's it", listOf(w("You're ready to start memorizing.")));

    val notes: List<TourNote>
        get() = if (this == Finished) listOf(
            TourNote(Icons.Outlined.Settings, "Open Settings and tap Show welcome tour to see these instructions again."),
            TourNote(Icons.Outlined.Mail, "Open Settings and tap Send feedback to share an idea or report a problem."),
        ) else emptyList()

    fun body(): Pair<AnnotatedString, Map<String, InlineTextContent>> {
        val inline = mutableMapOf<String, InlineTextContent>()
        val text = buildAnnotatedString {
            pieces.forEachIndexed { index, piece ->
                when (piece) {
                    is Piece.Words -> if (piece.bold) withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(piece.text) } else append(piece.text)
                    is Piece.Symbol -> {
                        val id = "symbol$index"
                        appendInlineContent(id, "[icon]")
                        inline[id] = InlineTextContent(Placeholder(1.1.em, 1.1.em, PlaceholderVerticalAlign.TextCenter)) {
                            Icon(piece.icon, null, tint = Theme.accent, modifier = Modifier.fillMaxSize())
                        }
                    }
                }
            }
        }
        return text to inline
    }
}

class Tour(private val scope: CoroutineScope) {
    var step by mutableStateOf(TourStep.OpenBrowse)
        private set
    var isPromptVisible by mutableStateOf(true)
        private set
    var isPaused by mutableStateOf(false)
    private var pendingPrompt: Job? = null

    fun complete(completed: TourStep, onlyIfCurrent: Boolean = false) {
        if (completed.ordinal < step.ordinal) return
        if (onlyIfCurrent && completed != step) return
        val next = TourStep.entries.getOrNull(completed.ordinal + 1) ?: return
        pendingPrompt?.cancel()
        step = next
        isPromptVisible = false
        pendingPrompt = scope.launch {
            delay(1000)
            showPrompt()
        }
    }

    val canGoBack get() = step != TourStep.entries.first()
    val canGoForward get() = step != TourStep.entries.last()

    fun goBack() = move(step.ordinal - 1)
    fun goForward() = move(step.ordinal + 1)

    private fun move(index: Int) {
        val destination = TourStep.entries.getOrNull(index) ?: return
        pendingPrompt?.cancel()
        step = destination
        isPromptVisible = true
    }

    fun dismissPrompt() {
        pendingPrompt?.cancel()
        isPromptVisible = false
    }

    fun showPrompt() {
        pendingPrompt?.cancel()
        isPromptVisible = true
    }
}

val LocalTour = compositionLocalOf<Tour?> { null }

@Composable
fun CompletesTourStep(step: TourStep, onlyIfCurrent: Boolean = false) {
    val tour = LocalTour.current
    LaunchedEffect(tour) { tour?.complete(step, onlyIfCurrent) }
}

@Composable
fun TourOverlay(tour: Tour, onSkip: () -> Unit, onFinish: () -> Unit) {
    val scale = LocalFontScale.current
    val alpha = animatedAlpha(!tour.isPaused)
    Box(Modifier.fillMaxSize().alpha(alpha)) {
        AnimatedVisibility(tour.isPromptVisible && !tour.isPaused, enter = fadeIn(), exit = fadeOut()) {
            Box(
                Modifier.fillMaxSize().background(Theme.bg.copy(alpha = 0.88f)).haptic(onClick = tour::dismissPrompt),
                contentAlignment = Alignment.Center,
            ) {
                Column(
                    Modifier
                        .padding(horizontal = Spacing.lg)
                        .shadow(18.dp, RoundedCornerShape(16.dp))
                        .card()
                        .haptic {}
                        .padding(Spacing.xl),
                    verticalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(tour.step.title, style = Typography.passageTitle.style(scale), color = Theme.inkBright, modifier = Modifier.weight(1f))
                        Text("${tour.step.ordinal + 1}/${TourStep.entries.size}", style = Typography.label.style(scale, 0.5f), color = Theme.faint)
                    }
                    val (body, inline) = tour.step.body()
                    Text(body, inlineContent = inline, style = Typography.callout.style(scale), color = Theme.muted)
                    for (note in tour.step.notes) {
                        InfoNote(Typography.footnote, color = Theme.faint, icon = note.icon, text = note.text)
                    }
                    Spacer(Modifier.size(Spacing.xs))
                    if (tour.step == TourStep.Finished) PrimaryButton("Start for real", onFinish)
                    else PrimaryButton("Try it", tour::dismissPrompt)
                    Row(Modifier.fillMaxWidth().padding(top = Spacing.xs), verticalAlignment = Alignment.CenterVertically) {
                        if (tour.step != TourStep.Finished) {
                            Text(
                                "Skip Walkthrough",
                                style = Typography.label.style(scale, 0.5f),
                                color = Theme.muted,
                                modifier = Modifier.haptic(onClick = onSkip).padding(vertical = Spacing.xs),
                            )
                        }
                        Spacer(Modifier.weight(1f))
                        Arrow(Icons.Outlined.ChevronLeft, tour.canGoBack, tour::goBack)
                        Arrow(Icons.Outlined.ChevronRight, tour.canGoForward, tour::goForward)
                    }
                }
            }
        }
        AnimatedVisibility(
            !tour.isPromptVisible && !tour.isPaused,
            enter = fadeIn() + scaleIn(initialScale = 0.8f),
            exit = fadeOut() + scaleOut(targetScale = 0.8f),
            modifier = Modifier.align(Alignment.BottomEnd).navigationBarsPadding().padding(end = Spacing.lg, bottom = 150.dp),
        ) {
            Box(
                Modifier
                    .size(44.dp)
                    .shadow(10.dp, CircleShape)
                    .background(Theme.accent, CircleShape)
                    .haptic(onClick = tour::showPrompt),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Outlined.QuestionMark, "Show tour", tint = Theme.bg, modifier = Modifier.size(20.dp))
            }
        }
    }
}

@Composable
private fun Arrow(icon: ImageVector, enabled: Boolean, onClick: () -> Unit) {
    Box(
        Modifier.size(width = 34.dp, height = 48.dp).haptic(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, tint = if (enabled) Theme.muted else Theme.faint, modifier = Modifier.size(22.dp))
    }
}

fun finishTour(onFinish: () -> Unit) {
    Feedback.sessionComplete()
    onFinish()
}
