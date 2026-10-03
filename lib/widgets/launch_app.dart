import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../mind_space/mindful_pause_overlay.dart';
import '../mind_space/timer_session_sheet.dart';
import '../services/focus_mode_service.dart';
import '../services/installed_apps_service.dart';
import '../services/mindful_pause_service.dart';
import '../services/mindful_timer_service.dart';

/// Launches [app] from any UI call site. A Mindful Pause app first gets its
/// breathing screen (skipping it cancels the launch); a Mindful Timer app
/// then asks for a session length (or is refused once its group's budget or
/// cooldown says no); a launch Focus Mode refuses is explained with a
/// SnackBar instead of silently doing nothing.
Future<void> launchApp(BuildContext context, AppInfo app) async {
  final messenger = ScaffoldMessenger.of(context);
  void explain(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  // No pause or timer for an app Focus Mode is about to refuse anyway.
  if (!await const FocusModeService().isBlocked(app.packageName)) {
    const pause = MindfulPauseService();
    if (await pause.isPaused(app.packageName)) {
      final seconds = await pause.seconds();
      if (!context.mounted || !await showMindfulPause(context, app, seconds)) return;
    }

    const timer = MindfulTimerService();
    final group = await timer.groupFor(app.packageName);
    if (group != null) {
      final now = DateTime.now();
      final used = await groupUsageToday(group, now);
      switch (await timer.blockFor(group, used, now)) {
        case BudgetSpent():
          return explain("${group.name} · today's ${group.dailyMinutes} min are used up");
        case CoolingDown(:final until):
          if (!context.mounted) return;
          return explain('${group.name} · cooling down until ${TimeOfDay.fromDateTime(until).format(context)}');
        case null:
      }
      final sessions = await timer.sessionsToday(group, now);
      if (!context.mounted) return;
      final minutes = await showTimerSessionSheet(
        context,
        app: app,
        group: group,
        usedToday: used,
        sessionsToday: sessions,
      );
      if (minutes == null) return;
      await timer.startSession(group, app.packageName, app.name, minutes, DateTime.now());
    }
  }
  if (await const InstalledAppsService().launch(app.packageName)) return;
  explain("Focus Mode is on · ${app.name} isn't an allowed app");
}
