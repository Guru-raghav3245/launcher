package com.example.launcher

import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

private const val CHANNEL = "student.launcher/music"

/// The Music tile's now-playing and transport controls (Phase 9 task 6),
/// through MediaSessionManager, which needs notification access for
/// MediaListenerService. Access is granted on Android's Notification access
/// screen; there's no runtime dialog for it.
class MusicBridge(private val activity: MainActivity) {
    private val listener = ComponentName(activity, MediaListenerService::class.java)

    fun attach(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAccess" -> result.success(hasAccess())
                "openAccessSettings" -> {
                    // Android 11+ can open this app's own switch directly.
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                            .putExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME, listener.flattenToString())
                    } else {
                        Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    }
                    activity.openExternal(intent)
                    result.success(null)
                }
                "nowPlaying" -> activity.inBackground(result) { controller()?.let(::describe) }
                "control" -> {
                    val controls = controller()?.transportControls
                    when (call.argument<String>("action")) {
                        "play" -> controls?.play()
                        "pause" -> controls?.pause()
                        "next" -> controls?.skipToNext()
                        "previous" -> controls?.skipToPrevious()
                    }
                    result.success(controls != null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasAccess(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            return activity.getSystemService(NotificationManager::class.java).isNotificationListenerAccessGranted(listener)
        }
        val enabled = Settings.Secure.getString(activity.contentResolver, "enabled_notification_listeners") ?: ""
        return enabled.split(':').any { ComponentName.unflattenFromString(it) == listener }
    }

    // The session to show: the one playing, else the most recent one.
    private fun controller(): MediaController? {
        if (!hasAccess()) return null
        val sessions = (activity.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager)
            .getActiveSessions(listener)
        return sessions.firstOrNull { it.playbackState?.state == PlaybackState.STATE_PLAYING } ?: sessions.firstOrNull()
    }

    private fun describe(controller: MediaController): Map<String, Any?> {
        val metadata = controller.metadata
        val art = metadata?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
            ?: metadata?.getBitmap(MediaMetadata.METADATA_KEY_ART)
        return mapOf(
            "title" to metadata?.getString(MediaMetadata.METADATA_KEY_TITLE),
            "artist" to (metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST)
                ?: metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)),
            "packageName" to controller.packageName,
            "playing" to (controller.playbackState?.state == PlaybackState.STATE_PLAYING),
            "art" to art?.let(::thumbnail),
        )
    }

    // Album art can be large; a 160px PNG is plenty for the tile.
    private fun thumbnail(bitmap: Bitmap): ByteArray {
        val scale = 160f / maxOf(bitmap.width, bitmap.height)
        val small = if (scale < 1f) {
            Bitmap.createScaledBitmap(bitmap, (bitmap.width * scale).toInt(), (bitmap.height * scale).toInt(), true)
        } else {
            bitmap
        }
        return ByteArrayOutputStream().also { small.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
    }
}
