import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../services/app_customizations_service.dart';
import '../services/mindful_break_service.dart';
import '../services/usage_stats_service.dart';
import '../state/app_settings.dart';
import '../state/app_settings_scope.dart';
import '../widgets/launch_app.dart';
import 'app_search.dart';

/// For the long-lived app lists (App Drawer, Spotlight Search): keeps the
/// user's [AppCustomizations] and the apps on a Mindful Break current
/// (re-read whenever either changes, and on resume so an expired break shows
/// its app again), and turns the cached installed-apps list into what the
/// user should see. Cheaper than reloading the apps, whose icons are heavy.
/// Also keeps each app's last use (30 days back, empty without usage access)
/// for recent apps and the unused-apps filter.
mixin ShowsVisibleApps<T extends StatefulWidget> on State<T> {
  AppCustomizations customizations = const AppCustomizations();
  Set<String> _onBreak = {};
  Map<String, DateTime> _lastUsed = {};
  late final _lifecycle = AppLifecycleListener(onResume: _load);

  @override
  void initState() {
    super.initState();
    _lifecycle;
    MindfulBreakService.changes.addListener(_load);
    AppCustomizationsService.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    MindfulBreakService.changes.removeListener(_load);
    AppCustomizationsService.changes.removeListener(_load);
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final (loaded, breaks, lastUsed) = await (
      const AppCustomizationsService().load(),
      const MindfulBreakService().breaks(),
      _loadLastUsed(),
    ).wait;
    if (!mounted) return;
    setState(() {
      customizations = loaded;
      _onBreak = breaks.keys.toSet();
      _lastUsed = lastUsed;
    });
  }

  static Future<Map<String, DateTime>> _loadLastUsed() async {
    const usage = UsageStatsService();
    try {
      if (!await usage.hasAccess()) return {};
      final now = DateTime.now();
      return await usage.lastUsed(start: now.subtract(const Duration(days: 30)), end: now);
    } catch (_) {
      return {}; // No usage channel (tests).
    }
  }

  /// The [count] most recently used of [apps], most recent first.
  List<AppInfo> recentApps(List<AppInfo> apps, {int count = 4}) =>
      (apps.where((a) => _lastUsed.containsKey(a.packageName)).toList()
            ..sort((a, b) => _lastUsed[b.packageName]!.compareTo(_lastUsed[a.packageName]!)))
          .take(count)
          .toList();

  /// [apps] with the recently used first (most recent first); the rest keep
  /// their order.
  List<AppInfo> byRecency(List<AppInfo> apps) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    return [...apps]..sort((a, b) => (_lastUsed[b.packageName] ?? epoch).compareTo(_lastUsed[a.packageName] ?? epoch));
  }

  /// Not opened in the last 30 days, and installed longer ago than that.
  /// Always false without usage data, so nothing is hidden by mistake.
  bool isUnused(AppInfo app) {
    if (_lastUsed.isEmpty || _lastUsed.containsKey(app.packageName)) return false;
    final installed = DateTime.fromMillisecondsSinceEpoch(app.installedTimestamp);
    return DateTime.now().difference(installed) > const Duration(days: 30);
  }

  /// [apps] renamed, minus hidden apps and apps on a break.
  List<AppInfo> visibleApps(List<AppInfo> apps) => [
    for (final app in customizations.apply(apps))
      if (!_onBreak.contains(app.packageName)) app,
  ];

  /// With the auto-open option on, a query that leaves exactly one app
  /// opens it (clearing the search and dropping the keyboard). Call from
  /// the search field's listener; [apps] is the loaded list, if any yet.
  void openIfSingleResult(TextEditingController search, List<AppInfo>? apps) {
    final query = search.text.trim();
    final settings = context.getInheritedWidgetOfExactType<AppSettingsScope>()?.notifier;
    if (apps == null || query.isEmpty || !(settings?.drawerOption(DrawerOption.autoOpenSingleResult) ?? false)) return;
    final results = filterAndSortApps(visibleApps(apps), query: query, sortMode: AppSortMode.alphabetical);
    if (results.length != 1) return;
    search.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    launchApp(context, results.single);
  }
}
