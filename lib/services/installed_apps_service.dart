import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import 'focus_mode_service.dart';

/// Shared installed-app data source for the App Drawer and its search
/// (Phase 1 tasks 6-8), Home's dock, and every app picker.
class InstalledAppsService {
  const InstalledAppsService();

  /// Launchable apps (system or not — a launcher's drawer must include
  /// system apps like Phone/Camera), sorted alphabetically by name, each
  /// with its icon loaded. Loaded once and shared by every caller (icons are
  /// heavy: seconds on a low-end phone) until [invalidate].
  Future<List<AppInfo>> loadApps() async {
    final cached = _cache ??= _fetch()..ignore();
    try {
      return [...await cached];
    } catch (_) {
      if (identical(_cache, cached)) _cache = null; // Retry next time.
      rethrow;
    }
  }

  static Future<List<AppInfo>>? _cache;

  static Future<List<AppInfo>> _fetch() async {
    final apps = await InstalledApps.getInstalledApps(
      excludeSystemApps: false,
      excludeNonLaunchableApps: true,
      withIcon: true,
    );
    // This launcher never lists itself (it's always the one showing).
    return [for (final app in apps) if (app.packageName != ownPackage) app];
  }

  /// Bumped by [invalidate], so long-lived lists reload.
  static final changes = ValueNotifier(0);

  /// An app was installed, removed, or updated (MainActivity's package
  /// receiver): drop the cache and tell listeners.
  static void invalidate() {
    _cache = null;
    changes.value++;
  }

  /// This app's applicationId (android/app/build.gradle.kts).
  // ponytail: hardcoded; read it from the platform if the id ever changes.
  static const ownPackage = 'com.example.launcher';

  /// Opens Android's App info page for [packageName] (storage, permissions,
  /// uninstall, ...).
  Future<void> openAppInfo(String packageName) =>
      const MethodChannel('student.launcher/app').invokeMethod('openAppInfo', {'packageName': packageName});

  /// Opens the clock app (its alarms screen), for taps on Home's clock.
  Future<void> openClock() => const MethodChannel('student.launcher/app').invokeMethod('openClock');

  /// Launches [packageName], unless Focus Mode is active, in which case the
  /// launch is refused (returns false) and no app opens.
  Future<bool> launch(String packageName) async {
    if (await const FocusModeService().isBlocked(packageName)) return false;
    await InstalledApps.startApp(packageName);
    return true;
  }
}
