package com.faizififita.verses.feature.settings

import android.Manifest
import android.app.TimePickerDialog
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Contrast
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.ExpandMore
import androidx.compose.material.icons.outlined.FormatSize
import androidx.compose.material.icons.outlined.HelpOutline
import androidx.compose.material.icons.outlined.Mail
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import com.faizififita.verses.logic.AppTheme
import com.faizififita.verses.logic.Difficulty
import com.faizififita.verses.logic.FontSize
import com.faizififita.verses.logic.Reminder
import com.faizififita.verses.store.AppStore
import com.faizififita.verses.support.AppInfo
import com.faizififita.verses.support.ReminderScheduler
import com.faizififita.verses.theme.DisclosureRow
import com.faizififita.verses.theme.HairlineDivider
import com.faizififita.verses.theme.IconSize
import com.faizififita.verses.theme.LocalFontScale
import com.faizififita.verses.theme.OptionSection
import com.faizififita.verses.theme.Screen
import com.faizififita.verses.theme.ScreenHeader
import com.faizififita.verses.theme.SegmentedPicker
import com.faizififita.verses.theme.Spacing
import com.faizififita.verses.theme.Theme
import com.faizififita.verses.theme.Typography
import com.faizififita.verses.theme.haptic
import com.faizififita.verses.theme.optionRow
import java.text.DateFormat
import java.util.Calendar

@Composable
fun SettingsScreen(
    store: AppStore,
    tourActive: Boolean,
    onBack: () -> Unit,
    onRestartTour: () -> Unit,
    onReleaseNotes: () -> Unit,
    onReportIssue: () -> Unit,
    onFeedback: () -> Unit,
) {
    val context = LocalContext.current
    val scale = LocalFontScale.current
    Screen(header = { ScreenHeader("Settings", onBack = onBack) }) {
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(start = 18.dp, end = 18.dp, bottom = Spacing.screen)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(22.dp),
        ) {
            OptionSection("Appearance", Icons.Outlined.Contrast) {
                SegmentedPicker(AppTheme.entries.map { it.label }, store.settings.appTheme.ordinal) { index ->
                    store.updateSettings { it.copy(appTheme = AppTheme.entries[index]) }
                }
            }
            OptionSection("Text Size", Icons.Outlined.FormatSize) {
                SegmentedPicker(FontSize.entries.map { it.label }, store.settings.fontSize.ordinal) { index ->
                    store.updateSettings { it.copy(fontSize = FontSize.entries[index]) }
                }
            }
            RemindersSection(store)
            OptionSection("Difficulty", Icons.Outlined.VisibilityOff, footer = "How hidden words look while you recite.") {
                SegmentedPicker(Difficulty.entries.map { it.label }, store.settings.difficulty.ordinal) { index ->
                    store.updateSettings { it.copy(difficulty = Difficulty.entries[index]) }
                }
            }
            OptionSection("Help", Icons.Outlined.HelpOutline) {
                DisclosureRow(if (tourActive) "Restart welcome tour" else "Show welcome tour", onRestartTour)
                HairlineDivider()
                DisclosureRow("What's new", onReleaseNotes)
            }
            OptionSection("Feedback", Icons.Outlined.Mail) {
                DisclosureRow("Report Issue", onReportIssue)
                HairlineDivider()
                DisclosureRow("Send feedback", onFeedback)
            }
            Column(Modifier.fillMaxWidth().padding(top = 10.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                Text(AppInfo.releaseSummary, style = Typography.micro.style(scale), color = Theme.faint)
                Text(
                    "Privacy Policy",
                    style = Typography.micro.style(scale).copy(textDecoration = TextDecoration.Underline),
                    color = Theme.muted,
                    modifier = Modifier
                        .haptic { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(AppInfo.PRIVACY_POLICY))) }
                        .padding(vertical = Spacing.xxs),
                )
            }
        }
    }
}

