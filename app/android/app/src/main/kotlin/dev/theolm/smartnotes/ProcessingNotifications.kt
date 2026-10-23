package dev.theolm.smartnotes

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

class ProcessingNotifications(private val context: Context) {
    fun show(arguments: Map<*, *>) {
        val channelName = arguments["channel"] as? String ?: "Note processing"
        if (Build.VERSION.SDK_INT >= 26) {
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, channelName, NotificationManager.IMPORTANCE_LOW).apply {
                    description = channelName
                    setSound(null, null)
                    enableVibration(false)
                    lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
                }
            )
        }
        val entryId = arguments["entryId"] as String
        val title = arguments["title"] as String
        val body = arguments["body"] as String
        val detail = arguments["detail"] as String
        val launch = Intent(context, MainActivity::class.java).apply {
            action = OPEN_ENTRY
            putExtra(ENTRY_ID, entryId)
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pending = PendingIntent.getActivity(
            context,
            NOTIFICATION_ID,
            launch,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(android.R.drawable.stat_notify_sync_noanim)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText("$body\n$detail"))
            .setContentIntent(pending)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setOngoing(true)
            .setLocalOnly(true)
            .build()
        try {
            context.getSystemService(NotificationManager::class.java)
                .notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // Permission denial never stops local inference.
        }
    }

    fun dismiss() {
        context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_ID)
    }

    companion object {
        const val OPEN_ENTRY = "dev.theolm.smartnotes.OPEN_ENTRY"
        const val ENTRY_ID = "entryId"
        private const val CHANNEL = "note_processing"
        private const val NOTIFICATION_ID = 0x534E01
    }
}
