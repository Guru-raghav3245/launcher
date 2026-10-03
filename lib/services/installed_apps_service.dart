import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import 'focus_mode_service.dart';

/// Shared installed-app data source for the App Drawer, drawer search, and
/// Spotlight Search (Phase 1 tasks 6-8) and Home's pinned-app dock.
class InstalledAppsService {
  const InstalledAppsService();

  /// Launchable apps (system or not — a launcher's drawer must include
  /// system apps like Phone/Camera), sorted alphabetically by name, each
  /// with its icon loaded.
  Future<List<AppInfo>> loadApps() {
    return InstalledApps.getInstalledApps(
      excludeSystemApps: false,
      excludeNonLaunchableApps: true,
      withIcon: true,
    );
  }

  /// Opens Android's App info page for [packageName] (storage, permissions,
  /// uninstall, ...).
  Future<void> openAppInfo(String packageName) =>
      const MethodChannel('yinyang.launcher/app').invokeMethod('openAppInfo', {'packageName': packageName});

  /// Opens the clock app (its alarms screen), for taps on Home's clock.
  Future<void> openClock() => const MethodChannel('yinyang.launcher/app').invokeMethod('openClock');

  /// Launches [packageName], unless Focus Mode is active, in which case the
  /// launch is refused (returns false) and no app opens.
  Future<bool> launch(String packageName) async {
    if (await const FocusModeService().isBlocked(packageName)) return false;
    await InstalledApps.startApp(packageName);
    return true;
  }
}
