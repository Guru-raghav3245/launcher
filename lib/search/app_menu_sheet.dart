import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../services/app_customizations_service.dart';
import '../services/installed_apps_service.dart';
import '../widgets/launch_app.dart';
import 'app_result_row.dart';

/// The App Drawer's long-press menu for [app]: Open, Rename, Pin/Unpin,
/// Hide, App info. Changes go through [AppCustomizationsService], whose
/// change notifier refreshes the drawer and Spotlight.
Future<void> showAppMenu(BuildContext context, AppInfo app, {required bool pinned}) async {
  const customizations = AppCustomizationsService();
  final messenger = ScaffoldMessenger.of(context);
  final action = await showModalBottomSheet<_AppAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: AppIcon(icon: app.icon),
              title: Text(app.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            for (final (action, icon, label) in [
              (_AppAction.open, Icons.open_in_new, 'Open'),
              (_AppAction.rename, Icons.edit_outlined, 'Rename'),
              (_AppAction.pin, pinned ? Icons.star : Icons.star_border, pinned ? 'Unpin' : 'Pin to top'),
              (_AppAction.hide, Icons.visibility_off_outlined, 'Hide'),
              (_AppAction.info, Icons.info_outline, 'App info'),
            ])
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: Icon(icon),
                title: Text(label),
                onTap: () => Navigator.of(context).pop(action),
              ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted) return;
  switch (action) {
    case _AppAction.open:
      await launchApp(context, app);
    case _AppAction.rename:
      final name = await _askName(context, app.name);
      if (name != null) await customizations.rename(app.packageName, name);
    case _AppAction.pin:
      await customizations.setPinned(app.packageName, !pinned);
    case _AppAction.hide:
      await customizations.setHidden(app.packageName, true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${app.name} is hidden'),
            action: SnackBarAction(label: 'Undo', onPressed: () => customizations.setHidden(app.packageName, false)),
          ),
        );
    case _AppAction.info:
      await const InstalledAppsService().openAppInfo(app.packageName);
    case null:
  }
}

enum _AppAction { open, rename, pin, hide, info }

/// Resolves to the new name ('' restores the app's own name), or null on
/// Cancel. The controller isn't disposed: the dialog's exit animation still
/// reads it after this resolves, and it holds nothing but listeners.
Future<String?> _askName(BuildContext context, String current) {
  final controller = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rename'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(helperText: "Leave empty to use the app's own name"),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Save')),
      ],
    ),
  );
}
