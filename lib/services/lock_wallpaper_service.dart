import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/wallpaper.dart';
import '../state/app_settings.dart';

/// Keeps the lock screen wallpaper matching Home's (Phase 12 task 4): when
/// [AppSettings.lockWallpaperSync] is on, the current theme's wallpaper is
/// painted at the screen's size, exactly as Home paints it, and set as the
/// lock screen wallpaper only (MainActivity's `setLockWallpaper`). Turning it
/// off clears the lock wallpaper, so the phone's own shows there again
/// (apps can't read back what was there before).
class LockWallpaperService {
  static const _channel = MethodChannel('student.launcher/app');

  /// The wallpaper id last set on the lock screen, or absent if none (or it
  /// was cleared), so nothing is rewritten when nothing changed.
  static const _appliedKey = 'lock_wallpaper_applied';

  static Timer? _timer;

  /// True while the Appearance editor is open: picks there are previews
  /// until Save or Cancel, which [schedule] again on closing.
  static var paused = false;

  /// Applies [settings]' wanted lock wallpaper a moment from now, so a run
  /// of changes (a theme flip, Cancel restoring several settings) writes once.
  static void schedule(AppSettings settings) {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 1), () {
      if (!paused) sync(settings.lockWallpaperSync ? settings.wallpaper : null);
    });
  }

  /// Sets [wallpaper] on the lock screen, or clears ours if null.
  static Future<void> sync(Wallpaper? wallpaper) async {
    final prefs = await SharedPreferences.getInstance();
    final applied = prefs.getString(_appliedKey);
    if (wallpaper?.id == applied) return;
    try {
      if (wallpaper == null) {
        await _channel.invokeMethod('clearLockWallpaper');
        await prefs.remove(_appliedKey);
      } else {
        await _channel.invokeMethod('setLockWallpaper', {'png': await render(wallpaper, _screenSize())});
        await prefs.setString(_appliedKey, wallpaper.id);
      }
    } on PlatformException {
      // The system refused (e.g. a managed device): leave it as it was.
    } on MissingPluginException {
      // No platform channel (tests).
    }
  }

  /// The display's size in physical pixels: the lock screen fills it.
  static ui.Size _screenSize() {
    final display = ui.PlatformDispatcher.instance.displays.first;
    return display.size;
  }

  /// [wallpaper]'s gradient over a [size] canvas, as a PNG.
  static Future<Uint8List> render(Wallpaper wallpaper, ui.Size size) async {
    final recorder = ui.PictureRecorder();
    final rect = ui.Offset.zero & size;
    ui.Canvas(recorder).drawRect(rect, ui.Paint()..shader = wallpaper.gradient.createShader(rect));
    final image = await recorder.endRecording().toImage(size.width.round(), size.height.round());
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return png!.buffer.asUint8List();
  }
}
