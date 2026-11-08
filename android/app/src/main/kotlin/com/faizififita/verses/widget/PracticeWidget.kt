package com.faizififita.verses.widget

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalSize
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.action.clickable
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.text.FontFamily
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import com.faizififita.verses.MainActivity
import com.faizififita.verses.VersesApplication
import com.faizififita.verses.logic.Passage
import com.faizififita.verses.logic.Percent
import com.faizififita.verses.logic.PracticeAge
import com.faizififita.verses.logic.PracticeQueue
import com.faizififita.verses.theme.WidgetPalette
import com.faizififita.verses.theme.WidgetSpacing
import com.faizififita.verses.theme.WidgetType

class PracticeWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val store = (context.applicationContext as VersesApplication).store
        provideContent {
            PracticeCard(
                context,
                PracticeQueue.next(store.passages),
                WidgetPalette(store.settings.appTheme),
                System.currentTimeMillis(),
            )
        }
    }

    companion object {
        suspend fun refresh(context: Context) = PracticeWidget().updateAll(context)

        fun openIntent(context: Context, passageID: String?): Intent =
            Intent(context, MainActivity::class.java)
                .setAction(Intent.ACTION_VIEW)
                .setData(passageID?.let { Uri.parse("$PASSAGE_URI$it") })

        fun passageID(intent: Intent?): String? =
            intent?.data?.toString()?.takeIf { it.startsWith(PASSAGE_URI) }?.removePrefix(PASSAGE_URI)

        private const val PASSAGE_URI = "verses://passage/"
    }
}

class PracticeWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget = PracticeWidget()
}

@Composable
private fun PracticeCard(context: Context, passage: Passage?, palette: WidgetPalette, now: Long) {
    val excerptLines = ((LocalSize.current.height - WidgetSpacing.chromeHeight) / WidgetSpacing.excerptLineHeight).toInt()
    Column(
        GlanceModifier
            .fillMaxSize()
            .appWidgetBackground()
            .cornerRadius(WidgetSpacing.corner)
            .background(palette.bg)
            .padding(WidgetSpacing.padding)
            .clickable(actionStartActivity(PracticeWidget.openIntent(context, passage?.id))),
        verticalAlignment = Alignment.Top,
    ) {
        if (passage == null) {
            Text("Verses", style = TextStyle(color = palette.faint, fontSize = WidgetType.eyebrow))
            Spacer(GlanceModifier.defaultWeight())
            Text(
                "Add a prayer to your library",
                style = TextStyle(color = palette.ink, fontSize = WidgetType.title, fontFamily = FontFamily.Serif),
            )
            return@Column
        }
        Text(
            PracticeAge.label(passage.lastPracticed, now),
            style = TextStyle(color = palette.accent, fontSize = WidgetType.eyebrow, fontWeight = FontWeight.Medium),
            maxLines = 1,
        )
        Spacer(GlanceModifier.height(WidgetSpacing.gap))
        Text(
            passage.title,
            style = TextStyle(color = palette.ink, fontSize = WidgetType.title, fontWeight = FontWeight.Medium, fontFamily = FontFamily.Serif),
            maxLines = 2,
        )
        if (excerptLines > 0) {
            Spacer(GlanceModifier.height(WidgetSpacing.gap))
            Text(
                Passage.paragraphsOf(passage.text).joinToString("\n"),
                style = TextStyle(color = palette.muted, fontSize = WidgetType.excerpt, fontFamily = FontFamily.Serif),
                maxLines = excerptLines,
            )
        }
        Spacer(GlanceModifier.defaultWeight())
        Text(
            "${Percent.label(passage.hiddenFraction)} memorized",
            style = TextStyle(color = palette.faint, fontSize = WidgetType.detail),
            maxLines = 1,
        )
    }
}