@Composable
private fun RemindersSection(store: AppStore) {
    val context = LocalContext.current
    val scale = LocalFontScale.current
    var expanded by rememberSaveable { mutableStateOf(false) }
    var permissionDenied by rememberSaveable { mutableStateOf(false) }
    val rotation by animateFloatAsState(if (expanded) 180f else 0f, label = "reminders")
    val settings = store.settings
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        permissionDenied = !granted
        store.updateSettings { it.copy(reminderEnabled = granted) }
    }
    val summary = when {
        !settings.reminderEnabled -> "Off"
        settings.reminders.size == 1 -> "On"
        else -> "${settings.reminders.size} reminders"
    }

    OptionSection(
        "Reminders", Icons.Outlined.Notifications,
        footer = if (permissionDenied) "Notifications are turned off for this app. Enable them in the Settings app to get reminders." else null,
    ) {
        Row(Modifier.fillMaxWidth().haptic { expanded = !expanded }.optionRow(), verticalAlignment = Alignment.CenterVertically) {
            Text("Daily reminders", style = Typography.body.style(scale), color = Theme.ink, modifier = Modifier.weight(1f))
            Text(summary, style = Typography.body.style(scale), color = Theme.muted)
            Spacer(Modifier.size(Spacing.sm))
            Icon(Icons.Outlined.ExpandMore, null, tint = Theme.faint, modifier = Modifier.size(IconSize.row).rotate(rotation))
        }
        AnimatedVisibility(expanded) {
            Column {
                HairlineDivider()
                Row(Modifier.fillMaxWidth().optionRow(), verticalAlignment = Alignment.CenterVertically) {
                    Text("Enabled", style = Typography.body.style(scale), color = Theme.ink, modifier = Modifier.weight(1f))
                    Switch(
                        checked = settings.reminderEnabled,
                        onCheckedChange = { enabled ->
                            com.faizififita.verses.support.Feedback.tap()
                            when {
                                !enabled -> store.updateSettings { it.copy(reminderEnabled = false) }
                                ReminderScheduler.hasPermission(context) -> {
                                    permissionDenied = false
                                    store.updateSettings { it.copy(reminderEnabled = true) }
                                }
                                Build.VERSION.SDK_INT >= 33 -> permission.launch(Manifest.permission.POST_NOTIFICATIONS)
                            }
                        },
                        colors = SwitchDefaults.colors(checkedTrackColor = Theme.accent, checkedThumbColor = Theme.raised, uncheckedTrackColor = Theme.hairline, uncheckedBorderColor = Theme.hairline, uncheckedThumbColor = Theme.faint),
                    )
                }
                if (settings.reminderEnabled) {
                    for (reminder in settings.reminders) {
                        HairlineDivider()
                        ReminderRow(store, reminder)
                    }
                    HairlineDivider()
                    Row(
                        Modifier.fillMaxWidth().haptic { store.updateSettings { it.copy(reminders = it.reminders + Reminder()) } }.optionRow(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
                    ) {
                        Icon(Icons.Outlined.Add, null, tint = Theme.accent, modifier = Modifier.size(IconSize.row))
                        Text("Add reminder", style = Typography.body.style(scale), color = Theme.accent)
                    }
                }
            }
        }
    }
}

@Composable
private fun ReminderRow(store: AppStore, reminder: Reminder) {
    val context = LocalContext.current
    val scale = LocalFontScale.current
    fun update(change: (Reminder) -> Reminder) = store.updateSettings { settings ->
        settings.copy(reminders = settings.reminders.map { if (it.id == reminder.id) change(it) else it })
    }
    val time = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, reminder.minuteOfDay / 60)
        set(Calendar.MINUTE, reminder.minuteOfDay % 60)
    }
    Column(Modifier.fillMaxWidth().optionRow(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Time", style = Typography.body.style(scale), color = Theme.ink, modifier = Modifier.weight(1f))
            Text(
                DateFormat.getTimeInstance(DateFormat.SHORT).format(time.time),
                style = Typography.body.style(scale),
                color = Theme.accent,
                textAlign = TextAlign.End,
                modifier = Modifier.haptic {
                    TimePickerDialog(
                        context,
                        { _, hour, minute -> update { it.copy(minuteOfDay = hour * 60 + minute) } },
                        reminder.minuteOfDay / 60,
                        reminder.minuteOfDay % 60,
                        android.text.format.DateFormat.is24HourFormat(context),
                    ).show()
                }.padding(vertical = Spacing.xxs),
            )
            if (store.settings.reminders.size > 1) {
                Icon(
                    Icons.Outlined.Delete, "Remove reminder", tint = Theme.muted,
                    modifier = Modifier
                        .padding(start = Spacing.md)
                        .size(IconSize.nav)
                        .haptic { store.updateSettings { s -> s.copy(reminders = s.reminders.filter { it.id != reminder.id }) } },
                )
            }
        }
        BasicTextField(
            reminder.message,
            { message -> update { it.copy(message = message) } },
            textStyle = Typography.body.style(scale).copy(color = Theme.muted),
            cursorBrush = SolidColor(Theme.accent),
            maxLines = 4,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}
