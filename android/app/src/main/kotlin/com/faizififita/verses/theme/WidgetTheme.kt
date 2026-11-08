package com.faizififita.verses.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.color.ColorProvider
import androidx.glance.unit.ColorProvider
import com.faizififita.verses.logic.AppTheme

class WidgetPalette(appTheme: AppTheme) {
    private val provide: (Pair<Color, Color>) -> ColorProvider = when (appTheme) {
        AppTheme.System -> { pair -> ColorProvider(day = pair.first, night = pair.second) }
        AppTheme.Light -> { pair -> ColorProvider(pair.first) }
        AppTheme.Dark -> { pair -> ColorProvider(pair.second) }
    }

    val bg = provide(Theme.raisedPair)
    val ink = provide(Theme.inkPair)
    val muted = provide(Theme.mutedPair)
    val faint = provide(Theme.faintPair)
    val accent = provide(Theme.accentPair)
}

object WidgetType {
    val eyebrow = 11.sp
    val title = 17.sp
    val excerpt = 14.sp
    val detail = 12.sp
}

object WidgetSpacing {
    val padding = Spacing.lg
    val gap = Spacing.xs
    val corner = Radius.card
    val chromeHeight = 125.dp
    val excerptLineHeight = 19.dp
}
