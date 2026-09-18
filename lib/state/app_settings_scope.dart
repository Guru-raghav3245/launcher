import 'package:flutter/widgets.dart';

import 'app_settings.dart';

/// Exposes the app-wide [AppSettings] to the widget tree, using Flutter's
/// built-in [InheritedNotifier] (no state-management dependency needed for
/// something this small).
class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({super.key, required AppSettings settings, required super.child})
      : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'No AppSettingsScope found in context');
    return scope!.notifier!;
  }
}
