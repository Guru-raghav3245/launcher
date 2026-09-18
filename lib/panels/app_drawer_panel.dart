import 'package:flutter/material.dart';

import '../services/installed_apps_service.dart';

/// App Drawer panel: alphabetical installed-app list with search.
/// Built out in Phase 1 tasks 6-7; for now just proves the task 5 data
/// source (installed_apps platform channel) actually returns apps on-device.
class AppDrawerPanel extends StatefulWidget {
  const AppDrawerPanel({super.key});

  @override
  State<AppDrawerPanel> createState() => _AppDrawerPanelState();
}

class _AppDrawerPanelState extends State<AppDrawerPanel> {
  final _service = const InstalledAppsService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _service.loadApps(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Center(child: Text('App Drawer — ${snapshot.data!.length} apps found'));
      },
    );
  }
}
