package com.faizififita.verses.support

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.faizififita.verses.MainActivity
import com.faizififita.verses.R
import com.faizififita.verses.VersesApplication
import com.faizififita.verses.logic.AppSettings
import java.util.Calendar

object ReminderScheduler {
    private const val CHANNEL = "daily-memorization-reminder"
    private const val SLOTS = 12
    const val EXTRA_SLOT = "slot"
    private const val WINDOW_MILLIS = 10 * 60 * 1000L

    fun hasPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    fun sync(context: Context, settings: AppSettings) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        for (slot in 0 until SLOTS) alarms.cancel(pending(context, slot))
        if (!settings.reminderEnabled || !hasPermission(context)) return
        ensureChannel(context)
        settings.reminders.take(SLOTS).forEachIndexed { slot, reminder ->
            schedule(context, alarms, slot, reminder.minuteOfDay)
        }
    }

    fun fire(context: Context, slot: Int) {
        val settings = (context.applicationContext as VersesApplication).store.settings
        val reminder = settings.reminders.getOrNull(slot) ?: return
        if (!settings.reminderEnabled || !hasPermission(context)) return
        ensureChannel(context)
        val message = reminder.message.trim().ifEmpty { AppSettings.DEFAULT_REMINDER_MESSAGE }
        val open = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Time to memorize")
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        runCatching { NotificationManagerCompat.from(context).notify(slot, notification) }
        context.getSystemService(AlarmManager::class.java)?.let { schedule(context, it, slot, reminder.minuteOfDay) }
    }

    private fun schedule(context: Context, alarms: AlarmManager, slot: Int, minuteOfDay: Int) {
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, minuteOfDay / 60)
            set(Calendar.MINUTE, minuteOfDay % 60)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis() + 1000) add(Calendar.DAY_OF_YEAR, 1)
        }
        alarms.setWindow(AlarmManager.RTC_WAKEUP, next.timeInMillis, WINDOW_MILLIS, pending(context, slot))
    }

    private fun pending(context: Context, slot: Int): PendingIntent = PendingIntent.getBroadcast(
        context,
        slot,
        Intent(context, ReminderReceiver::class.java).putExtra(EXTRA_SLOT, slot),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun ensureChannel(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL) != null) return
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL, context.getString(R.string.reminder_channel), NotificationManager.IMPORTANCE_DEFAULT)
        )
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ReminderScheduler.fire(context, intent.getIntExtra(ReminderScheduler.EXTRA_SLOT, 0))
    }
}

class ReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ReminderScheduler.sync(context, (context.applicationContext as VersesApplication).store.settings)
    }
}
