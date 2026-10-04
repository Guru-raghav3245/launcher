import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The ongoing "Focus Mode" notification (Phase 12 task 3), shown in the
/// shade and on the lock screen while a session runs. Android keeps the time
/// itself (a chronometer counting down to the end, or up from the start),
/// and a timed one removes itself when the session ends, so nothing has to
/// run to keep it current. Since Android 14 it can still be swiped away.
class FocusSessionNotification {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Clear of Focus schedules' reminder ids (`index * 10 + weekday`).
  static const _id = 9000;

  /// Set by [FocusScheduleService.init] once the plugin is set up; until
  /// then (e.g. in tests) nothing is posted.
  static var ready = false;

  /// Posts (or replaces) the notification for a session that started at
  /// [startedAt] and, if timed, ends at [endsAt]. Asks for the notification
  /// permission first (Android 13+); without it, nothing is shown.
  static Future<void> show({required DateTime startedAt, DateTime? endsAt, bool strict = false}) async {
    if (!ready) return;
    final remaining = endsAt?.difference(DateTime.now());
    if (remaining != null && remaining <= Duration.zero) return;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (!(await android?.requestNotificationsPermission() ?? false)) return;
    await _plugin.show(
      id: _id,
      title: strict ? 'Strict Focus session' : 'Focus Mode',
      body: remaining == null
          ? 'Only your allowed apps open · stop it from the launcher'
          : 'Only your allowed apps open until it ends',
      payload: 'focus_session',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'focus_session',
          'Focus session',
          channelDescription: 'Shows a running Focus session, including on the lock screen',
          // Default rather than low importance, so it isn't treated as a
          // silent notification (which lock screens can hide); no sound,
          // vibration, or pop-up.
          importance: Importance.defaultImportance,
          playSound: false,
          enableVibration: false,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.status,
          when: (endsAt ?? startedAt).millisecondsSinceEpoch,
          usesChronometer: true,
          chronometerCountDown: remaining != null,
          timeoutAfter: remaining?.inMilliseconds,
        ),
      ),
    );
  }

  static Future<void> cancel() async {
    if (ready) await _plugin.cancel(id: _id);
  }
}
