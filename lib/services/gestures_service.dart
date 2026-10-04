import 'package:flutter/services.dart';

/// Talks to `GesturesBridge.kt` for Home's configurable gestures: opening
/// the notification shade, and locking the screen through the lock-only
/// accessibility service or device admin.
class GesturesService {
  const GesturesService();

  static const _channel = MethodChannel('student.launcher/gestures');

  Future<bool> expandNotifications() async => await _channel.invokeMethod<bool>('expandNotifications') ?? false;

  /// Whether the user has switched the lock-only accessibility service on.
  Future<bool> accessibilityLockReady() async => await _channel.invokeMethod<bool>('accessibilityLockReady') ?? false;

  Future<void> openAccessibilitySettings() => _channel.invokeMethod('openAccessibilitySettings');

  Future<bool> lockWithAccessibility() async => await _channel.invokeMethod<bool>('lockWithAccessibility') ?? false;

  Future<bool> deviceAdminReady() async => await _channel.invokeMethod<bool>('deviceAdminReady') ?? false;

  /// Opens Android's "activate device admin" screen (no result reported).
  Future<void> requestDeviceAdmin() => _channel.invokeMethod('requestDeviceAdmin');

  Future<bool> lockWithDeviceAdmin() async => await _channel.invokeMethod<bool>('lockWithDeviceAdmin') ?? false;
}
