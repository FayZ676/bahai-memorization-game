package com.faizififita.verses.theme

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBackIos
import androidx.compose.material.icons.automirrored.outlined.Send
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.faizififita.verses.support.Feedback

fun Modifier.haptic(enabled: Boolean = true, role: Role = Role.Button, onClick: () -> Unit): Modifier = this.then(
    Modifier.clickable(
        interactionSource = null,
        indication = null,
        enabled = enabled,
        role = role,
    ) {
        Feedback.tap()
        onClick()
    }
)

@Composable
fun Modifier.card(radius: Dp = Radius.card): Modifier {
    val shape = RoundedCornerShape(radius)
    return this
        .clip(shape)
        .background(Theme.rowBg, shape)
        .border(1.dp, Theme.hairline, shape)
}

@Composable
fun IconButton(
    icon: ImageVector,
    contentDescription: String?,
    tint: Color = Theme.navIcon,
    size: Dp = IconSize.button,
    iconSize: Dp = IconSize.nav,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    LaunchedEffect(pressed) { if (pressed) Feedback.tap() }
    Box(
        modifier = Modifier
            .size(size)
            .alpha(if (pressed) 0.6f else 1f)
            .clip(CircleShape)
            .background(Theme.surface, CircleShape)
            .border(1.dp, Theme.hairline, CircleShape)
            .clickable(interactionSource = interaction, indication = null, enabled = enabled, role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription, tint = tint, modifier = Modifier.size(iconSize))
    }
}

@Composable
fun ScreenHeader(
    title: String,
    onBack: (() -> Unit)? = null,
    onTitleTap: (() -> Unit)? = null,
    slotWidth: Dp = IconSize.button,
    leading: @Composable () -> Unit = {},
    trailing: @Composable () -> Unit = {},
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 18.dp, end = 18.dp, top = 10.dp, bottom = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.width(slotWidth).height(IconSize.button), contentAlignment = Alignment.CenterStart) {
            if (onBack != null) IconButton(Icons.AutoMirrored.Outlined.ArrowBackIos, "Back", iconSize = 15.dp, onClick = onBack)
            else leading()
        }
        Text(
            title,
            style = Typography.passageTitle.scaled,
            color = Theme.inkBright,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .weight(1f)
                .then(if (onTitleTap != null) Modifier.haptic(onClick = onTitleTap) else Modifier),
        )
        Box(Modifier.width(slotWidth).height(IconSize.button), contentAlignment = Alignment.CenterEnd) {
            trailing()
        }
    }
}

@Composable
fun Screen(header: @Composable () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier
            .fillMaxSize()
            .background(Theme.bg)
            .statusBarsPadding()
    ) {
        header()
        Spacer(Modifier.height(Spacing.headerGap))
        content()
    }
}

@Composable
fun SectionLabel(text: String, icon: ImageVector? = null) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        modifier = Modifier.padding(horizontal = 6.dp),
    ) {
        if (icon != null) Icon(icon, null, tint = Theme.faint, modifier = Modifier.size(13.dp))
        Text(text, style = Typography.footnote.style(LocalFontScale.current, 0.3f), color = Theme.faint)
    }
}

@Composable
fun OptionSection(
    label: String? = null,
    icon: ImageVector? = null,
    footer: String? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column {
        if (label != null) {
            SectionLabel(label, icon)
            Spacer(Modifier.height(8.dp))
        }
        Column(Modifier.fillMaxWidth().card(Radius.group), content = content)
        if (footer != null) {
            Text(
                footer,
                style = Typography.caption.scaled,
                color = Theme.faint,
                modifier = Modifier.padding(start = 6.dp, end = 6.dp, top = 8.dp),
            )
        }
    }
}

fun Modifier.optionRow(): Modifier = padding(vertical = Spacing.md, horizontal = Spacing.lg)

@Composable
fun DisclosureRow(title: String, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().haptic(onClick = onClick).optionRow(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = Typography.body.scaled, color = Theme.ink, modifier = Modifier.weight(1f))
        Icon(Icons.Outlined.ChevronRight, null, tint = Theme.faint, modifier = Modifier.size(IconSize.row))
    }
}

