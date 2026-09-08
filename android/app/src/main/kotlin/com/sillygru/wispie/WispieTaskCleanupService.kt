package com.sillygru.wispie

import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import com.ryanheise.audioservice.AudioService

/**
 * Task-removal watchdog for the audio notification.
 *
 * audio_service binds to its own [AudioService], so the playback service
 * itself cannot be subclassed. EMUI (Huawei) does not reliably stop that
 * service on swipe-away, leaving an ongoing notification with buttons
 * pointing at a dead Dart handler. Any [Service.onTaskRemoved] still runs
 * natively after Dart is gone, so this standalone service performs the
 * same cleanup: cancel the notification and stop the audio service.
 */
class WispieTaskCleanupService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int =
        START_NOT_STICKY

    override fun onTaskRemoved(rootIntent: Intent?) {
        try {
            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(AUDIO_SERVICE_NOTIFICATION_ID)
        } catch (_: SecurityException) {
            // Best-effort cleanup; never crash task removal.
        } catch (_: Exception) {
        }
        try {
            stopService(Intent(this, AudioService::class.java))
        } catch (_: SecurityException) {
        } catch (_: Exception) {
        }
        try {
            super.onTaskRemoved(rootIntent)
        } catch (_: Exception) {
        }
        stopSelf()
    }

    companion object {
        /** Mirrors private AudioService.NOTIFICATION_ID in audio_service. */
        private const val AUDIO_SERVICE_NOTIFICATION_ID = 1124
    }
}
