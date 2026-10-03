import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'launcher_role_service.dart';

/// The line glyphs the dock's default slots are drawn with, in slot order.
enum DockGlyph { phone, messages, browser, camera }

/// One of Home's four dock slots: an app (null = empty), and the glyph it's
/// drawn with while it still holds its default app (null = the app's icon).
typedef DockSlot = ({String? packageName, DockGlyph? glyph});

/// Persists Home's four dock slots (`home_dock`). The first read seeds them
/// with the default dialer, SMS, browser, and camera apps, each keeping its
/// glyph; once stored (even changed) they're never re-seeded.
class DockService {
  const DockService();

  static const _key = 'home_dock';
  static const slotCount = 4;

  /// Bumped on every change so Home redraws the dock.
  static final changes = ValueNotifier<int>(0);

  Future<List<DockSlot>> slots() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      return [
        for (final s in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
          (
            packageName: s['package'] as String?,
            glyph: s['glyph'] == null ? null : DockGlyph.values.byName(s['glyph'] as String),
          ),
      ];
    }
    final defaults = await _defaults();
    final seeded = [
      for (var i = 0; i < slotCount; i++)
        (packageName: defaults[i], glyph: defaults[i] == null ? null : DockGlyph.values[i]),
    ];
    await _save(seeded, notify: false);
    return seeded;
  }

  /// Puts [packageName] in [index]; it shows that app's own icon.
  Future<void> setSlot(int index, String packageName) async {
    final current = await slots();
    current[index] = (packageName: packageName, glyph: null);
    await _save(current);
  }

  Future<List<String?>> _defaults() async {
    try {
      final found = await const LauncherRoleService().defaultDockPackages();
      return [for (var i = 0; i < slotCount; i++) i < found.length ? found[i] : null];
    } catch (_) {
      return List.filled(slotCount, null); // No platform channel (tests): start empty.
    }
  }

  Future<void> _save(List<DockSlot> slots, {bool notify = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([
        for (final s in slots) {'package': s.packageName, 'glyph': s.glyph?.name},
      ]),
    );
    if (notify) changes.value++;
  }
}
