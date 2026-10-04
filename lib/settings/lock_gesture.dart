import 'package:flutter/material.dart';

import '../services/gestures_service.dart';
import '../state/app_settings.dart';

/// Gets double-tap-to-lock's permission in place, as the original does:
/// for accessibility, an explainer first (what the service does and
/// doesn't do) and then Android's Accessibility settings, where the user
/// switches it on; for device admin, Android's own activation screen.
Future<void> setUpLock(BuildContext context, DoubleTapAction method) async {
  const gestures = GesturesService();
  switch (method) {
    case DoubleTapAction.lockAccessibility:
      if (await gestures.accessibilityLockReady() || !context.mounted) return;
      final allow = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Accessibility service'),
          content: const Text(
            "Double tap to lock uses Android's Accessibility Service. It only sends the lock-screen action: no "
            'screen content, text, notifications, or other personal data is read, collected, or shared. You can '
            'turn it off anytime in Android Settings.\n\nOn the next screen, choose "Student Launcher double tap to lock" '
            'and switch it on.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Allow')),
          ],
        ),
      );
      if (allow == true) await gestures.openAccessibilitySettings();
    case DoubleTapAction.lockDeviceAdmin:
      if (!await gestures.deviceAdminReady()) await gestures.requestDeviceAdmin();
    case DoubleTapAction.none:
  }
}

/// Home's double tap: locks with [method], or walks through [setUpLock] if
/// its permission isn't in place (yet, or any more).
Future<void> lockScreen(BuildContext context, DoubleTapAction method) async {
  const gestures = GesturesService();
  final locked = switch (method) {
    DoubleTapAction.lockAccessibility => await gestures.lockWithAccessibility(),
    DoubleTapAction.lockDeviceAdmin => await gestures.lockWithDeviceAdmin(),
    DoubleTapAction.none => true,
  };
  if (!locked && context.mounted) await setUpLock(context, method);
}
