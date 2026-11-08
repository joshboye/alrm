package com.alrm.interval_alarms

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import androidx.core.app.NotificationCompat
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

object Notifs {
    const val CH_RING = "ring_v1"
    const val CH_MISSED = "missed_v1"
    const val RING_ID = 7001

    fun ensureChannels(ctx: Context) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CH_RING) == null) {
            val ch = NotificationChannel(CH_RING, "Ringing alarms", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Shows the alarm screen when an alarm rings"
                setSound(null, null)          // audio is played by AlarmService on the alarm stream
                enableVibration(false)        // vibration handled by AlarmService
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setBypassDnd(true)
            }
            nm.createNotificationChannel(ch)
        }
        if (nm.getNotificationChannel(CH_MISSED) == null) {
            val ch = NotificationChannel(CH_MISSED, "Missed alarms", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Alarms that rang without being stopped, or could not ring"
                setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI,
                    AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build())
            }
            nm.createNotificationChannel(ch)
        }
    }

    fun openAppIntent(ctx: Context, ring: Boolean = true): Intent =
        Intent(ctx, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra("ring", ring)

    fun openApp(ctx: Context, ring: Boolean): PendingIntent {
        val i = openAppIntent(ctx, ring)
        return PendingIntent.getActivity(ctx, if (ring) 1 else 2, i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun action(ctx: Context, act: String, req: Int): PendingIntent {
        val i = Intent(ctx, AlarmService::class.java).setAction(act)
        return PendingIntent.getService(ctx, req, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    fun timeText(ctx: Context, at: Long): String {
        val h24 = Store.settings(ctx).optBoolean("use24h", false)
        val f = DateTimeFormatter.ofPattern(if (h24) "HH:mm" else "hh:mm a")
        return Instant.ofEpochMilli(at).atZone(ZoneId.systemDefault()).format(f)
    }

    fun ringing(ctx: Context, label: String, at: Long, preview: Boolean): Notification {
        ensureChannels(ctx)
        val full = openApp(ctx, ring = true)
        return NotificationCompat.Builder(ctx, CH_RING)
            .setSmallIcon(R.drawable.ic_alarm)
            .setContentTitle(label.uppercase())
            .setContentText((if (preview) "PREVIEW · " else "ALARM · ") + timeText(ctx, at))
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setSilent(true)
            .setContentIntent(full)
            .setFullScreenIntent(full, true)
            .addAction(0, "SNOOZE 9 MIN", action(ctx, AlarmService.ACTION_SNOOZE, 11))
            .addAction(0, "STOP", action(ctx, AlarmService.ACTION_STOP, 12))
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    fun missed(ctx: Context, f: Fire, late: Boolean) {
        ensureChannels(ctx)
        val a = Store.alarm(ctx, f.alarmId)
        val label = (a?.optString("label")?.takeIf { it.isNotBlank() } ?: "Alarm").uppercase()
        val text = if (late) "Couldn't ring at ${timeText(ctx, f.at)} — the phone was off"
                   else "Rang at ${timeText(ctx, f.at)} and was not stopped"
        val n = NotificationCompat.Builder(ctx, CH_MISSED)
            .setSmallIcon(R.drawable.ic_alarm)
            .setContentTitle("MISSED · $label")
            .setContentText(text)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setContentIntent(openApp(ctx, ring = false))
            .setAutoCancel(true)
            .build()
        try {
            ctx.getSystemService(NotificationManager::class.java).notify((f.at / 1000 % 100000).toInt() + 8000, n)
        } catch (_: SecurityException) {}
    }
}
