import 'package:shared_preferences/shared_preferences.dart';

/// A Focus Mode session: active with an optional end time (null means
/// indefinite, stopped manually via [FocusModeService.stop]).
class FocusStatus {
  const FocusStatus({required this.active, this.endsAt});

  final bool active;
  final DateTime? endsAt;

  Duration? get remaining => endsAt?.difference(DateTime.now());
}

/// Persists and enforces the single Focus Mode session shared by the Mind
/// Space quick actions (Phase 4 task 6: Pause/Timer/Focus Mode all start or
/// stop this same session) and Settings' Focus Mode toggle (Phase 5).
/// [InstalledAppsService.launch] consults [isBlocked] before opening an app.
class FocusModeService {
  const FocusModeService();

  static const _activeKey = 'focus_mode_active';
  static const _endsAtKey = 'focus_mode_ends_at';

  Future<FocusStatus> status() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_activeKey) ?? false)) return const FocusStatus(active: false);
    final endsAtMillis = prefs.getInt(_endsAtKey);
    if (endsAtMillis == null) return const FocusStatus(active: true);
    final endsAt = DateTime.fromMillisecondsSinceEpoch(endsAtMillis);
    if (DateTime.now().isAfter(endsAt)) {
      await stop();
      return const FocusStatus(active: false);
    }
    return FocusStatus(active: true, endsAt: endsAt);
  }

  /// Starts a session. [duration] null means indefinite (stopped via [stop]).
  Future<void> start({Duration? duration}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activeKey, true);
    if (duration == null) {
      await prefs.remove(_endsAtKey);
    } else {
      await prefs.setInt(_endsAtKey, DateTime.now().add(duration).millisecondsSinceEpoch);
    }
  }

  Future<void> stop() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activeKey, false);
    await prefs.remove(_endsAtKey);
  }

  // ponytail: blocks every app with no exceptions; add an essential-apps
  // allowlist once Phase 5's Settings screen has somewhere to configure one.
  Future<bool> isBlocked(String packageName) async => (await status()).active;
}
