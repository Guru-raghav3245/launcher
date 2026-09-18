import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

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

  Future<void> launch(String packageName) async {
    await InstalledApps.startApp(packageName);
  }
}
