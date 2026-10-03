import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../services/app_customizations_service.dart';
import '../services/mindful_break_service.dart';

/// For the long-lived app lists (App Drawer, Spotlight Search): keeps the
/// user's [AppCustomizations] and the apps on a Mindful Break current
/// (re-read whenever either changes, and on resume so an expired break shows
/// its app again), and turns the cached installed-apps list into what the
/// user should see. Cheaper than reloading the apps, whose icons are heavy.
mixin ShowsVisibleApps<T extends StatefulWidget> on State<T> {
  AppCustomizations customizations = const AppCustomizations();
  Set<String> _onBreak = {};
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
    final (loaded, breaks) = await (const AppCustomizationsService().load(), const MindfulBreakService().breaks()).wait;
    if (!mounted) return;
    setState(() {
      customizations = loaded;
      _onBreak = breaks.keys.toSet();
    });
  }

  /// [apps] renamed, minus hidden apps and apps on a break.
  List<AppInfo> visibleApps(List<AppInfo> apps) => [
    for (final app in customizations.apply(apps))
      if (!_onBreak.contains(app.packageName)) app,
  ];
}
