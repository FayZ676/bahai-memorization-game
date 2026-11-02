package com.faizififita.verses.feature.achievements

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FrontHand
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.SelfImprovement
import androidx.compose.material.icons.filled.WbTwilight
import androidx.compose.material.icons.outlined.Bedtime
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.FrontHand
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.SelfImprovement
import androidx.compose.material.icons.outlined.WbTwilight
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.faizififita.verses.feature.onboarding.CompletesTourStep
import com.faizififita.verses.feature.onboarding.TourStep
import com.faizififita.verses.logic.Achievement
import com.faizififita.verses.logic.AchievementCatalog
import com.faizififita.verses.logic.AchievementSymbol
import com.faizififita.verses.logic.Percent
import com.faizififita.verses.store.AppStore
import com.faizififita.verses.theme.HairlineDivider
import com.faizififita.verses.theme.IconSize
import com.faizififita.verses.theme.LocalFontScale
import com.faizififita.verses.theme.Motion
import com.faizififita.verses.theme.Screen
import com.faizififita.verses.theme.ScreenHeader
import com.faizififita.verses.theme.Spacing
import com.faizififita.verses.theme.Theme
import com.faizififita.verses.theme.Typography
import com.faizififita.verses.theme.card
import com.faizififita.verses.theme.haptic

private fun AchievementSymbol.icon(earned: Boolean): ImageVector = when (this) {
    AchievementSymbol.Hands -> if (earned) Icons.Filled.SelfImprovement else Icons.Outlined.SelfImprovement
    AchievementSymbol.Sunrise -> if (earned) Icons.Filled.WbTwilight else Icons.Outlined.WbTwilight
    AchievementSymbol.Heart -> if (earned) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder
    AchievementSymbol.HandRaised -> if (earned) Icons.Filled.FrontHand else Icons.Outlined.FrontHand
    AchievementSymbol.House -> if (earned) Icons.Filled.Home else Icons.Outlined.Home
    AchievementSymbol.Moon -> if (earned) Icons.Filled.Bedtime else Icons.Outlined.Bedtime
    AchievementSymbol.Book -> if (earned) Icons.AutoMirrored.Filled.MenuBook else Icons.AutoMirrored.Outlined.MenuBook
}

@Composable
fun AchievementsScreen(store: AppStore, onBack: () -> Unit, onAchievement: (Achievement) -> Unit) {
    val memorized = store.memorizedPrayerIDs
    val scale = LocalFontScale.current
    CompletesTourStep(TourStep.Achievements, onlyIfCurrent = true)
    Screen(header = { ScreenHeader("Achievements", onBack = onBack) }) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(start = Spacing.lg, end = Spacing.lg, bottom = Spacing.xxl).navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(Spacing.xl),
        ) {
            val earned = AchievementCatalog.all.count { it.isEarned(memorized) }
            Row(Modifier.padding(horizontal = Spacing.xs), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                Text("$earned", style = Typography.tally.style(scale), color = Theme.muted)
                Text("of ${AchievementCatalog.all.size} Earned", style = Typography.footnote.style(scale, 0.5f), color = Theme.faint, modifier = Modifier.padding(bottom = 4.dp))
            }
            Column(Modifier.fillMaxWidth().card()) {
                AchievementCatalog.all.forEachIndexed { index, achievement ->
                    if (index > 0) HairlineDivider(Modifier.padding(start = Spacing.lg))
                    AchievementRow(
                        achievement = achievement,
                        earned = achievement.isEarned(memorized),
                        matched = achievement.matchedCount(memorized),
                        progress = store.progress(achievement),
                    ) { onAchievement(achievement) }
                }
            }
        }
    }
}

@Composable
private fun AchievementRow(achievement: Achievement, earned: Boolean, matched: Int, progress: Double?, onClick: () -> Unit) {
    val scale = LocalFontScale.current
    val required = achievement.requirement.count
    Row(
        Modifier.fillMaxWidth().haptic(onClick = onClick).padding(Spacing.lg),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.lg),
    ) {
        AchievementRing(progress, earned)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.xxs)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                Icon(achievement.symbol.icon(earned), null, tint = if (earned) Theme.gold else Theme.accent, modifier = Modifier.size((15 * scale).dp))
                Text(achievement.title, style = Typography.passageTitle.style(scale), color = if (earned) Theme.ink else Theme.muted)
            }
            Text(achievement.condition, style = Typography.caption.style(scale), color = Theme.muted)
            if (required > 1 && !earned) {
                Text("$matched of $required", style = Typography.micro.style(scale), color = if (matched > 0) Theme.gold else Theme.faint)
            }
        }
        Icon(Icons.Outlined.ChevronRight, null, tint = Theme.faint, modifier = Modifier.size(IconSize.row))
    }
}

@Composable
private fun AchievementRing(progress: Double?, earned: Boolean) {
    val track = Theme.ink.copy(alpha = 0.1f)
    val color = if (earned) Theme.gold else Theme.accent
    val sweep by animateFloatAsState(if (earned) 1f else (progress ?: 0.0).toFloat().coerceIn(0f, 1f), Motion.standard(), label = "ring")
    Box(Modifier.size(52.dp), contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(52.dp)) {
            val stroke = 4.dp.toPx()
            val inset = stroke / 2
            val arcSize = androidx.compose.ui.geometry.Size(size.width - stroke, size.height - stroke)
            val topLeft = androidx.compose.ui.geometry.Offset(inset, inset)
            drawArc(track, 0f, 360f, false, topLeft, arcSize, style = Stroke(stroke))
            drawArc(color, -90f, 360f * sweep, false, topLeft, arcSize, style = Stroke(stroke, cap = StrokeCap.Round))
        }
        val scale = LocalFontScale.current
        when {
            earned -> Icon(Icons.Outlined.Check, null, tint = Theme.gold, modifier = Modifier.size(18.dp))
            progress != null -> Text(Percent.label(progress), style = Typography.label.style(scale), color = Theme.accent)
            else -> Text("—", style = Typography.label.style(scale), color = Theme.accent)
        }
    }
}
