import 'package:flutter/services.dart';

/// Requests the Android default-launcher (ROLE_HOME) role via the native
/// RoleManager dialog. No Flutter plugin wraps this start-for-result flow,
/// so this talks to a small MethodChannel implemented in MainActivity.kt.
class LauncherRoleService {
  const LauncherRoleService();

  static const _channel = MethodChannel('yinyang.launcher/role');

  /// true = granted, false = user cancelled the dialog, null = this
  /// Android version has no ROLE_HOME (opened Settings instead, no result).
  Future<bool?> requestHomeRole() async {
    try {
      return await _channel.invokeMethod<bool>('requestHomeRole');
    } on PlatformException {
      return null;
    }
  }
}
