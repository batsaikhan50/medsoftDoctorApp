package com.example.medsoft_doctor

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

class ScreenCaptureService : Service() {
    companion object {
        private const val CHANNEL_ID = "screen_capture_channel"
        const val NOTIFICATION_ID = 1002

        // Holds a reference to the running instance so MainActivity can call
        // upgradeToMediaProjection() synchronously within the Android 14 consent window.
        var instance: ScreenCaptureService? = null
            private set

        // Called from MainActivity.onActivityResult() on Android 14+ to add the
        // MEDIA_PROJECTION foreground service type while still inside the consent window.
        // On Android 10-13 this is a no-op (the type is set in onStartCommand directly).
        fun upgradeToMediaProjection() {
            val svc = instance ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                val notification = svc.buildNotification()
                svc.startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
            }
        }
    }

    private fun buildNotification(): Notification {
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Screen sharing")
            .setContentText("Screen is being shared")
            .setSmallIcon(android.R.drawable.ic_menu_share)
            .build()
    }

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Screen Capture",
                NotificationManager.IMPORTANCE_LOW
            )
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        instance = this
        val notification = buildNotification()

        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE -> {
                // Android 14+: must specify a type (no-type call infers mediaProjection from
                // manifest, which requires consent we don't have yet → SecurityException).
                // Use MEDIA_PLAYBACK as a neutral initial type; MainActivity.onActivityResult()
                // will call upgradeToMediaProjection() synchronously within the consent window
                // to add MEDIA_PROJECTION before the Fragment calls getMediaProjection().
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> {
                // Android 10-13: MEDIA_PROJECTION type can be set immediately, no consent window.
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
            }
            else -> {
                startForeground(NOTIFICATION_ID, notification)
            }
        }

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
