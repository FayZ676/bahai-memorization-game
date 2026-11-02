package com.faizififita.verses.feature.splash

import android.provider.Settings
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.faizififita.verses.R
import com.faizififita.verses.support.Feedback
import com.faizififita.verses.theme.Theme
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private const val ARRIVAL = 550
private const val BEAT = 700L
private const val LIFT = 500
private const val CARRY = 620
private const val HANDOFF_LEAD = 280
private const val FADE_WIDTH = 0.77f
private const val FADE_MID = 0.63f
private const val FADE_MID_OPACITY = 0.16f

@Composable
fun SplashScreen(onFinish: () -> Unit) {
    val context = LocalContext.current
    val finish by rememberUpdatedState(onFinish)
    val arrival = remember { Animatable(0f) }
    val sweep = remember { Animatable(0f) }
    var dismissed by remember { mutableStateOf(false) }
    fun done() {
        if (dismissed) return
        dismissed = true
        finish()
    }
    val reduceMotion = remember {
        Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    }

    LaunchedEffect(Unit) {
        if (reduceMotion) {
            arrival.snapTo(1f)
            delay(BEAT)
            done()
            return@LaunchedEffect
        }
        arrival.animateTo(1f, tween(ARRIVAL, easing = CubicBezierEasing(0f, 0f, 0.58f, 1f)))
        delay(BEAT)
        if (dismissed) return@LaunchedEffect
        Feedback.cascadeRipple(listOf(0.05, 0.26, 0.47, 0.68, 0.89))
        launch {
            sweep.animateTo(0.3f, tween(LIFT, easing = CubicBezierEasing(0.42f, 0f, 0.58f, 1f)))
            sweep.animateTo(1f, tween(CARRY, easing = CubicBezierEasing(0.42f, 0f, 0.58f, 1f)))
        }
        delay((LIFT + CARRY - HANDOFF_LEAD).toLong())
        done()
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(Theme.bg)
            .pointerInput(Unit) { detectTapGestures { done() } },
        contentAlignment = Alignment.Center,
    ) {
        Image(
            painterResource(R.drawable.splash_star),
            null,
            modifier = Modifier
                .size(232.dp)
                .graphicsLayer {
                    val scale = 0.94f + 0.06f * arrival.value
                    scaleX = scale
                    scaleY = scale
                    alpha = arrival.value
                    compositingStrategy = CompositingStrategy.Offscreen
                }
                .drawWithContent {
                    drawContent()
                    val progress = sweep.value
                    if (progress <= 0f) return@drawWithContent
                    val width = size.width * FADE_WIDTH
                    val edge = size.width * 1.1f + (-width - size.width * 0.1f - size.width * 1.1f) * progress
                    drawRect(
                        Brush.horizontalGradient(
                            0f to Color.Black.copy(alpha = 0f),
                            FADE_MID to Color.Black.copy(alpha = 1 - FADE_MID_OPACITY),
                            1f to Color.Black,
                            startX = edge,
                            endX = edge + width,
                        ),
                        blendMode = BlendMode.DstOut,
                    )
                },
        )
    }
}
