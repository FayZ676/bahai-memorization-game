package com.faizififita.verses.feature.releasenotes

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Android
import androidx.compose.material.icons.outlined.GraphicEq
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.QuestionMark
import androidx.compose.material.icons.outlined.TouchApp
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.Widgets
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.faizififita.verses.logic.AppSettings
import com.faizififita.verses.theme.LocalFontScale
import com.faizififita.verses.theme.PrimaryButton
import com.faizififita.verses.theme.Spacing
import com.faizififita.verses.theme.Theme
import com.faizififita.verses.theme.Typography
import com.faizififita.verses.theme.card
import com.faizififita.verses.theme.haptic

data class ReleaseHighlight(val icon: ImageVector, val title: String, val text: String)

data class ReleaseNote(val version: String, val headline: String, val highlights: List<ReleaseHighlight>)

object ReleaseNotes {
    val all = listOf(
        ReleaseNote(
            version = "1.0.8",
            headline = "Choose how hidden words look, and see your place as you say a prayer.",
            highlights = listOf(
                ReleaseHighlight(Icons.Outlined.VisibilityOff, "Lines or nothing", "When you say a prayer out loud, a hidden word can show as a line, or as an empty space. Tap the three dots at the top of a prayer to choose."),
                ReleaseHighlight(Icons.Outlined.Mic, "See where you are", "A soft green light sits where the next word goes, so you always know your place."),
                ReleaseHighlight(Icons.Outlined.Visibility, "Words come back softly", "Each word you say shows again slowly, from left to right."),
            ),
        ),
        ReleaseNote(
            version = "1.0.7",
            headline = "When you say a whole prayer from memory, you now see a star.",
            highlights = listOf(
                ReleaseHighlight(Icons.Outlined.Mic, "Said from memory", "Hide every word, then say the whole prayer from the start. When you finish, you see a star."),
                ReleaseHighlight(Icons.Outlined.Widgets, "More of the prayer", "The widget on your home screen now shows more of the prayer, not just its first line."),
            ),
        ),
        ReleaseNote(
            version = "1.0.6",
            headline = "Put a prayer on your home screen to remind you to practice.",
            highlights = listOf(
                ReleaseHighlight(Icons.Outlined.Widgets, "A prayer on your home screen", "The Verses widget shows the prayer you have gone longest without practicing. Tap it to open that prayer."),
                ReleaseHighlight(Icons.Outlined.TouchApp, "How to add it", "Touch and hold an empty spot on your home screen, tap Widgets, then find Verses."),
            ),
        ),
        ReleaseNote(
            version = "1.0.5",
            headline = "A word you hide while you say the prayer now comes back when you say it.",
            highlights = listOf(
                ReleaseHighlight(Icons.Outlined.TouchApp, "Hide it, then say it", "Tap a word while you say the prayer to hide it. When you get to that word and say it, it shows again."),
                ReleaseHighlight(Icons.Outlined.QuestionMark, "Help in the corner", "In the welcome tour, the question mark button now sits in the bottom corner. When a prayer is open, it sits just above the buttons."),
            ),
        ),
        ReleaseNote(
            version = "1.0.2",
            headline = "You can now show or hide words while you say the prayer out loud.",
            highlights = listOf(
                ReleaseHighlight(Icons.Outlined.Visibility, "See a word you forgot", "Forgot a word while you say the prayer? Tap the empty space where it goes. The word shows, and you can keep going."),
                ReleaseHighlight(Icons.Outlined.VisibilityOff, "Hide words as you go", "Tap a word while you say the prayer to hide it. Tap away from the words when you want to stop."),
            ),
        ),
        ReleaseNote(
            version = "1.0.0",
            headline = "Verses is now on Android.",
            highlights = listOf(
                ReleaseHighlight(Icons.Outlined.Android, "Welcome", "Everything from the iPhone app is here: the Writings, hiding words, and reciting out loud."),
                ReleaseHighlight(Icons.Outlined.GraphicEq, "It hears every word", "Saying a prayer out loud uses a listener that runs entirely on your phone. It can tell Thy from my. If you miss a word twice, it shows you that word."),
                ReleaseHighlight(Icons.Outlined.Mic, "Just you and the prayer", "Tap Recite and everything else fades away, so only the prayer is left. Tap the page when you want to stop."),
            ),
        ),
    )

    val latest: ReleaseNote? get() = all.firstOrNull()

    fun unseen(version: String, settings: AppSettings): ReleaseNote? {
        if (!settings.hasSeenWelcomeTour || settings.lastSeenReleaseNotesVersion == version) return null
        return all.firstOrNull { it.version == version }
    }
}

@Composable
fun ReleaseNotesOverlay(note: ReleaseNote, onDismiss: () -> Unit) {
    val scale = LocalFontScale.current
    Box(
        Modifier.fillMaxSize().background(Theme.bg.copy(alpha = 0.88f)).haptic(onClick = onDismiss),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            Modifier
                .padding(horizontal = Spacing.md)
                .shadow(18.dp, androidx.compose.foundation.shape.RoundedCornerShape(16.dp))
                .card()
                .haptic {}
                .padding(Spacing.xl),
            verticalArrangement = Arrangement.spacedBy(Spacing.lg),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                Text("Version ${note.version}", style = Typography.label.style(scale, 0.6f), color = Theme.faint)
                Text("What's New", style = Typography.heading.style(scale), color = Theme.inkBright)
                Text(note.headline, style = Typography.callout.style(scale), color = Theme.muted)
            }
            Column(
                Modifier.heightIn(max = (400 * scale).dp).verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(Spacing.lg),
            ) {
                for (highlight in note.highlights) {
                    Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                        Box(Modifier.size((34 * scale).dp).background(Theme.bg, CircleShape), contentAlignment = Alignment.Center) {
                            Icon(highlight.icon, null, tint = Theme.accent, modifier = Modifier.size((16 * scale).dp))
                        }
                        Column(verticalArrangement = Arrangement.spacedBy(Spacing.xxs)) {
                            Text(highlight.title, style = Typography.subtitle.style(scale), color = Theme.ink)
                            Text(highlight.text, style = Typography.callout.style(scale), color = Theme.muted)
                        }
                    }
                }
            }
            Box(Modifier.fillMaxWidth()) { PrimaryButton("Continue", onDismiss) }
        }
    }
}
