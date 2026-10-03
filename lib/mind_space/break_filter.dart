import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../services/mindful_break_service.dart';

/// For the App Drawer and Spotlight Search: keeps the set of apps on a
/// Mindful Break current (re-read on every break change and on resume, so
/// an expired break shows its app again) and filters them out of a list.
mixin HidesAppsOnBreak<T extends StatefulWidget> on State<T> {
  Set<String> _onBreak = {};
  late final _lifecycle = AppLifecycleListener(onResume: _loadBreaks);

  @override
  void initState() {
    super.initState();
    _lifecycle;
    MindfulBreakService.changes.addListener(_loadBreaks);
    _loadBreaks();
  }

  @override
  void dispose() {
    MindfulBreakService.changes.removeListener(_loadBreaks);
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _loadBreaks() async {
    final onBreak = (await const MindfulBreakService().breaks()).keys.toSet();
    if (mounted) setState(() => _onBreak = onBreak);
  }

  List<AppInfo> withoutAppsOnBreak(List<AppInfo> apps) => [
    for (final app in apps)
      if (!_onBreak.contains(app.packageName)) app,
  ];
}
