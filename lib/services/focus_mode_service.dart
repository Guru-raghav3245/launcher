import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'launcher_role_service.dart';

/// A Focus Mode session: active with an optional end time (null means
/// indefinite, stopped manually via [FocusModeService.stop]). [startedAt]
/// drives the session screen's elapsed timer; it's null for sessions saved
/// before it was recorded.
class FocusStatus {
  const FocusStatus({required this.active, this.startedAt, this.endsAt});

  final bool active;
  final DateTime? startedAt;
  final DateTime? endsAt;

  Duration? get remaining => endsAt?.difference(DateTime.now());
}

/// Persists and enforces the single Focus Mode session shared by the Mind
/// Space quick actions (Phase 4 task 6: Pause/Timer/Focus Mode all start or
/// stop this same session) and Settings' Focus Mode toggle (Phase 5).
/// [InstalledAppsService.launch] consults [isBlocked] before opening an app;
/// apps in [essentials] are never blocked.
class FocusModeService {
  const FocusModeService();

  static const _activeKey = 'focus_mode_active';
  static const _endsAtKey = 'focus_mode_ends_at';
  static const _startedAtKey = 'focus_mode_started_at';
  static const _essentialsKey = 'focus_mode_essentials';

  /// Fires after every [start]/[stop], so each on-screen copy of the quick
  /// actions (Mind Space panel, Settings sheet) can re-read [status].
  static final changes = ValueNotifier<int>(0);

  Future<FocusStatus> status() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_activeKey) ?? false)) return const FocusStatus(active: false);
    final startedAtMillis = prefs.getInt(_startedAtKey);
    final startedAt = startedAtMillis == null ? null : DateTime.fromMillisecondsSinceEpoch(startedAtMillis);
    final endsAtMillis = prefs.getInt(_endsAtKey);
    if (endsAtMillis == null) return FocusStatus(active: true, startedAt: startedAt);
    final endsAt = DateTime.fromMillisecondsSinceEpoch(endsAtMillis);
    if (DateTime.now().isAfter(endsAt)) {
      await stop();
      return const FocusStatus(active: false);
    }
    return FocusStatus(active: true, startedAt: startedAt, endsAt: endsAt);
  }

  /// Starts a session. [duration] null means indefinite (stopped via [stop]).
  Future<void> start({Duration? duration}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activeKey, true);
    await prefs.setInt(_startedAtKey, DateTime.now().millisecondsSinceEpoch);
    if (duration == null) {
      await prefs.remove(_endsAtKey);
    } else {
      await prefs.setInt(_endsAtKey, DateTime.now().add(duration).millisecondsSinceEpoch);
    }
    changes.value++;
  }

  Future<void> stop() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activeKey, false);
    await prefs.remove(_endsAtKey);
    await prefs.remove(_startedAtKey);
    changes.value++;
  }

  /// Package names that stay launchable during a session. On first use it
  /// is seeded with the default dialer and SMS apps, like the original
  /// launcher; once the list has been written (even emptied) it's never
  /// re-seeded, so the user's removals stick.
  Future<Set<String>> essentials() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_essentialsKey);
    if (stored != null) return stored.toSet();
    final defaults = await _defaultEssentials();
    await prefs.setStringList(_essentialsKey, defaults);
    return defaults.toSet();
  }

  Future<List<String>> _defaultEssentials() async {
    try {
      return await const LauncherRoleService().defaultCommsPackages();
    } catch (_) {
      // No platform channel (tests, non-Android): start empty.
      return const [];
    }
  }

  Future<void> setEssential(String packageName, bool essential) async {
    final current = await essentials();
    if (essential) {
      current.add(packageName);
    } else {
      current.remove(packageName);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_essentialsKey, current.toList());
  }

  Future<bool> isBlocked(String packageName) async =>
      (await status()).active && !(await essentials()).contains(packageName);
}
