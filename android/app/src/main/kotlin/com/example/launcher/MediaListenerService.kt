package com.example.launcher

import android.service.notification.NotificationListenerService

/// The Music tile's notification access (Phase 9 task 6), like the original's
/// MusicNotificationListenerService. It handles no notifications itself:
/// being an enabled listener is what lets MediaSessionManager list the
/// active media sessions (what's playing, and its play/pause/skip controls).
class MediaListenerService : NotificationListenerService()
