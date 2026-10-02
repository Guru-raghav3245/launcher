import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../mind_space/mindful_pause_overlay.dart';
import '../services/focus_mode_service.dart';
import '../services/installed_apps_service.dart';
import '../services/mindful_pause_service.dart';

/// Launches [app] from any UI call site. A Mindful Pause app first gets its
/// breathing screen (skipping it cancels the launch); a launch Focus Mode
/// refuses is explained with a SnackBar instead of silently doing nothing.
Future<void> launchApp(BuildContext context, AppInfo app) async {
  final messenger = ScaffoldMessenger.of(context);
  // No pause for an app Focus Mode is about to refuse anyway.
  if (!await const FocusModeService().isBlocked(app.packageName)) {
    const pause = MindfulPauseService();
    if (await pause.isPaused(app.packageName)) {
      final seconds = await pause.seconds();
      if (!context.mounted || !await showMindfulPause(context, app, seconds)) return;
    }
  }
  if (await const InstalledAppsService().launch(app.packageName)) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text("Focus Mode is on · ${app.name} isn't an essential app")));
}