@Composable
fun HairlineDivider(modifier: Modifier = Modifier, color: Color = Theme.hairline) {
    Box(modifier.fillMaxWidth().height(1.dp).background(color))
}

@Composable
fun SegmentedPicker(options: List<String>, selected: Int, onSelect: (Int) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(3.dp), horizontalArrangement = Arrangement.spacedBy(3.dp)) {
        options.forEachIndexed { index, option ->
            val isSelected = index == selected
            val fill by animateColorAsState(if (isSelected) Theme.accent.copy(alpha = 0.14f) else Color.Transparent, Motion.toggle(), label = "segment")
            Text(
                option,
                style = Typography.label.scaled,
                color = if (isSelected) Theme.ink else Theme.muted,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(Radius.inset))
                    .background(fill)
                    .haptic { onSelect(index) }
                    .padding(vertical = Spacing.sm),
            )
        }
    }
}

@Composable
fun InfoNote(
    token: AppTextToken,
    color: Color = Theme.muted,
    icon: ImageVector = Icons.Outlined.Info,
    text: String,
    textColor: Color = color,
    modifier: Modifier = Modifier,
) {
    val scale = LocalFontScale.current
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(Spacing.xs)) {
        Icon(icon, null, tint = color, modifier = Modifier.padding(top = 2.dp).size((token.size * scale).dp))
        Text(text, style = token.scaled, color = textColor)
    }
}

@Composable
fun PrimaryButton(title: String, onClick: () -> Unit) {
    Text(
        title,
        style = Typography.button.scaled,
        color = Theme.bg,
        textAlign = TextAlign.Center,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(50))
            .background(Theme.accent)
            .haptic(onClick = onClick)
            .padding(vertical = Spacing.md),
    )
}

@Composable
fun SendButton(title: String, sending: Boolean, enabled: Boolean, onClick: () -> Unit) {
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(50))
            .background(if (enabled) Theme.accent else Theme.accentMuted)
            .haptic(enabled = enabled, onClick = onClick)
            .padding(vertical = Spacing.md),
        contentAlignment = Alignment.Center,
    ) {
        if (sending) {
            CircularProgressIndicator(color = Theme.bg, strokeWidth = 2.dp, modifier = Modifier.size(22.dp))
        } else {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.AutoMirrored.Outlined.Send, null, tint = Theme.bg, modifier = Modifier.size(IconSize.row))
                Text(title, style = Typography.button.scaled, color = Theme.bg)
            }
        }
    }
}

@Composable
fun PassageCard(
    title: String,
    author: String? = null,
    section: String? = null,
    detail: String? = null,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier.fillMaxWidth().padding(horizontal = Spacing.lg, vertical = Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Spacing.xs),
    ) {
        Text(title, style = Typography.passageTitle.scaled, color = Theme.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            if (author != null) Text(author, style = Typography.byline.scaled, color = Theme.faint, maxLines = 1)
            if (section != null) {
                if (author != null) Text("·", style = Typography.footnote.scaled, color = Theme.faint)
                Text(
                    section,
                    style = Typography.footnote.scaled,
                    color = Theme.faint,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false),
                )
            }
            Spacer(Modifier.weight(1f))
            if (detail != null) Text(detail, style = Typography.footnote.scaled, color = Theme.faint, maxLines = 1)
        }
    }
}

@Composable
fun Colophon(author: String) {
    Text(
        "— $author",
        style = Typography.attribution.scaled,
        color = Theme.faint,
        textAlign = TextAlign.End,
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
fun EmptyNote(message: String) {
    Text(
        message,
        style = Typography.body.scaled,
        color = Theme.muted,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth().padding(top = 40.dp),
    )
}

@Composable
fun animatedAlpha(visible: Boolean, durationMillis: Int = Motion.FOCUS): Float {
    val alpha by animateFloatAsState(if (visible) 1f else 0f, androidx.compose.animation.core.tween(durationMillis, easing = Motion.easeInOut), label = "alpha")
    return alpha
}
