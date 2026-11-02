package com.faizififita.verses.feature.contact

import androidx.compose.animation.AnimatedContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Mail
import androidx.compose.material.icons.outlined.Notes
import androidx.compose.material.icons.outlined.Verified
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.faizififita.verses.support.Feedback
import com.faizififita.verses.support.FeedbackForm
import com.faizififita.verses.theme.LocalFontScale
import com.faizififita.verses.theme.OptionSection
import com.faizififita.verses.theme.Screen
import com.faizififita.verses.theme.ScreenHeader
import com.faizififita.verses.theme.SendButton
import com.faizififita.verses.theme.Theme
import com.faizififita.verses.theme.Typography
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

enum class ContactPurpose(val title: String, val prompt: String, val sendTitle: String, val kind: String) {
    ReportIssue("Report Issue", "What went wrong?", "Send Report", FeedbackForm.PROBLEM),
    Feedback("Feedback", "What would you like the app to do?", "Send Feedback", FeedbackForm.IDEA),
}

@Composable
fun ContactScreen(purpose: ContactPurpose, onBack: () -> Unit) {
    val scope = rememberCoroutineScope()
    val focus = LocalFocusManager.current
    val scale = LocalFontScale.current
    var message by rememberSaveable { mutableStateOf("") }
    var email by rememberSaveable { mutableStateOf("") }
    var sending by rememberSaveable { mutableStateOf(false) }
    var sent by rememberSaveable { mutableStateOf(false) }
    var failed by rememberSaveable { mutableStateOf(false) }
    val canSend = !sending && message.isNotBlank()

    fun send() {
        focus.clearFocus()
        sending = true
        scope.launch {
            val delivered = FeedbackForm.submit(purpose.kind, message.trim(), email.trim())
            sending = false
            if (!delivered) {
                failed = true
                return@launch
            }
            Feedback.sessionComplete()
            sent = true
            delay(1600)
            onBack()
        }
    }

    Screen(header = { ScreenHeader(purpose.title, onBack = onBack) }) {
        AnimatedContent(sent, label = "contact") { done ->
            if (done) {
                Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically)) {
                    Icon(Icons.Outlined.Verified, null, tint = Theme.accent, modifier = Modifier.size(40.dp))
                    Text("Thank you", style = Typography.heading.style(scale), color = Theme.ink)
                    Text("Your note is on its way.", style = Typography.callout.style(scale), color = Theme.muted)
                }
            } else {
                Column(
                    Modifier.fillMaxSize().verticalScroll(rememberScrollState()).imePadding().padding(start = 18.dp, end = 18.dp, bottom = 32.dp),
                    verticalArrangement = Arrangement.spacedBy(18.dp),
                ) {
                    OptionSection("Message", Icons.Outlined.Notes) {
                        Box(Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 16.dp)) {
                            if (message.isEmpty()) Text(purpose.prompt, style = Typography.body.style(scale), color = Theme.faint)
                            BasicTextField(
                                message, { message = it },
                                textStyle = Typography.body.style(scale).copy(color = Theme.ink),
                                cursorBrush = SolidColor(Theme.accent),
                                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                                modifier = Modifier.fillMaxWidth().heightIn(min = 120.dp),
                            )
                        }
                    }
                    OptionSection("Email (Optional)", Icons.Outlined.Mail) {
                        Box(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 14.dp)) {
                            if (email.isEmpty()) Text("So I can write back", style = Typography.body.style(scale), color = Theme.faint)
                            BasicTextField(
                                email, { email = it },
                                singleLine = true,
                                textStyle = Typography.body.style(scale).copy(color = Theme.ink),
                                cursorBrush = SolidColor(Theme.accent),
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, autoCorrectEnabled = false),
                                modifier = Modifier.fillMaxWidth(),
                            )
                        }
                    }
                    SendButton(purpose.sendTitle, sending, canSend, ::send)
                }
            }
        }
    }

    if (failed) {
        AlertDialog(
            onDismissRequest = { failed = false },
            title = { Text("Couldn't send") },
            text = { Text("Your message wasn't delivered. Check your connection and try again.") },
            confirmButton = { TextButton(onClick = { Feedback.tap(); failed = false; send() }) { Text("Try again", color = Theme.accent) } },
            dismissButton = { TextButton(onClick = { Feedback.tap(); failed = false }) { Text("Cancel", color = Theme.muted) } },
            containerColor = Theme.raised,
            titleContentColor = Theme.ink,
            textContentColor = Theme.muted,
        )
    }
}
