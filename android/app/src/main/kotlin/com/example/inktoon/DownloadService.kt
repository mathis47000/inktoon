package com.example.inktoon

import android.app.Notification
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class DownloadService : Service() {

    companion object {
        const val ACTION_UPDATE = "com.example.inktoon.DOWNLOAD_UPDATE"
        const val ACTION_STOP   = "com.example.inktoon.DOWNLOAD_STOP"
        private const val NOTIF_ID   = 1000
        private const val CHANNEL_ID = "inktoon_export"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            stopSelf()
            return START_NOT_STICKY
        }

        val title    = intent?.getStringExtra("title")    ?: "Téléchargement"
        val text     = intent?.getStringExtra("text")     ?: "Démarrage..."
        val progress = intent?.getIntExtra("progress", 0) ?: 0
        val max      = intent?.getIntExtra("max", 0)      ?: 0
        val notif    = buildNotification(title, text, progress, max)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIF_ID, notif)
        }

        return START_NOT_STICKY
    }

    private fun buildNotification(title: String, text: String, progress: Int, max: Int): Notification {
        val indeterminate = max == 0 && text == "Démarrage..."
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(title)
            .setContentText(text)
            .setProgress(max, progress, indeterminate)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }
}
