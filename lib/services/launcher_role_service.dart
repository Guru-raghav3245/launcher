import 'package:flutter/services.dart';

/// Requests the Android default-launcher (ROLE_HOME) role via the native
/// RoleManager dialog. No Flutter plugin wraps this start-for-result flow,
/// so this talks to a small MethodChannel implemented in MainActivity.kt.
class LauncherRoleService {
  const LauncherRoleService();

  static const _channel = MethodChannel('student.launcher/role');

  /// true = granted, false = user cancelled the dialog, null = this
  /// Android version has no ROLE_HOME (opened Settings instead, no result).
  Future<bool?> requestHomeRole() async {
    try {
      return await _channel.invokeMethod<bool>('requestHomeRole');
    } on PlatformException {
      return null;
    }
  }

  /// Whether this app is currently the default HOME app.
  Future<bool> isDefaultLauncher() async => (await _channel.invokeMethod<bool>('isDefaultLauncher')) ?? false;

  /// Opens the system Home-app picker (fire-and-forget, no result) so the
  /// user can switch default launcher in either direction.
  Future<void> openHomeSettings() => _channel.invokeMethod('openHomeSettings');

  /// Home's dock defaults in slot order: dialer, SMS, browser, camera (null
  /// where there's no default).
  Future<List<String?>> defaultDockPackages() async =>
      (await _channel.invokeListMethod<String?>('defaultDockPackages')) ?? const [null, null, null, null];

  /// The default dialer and SMS app packages (either may be missing).
  Future<List<String>> defaultCommsPackages() async =>
      (await _channel.invokeListMethod<String>('defaultCommsPackages')) ?? const [];
}
