package com.faizififita.verses.theme

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.faizififita.verses.R
import kotlin.math.pow

val LocalDark = staticCompositionLocalOf { false }
val LocalFontScale = staticCompositionLocalOf { 1f }

private fun adaptive(light: Long, dark: Long) = Pair(Color(light or 0xFF000000), Color(dark or 0xFF000000))

object Theme {
    private val bgPair = adaptive(0xECEEE8, 0x121212)
    private val raisedPair = adaptive(0xFAFBF7, 0x1E1E1E)
    private val inkPair = adaptive(0x1C2521, 0xEDEDED)
    private val mutedPair = adaptive(0x6A716B, 0x9A9A9A)
    private val faintPair = adaptive(0x9DA39C, 0x6A6A6A)
    private val hairlinePair = adaptive(0xDFE2DB, 0x2E2E2E)
    private val accentPair = adaptive(0x2F6E5B, 0xC89A5A)
    private val accentMutedPair = adaptive(0xB9BEBA, 0x4A3D28)
    private val warnPair = adaptive(0xB4443A, 0xD98A80)

    @Composable @ReadOnlyComposable
    private fun pick(pair: Pair<Color, Color>) = if (LocalDark.current) pair.second else pair.first

    val bg @Composable @ReadOnlyComposable get() = pick(bgPair)
    val raised @Composable @ReadOnlyComposable get() = pick(raisedPair)
    val rowBg @Composable @ReadOnlyComposable get() = raised
    val surface @Composable @ReadOnlyComposable get() = raised
    val ink @Composable @ReadOnlyComposable get() = pick(inkPair)
    val inkBright @Composable @ReadOnlyComposable get() = ink
    val muted @Composable @ReadOnlyComposable get() = pick(mutedPair)
    val faint @Composable @ReadOnlyComposable get() = pick(faintPair)
    val navIcon @Composable @ReadOnlyComposable get() = muted
    val disabled @Composable @ReadOnlyComposable get() = faint
    val hiddenInk @Composable @ReadOnlyComposable get() = faint
    val hairline @Composable @ReadOnlyComposable get() = pick(hairlinePair)
    val accent @Composable @ReadOnlyComposable get() = pick(accentPair)
    val accentMuted @Composable @ReadOnlyComposable get() = pick(accentMutedPair)
    val warn @Composable @ReadOnlyComposable get() = pick(warnPair)
    val shadow = Color.Black
}

object Spacing {
    val xxs = 4.dp
    val xs = 6.dp
    val sm = 8.dp
    val md = 12.dp
    val lg = 16.dp
    val xl = 20.dp
    val screen = 24.dp
    val xxl = 32.dp
    val headerGap = xxs
}

object Radius {
    val word = 6.dp
    val inset = 8.dp
    val control = 10.dp
    val group = 12.dp
    val card = 16.dp
    val panel = 28.dp
}

object Motion {
    val easeInOut = CubicBezierEasing(0.42f, 0f, 0.58f, 1f)
    val easeOut = CubicBezierEasing(0f, 0f, 0.58f, 1f)
    const val TOGGLE = 220
    const val STANDARD = 280
    const val HANDOFF = 950
    const val FADE = 350
    const val LINE_FADE_DELAY = 500
    const val FOCUS = 250
    const val REVEAL = 120
    const val SCROLL = 400
    const val CASCADE_SPAN = 0.6

    fun <T> toggle() = tween<T>(TOGGLE, easing = easeInOut)
    fun <T> standard() = tween<T>(STANDARD, easing = easeInOut)
    fun <T> focus() = tween<T>(FOCUS, easing = easeInOut)
    fun <T> fade(delay: Int = 0) = tween<T>(FADE, delay, easeInOut)
    fun <T> reveal() = tween<T>(REVEAL, easing = easeOut)
    fun <T> push() = tween<T>(STANDARD, easing = FastOutSlowInEasing)
    fun <T> settle() = tween<T>(TOGGLE, easing = LinearOutSlowInEasing)

    fun cascadeDelay(index: Int, count: Int): Double {
        if (count <= 1) return 0.0
        val t = index.toDouble() / (count - 1)
        return CASCADE_SPAN * (1 - (1 - t).pow(1.8))
    }
}

enum class TextFace(val opticalScale: Float) { Sans(1f), Serif(1.08f) }

val Garamond = FontFamily(
    Font(R.font.eb_garamond_regular, FontWeight.Normal),
    Font(R.font.eb_garamond_medium, FontWeight.Medium),
    Font(R.font.eb_garamond_semibold, FontWeight.SemiBold),
    Font(R.font.eb_garamond_bold, FontWeight.Bold),
    Font(R.font.eb_garamond_italic, FontWeight.Normal, FontStyle.Italic),
    Font(R.font.eb_garamond_mediumitalic, FontWeight.Medium, FontStyle.Italic),
    Font(R.font.eb_garamond_semibolditalic, FontWeight.SemiBold, FontStyle.Italic),
    Font(R.font.eb_garamond_bolditalic, FontWeight.Bold, FontStyle.Italic),
)

data class AppTextToken(
    val size: Float,
    val weight: FontWeight = FontWeight.Normal,
    val face: TextFace = TextFace.Sans,
    val italic: Boolean = false,
) {
    fun weight(weight: FontWeight) = copy(weight = weight)

    fun style(scale: Float, letterSpacing: Float = 0f): TextStyle = TextStyle(
        fontSize = (size * scale * face.opticalScale).sp,
        fontWeight = weight,
        fontStyle = if (italic) FontStyle.Italic else FontStyle.Normal,
        fontFamily = if (face == TextFace.Serif) Garamond else FontFamily.Default,
        letterSpacing = letterSpacing.sp,
    )

    val scaled: TextStyle
        @Composable @ReadOnlyComposable get() = style(LocalFontScale.current)
}

object Typography {
    val button = AppTextToken(17f, FontWeight.SemiBold)
    val subtitle = AppTextToken(17f, FontWeight.SemiBold)
    val body = AppTextToken(16f)
    val callout = AppTextToken(15f)
    val label = AppTextToken(13f, FontWeight.Medium)
    val caption = AppTextToken(13f)
    val footnote = AppTextToken(12f)
    val micro = AppTextToken(11f)

    val heading = AppTextToken(32f, FontWeight.SemiBold, TextFace.Serif)
    val passageTitle = AppTextToken(21f, FontWeight.SemiBold, TextFace.Serif)

    val tally = AppTextToken(22f, FontWeight.Light)
    val recite = AppTextToken(26f, face = TextFace.Serif)
    val verse = AppTextToken(20f, face = TextFace.Serif)
    val verseInitial = AppTextToken(32f, face = TextFace.Serif)
    val excerpt = AppTextToken(15f, face = TextFace.Serif)

    val attribution = AppTextToken(20f, FontWeight.SemiBold, TextFace.Serif, italic = true)
    val byline = AppTextToken(13f, FontWeight.SemiBold, TextFace.Serif, italic = true)
}

object IconSize {
    val nav = 18.dp
    val button = 38.dp
    val small = 14.dp
    val row = 16.dp
}
