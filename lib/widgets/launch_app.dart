import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../services/installed_apps_service.dart';

/// Launches [app] from any UI call site, explaining with a SnackBar when
/// Focus Mode refuses it (otherwise a blocked tap would silently do nothing).
Future<void> launchApp(BuildContext context, AppInfo app) async {
  final messenger = ScaffoldMessenger.of(context);
  if (await const InstalledAppsService().launch(app.packageName)) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text("Focus Mode is on · ${app.name} isn't an essential app")));
}
