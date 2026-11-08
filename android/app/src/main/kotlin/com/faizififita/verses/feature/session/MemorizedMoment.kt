package com.faizififita.verses.feature.session

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.faizififita.verses.R
import com.faizififita.verses.theme.Motion
import com.faizififita.verses.theme.Radius
import com.faizififita.verses.theme.Spacing
import com.faizififita.verses.theme.Theme
import com.faizififita.verses.theme.Typography
import com.faizififita.verses.theme.card
import com.faizififita.verses.theme.haptic

private val starSize = 104.dp
private const val STAR_START_SCALE = 0.82f
private const val ENTRY_SCALE = 0.96f

@Composable
fun BoxScope.MemorizedMoment(visible: Boolean, title: String, onDismiss: () -> Unit) {
    AnimatedVisibility(
        visible,
        Modifier.align(Alignment.Center),
        enter = fadeIn(Motion.fade()) + scaleIn(Motion.fade(), initialScale = ENTRY_SCALE),
        exit = fadeOut(Motion.fade()) + scaleOut(Motion.fade(), targetScale = ENTRY_SCALE),
    ) {
        val glow = remember { Animatable(0f) }
        LaunchedEffect(Unit) { glow.animateTo(1f, Motion.celebrate()) }
        val shape = RoundedCornerShape(Radius.panel)
        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.screen)
                .shadow(24.dp, shape, ambientColor = Theme.shadow.copy(alpha = 0.12f), spotColor = Theme.shadow.copy(alpha = 0.12f))
                .card(Radius.panel)
                .haptic(onClick = onDismiss)
                .semantics(mergeDescendants = true) {}
                .padding(horizontal = Spacing.xxl, vertical = Spacing.screen),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Image(
                painterResource(R.drawable.splash_star),
                null,
                modifier = Modifier
                    .size(starSize)
                    .graphicsLayer {
                        val scale = STAR_START_SCALE + (1 - STAR_START_SCALE) * glow.value
                        scaleX = scale
                        scaleY = scale
                    },
            )
            Text("Recited from memory", style = Typography.passageTitle.scaled, color = Theme.ink, textAlign = TextAlign.Center)
            Text(
                title,
                style = Typography.byline.scaled,
                color = Theme.muted,
                textAlign = TextAlign.Center,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}
