import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:installed_apps/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'installed_apps_service.dart';

/// The user's per-app tweaks: pinned apps (in pin order), hidden apps, and
/// custom names.
class AppCustomizations {
  const AppCustomizations({this.pinned = const [], this.hidden = const {}, this.renames = const {}});

  final List<String> pinned;
  final Set<String> hidden;
  final Map<String, String> renames;

  /// [apps] with custom names applied and (unless [includeHidden]) hidden
  /// apps removed, re-sorted by the name the user sees.
  List<AppInfo> apply(List<AppInfo> apps, {bool includeHidden = false}) {
    final result = [
      for (final app in apps)
        if (includeHidden || !hidden.contains(app.packageName))
          switch (renames[app.packageName]) {
            final name? => AppInfo(
              name: name,
              icon: app.icon,
              packageName: app.packageName,
              versionName: app.versionName,
              versionCode: app.versionCode,
              platformType: app.platformType,
              installedTimestamp: app.installedTimestamp,
              isSystemApp: app.isSystemApp,
              isLaunchableApp: app.isLaunchableApp,
              category: app.category,
            ),
            null => app,
          },
    ];
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }
}

/// Persists [AppCustomizations]. Every write bumps [changes], so the App
/// Drawer re-applies them without reloading app icons.
class AppCustomizationsService {
  const AppCustomizationsService();

  static const _pinnedKey = 'apps_pinned';
  static const _hiddenKey = 'apps_hidden';
  static const _renamesKey = 'apps_renames';

  static final changes = ValueNotifier<int>(0);

  Future<AppCustomizations> load() async {
    final prefs = await SharedPreferences.getInstance();
    final renames = prefs.getString(_renamesKey);
    return AppCustomizations(
      pinned: prefs.getStringList(_pinnedKey) ?? const [],
      hidden: (prefs.getStringList(_hiddenKey) ?? const []).toSet(),
      renames: renames == null ? const {} : (jsonDecode(renames) as Map<String, dynamic>).cast<String, String>(),
    );
  }

  /// Pinning appends to the end of the pinned order; unpinning removes.
  Future<void> setPinned(String packageName, bool pinned) async {
    final current = [...(await load()).pinned]..remove(packageName);
    if (pinned) current.add(packageName);
    await _write((prefs) => prefs.setStringList(_pinnedKey, current));
  }

  Future<void> setHidden(String packageName, bool hidden) async {
    final current = {...(await load()).hidden};
    hidden ? current.add(packageName) : current.remove(packageName);
    await _write((prefs) => prefs.setStringList(_hiddenKey, current.toList()));
  }

  /// A null or blank [name] restores the app's own name.
  Future<void> rename(String packageName, String? name) async {
    final current = {...(await load()).renames};
    final trimmed = name?.trim() ?? '';
    trimmed.isEmpty ? current.remove(packageName) : current[packageName] = trimmed;
    await _write((prefs) => prefs.setString(_renamesKey, jsonEncode(current)));
  }

  Future<void> _write(Future<bool> Function(SharedPreferences prefs) write) async {
    await write(await SharedPreferences.getInstance());
    changes.value++;
  }
}

/// Installed apps as the user sees them: renamed, and without hidden apps
/// unless [includeHidden]. The one-shot loader for pickers; long-lived lists
/// (the App Drawer) apply [AppCustomizations] to a cached list instead.
Future<List<AppInfo>> loadCustomizedApps({bool includeHidden = false}) async {
  final (apps, customizations) = await (
    const InstalledAppsService().loadApps(),
    const AppCustomizationsService().load(),
  ).wait;
  return customizations.apply(apps, includeHidden: includeHidden);
}
