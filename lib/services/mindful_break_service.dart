import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists Mindful Break: apps put away until a set time. An app on break
/// is hidden from the App Drawer and Spotlight Search, and `launchApp`
/// refuses it with a block screen until the break ends.
class MindfulBreakService {
  const MindfulBreakService();

  static const _key = 'mindful_break_apps';
  static const lengthsInDays = [1, 3, 7, 30];

  /// Bumped on every start/end so the drawer and Spotlight re-filter.
  static final changes = ValueNotifier<int>(0);

  /// Apps currently on break, with when each break ends. Expired breaks are
  /// left out (and dropped from storage on the next write).
  Future<Map<String, DateTime>> breaks({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final at = now ?? DateTime.now();
    return {
      for (final MapEntry(:key, :value) in (jsonDecode(raw) as Map<String, dynamic>).entries)
        if (DateTime.fromMillisecondsSinceEpoch(value as int).isAfter(at))
          key: DateTime.fromMillisecondsSinceEpoch(value),
    };
  }

  Future<DateTime?> endsAt(String packageName, {DateTime? now}) async => (await breaks(now: now))[packageName];

  Future<void> start(String packageName, int days, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    await _save((await breaks(now: at))..[packageName] = at.add(Duration(days: days)));
  }

  Future<void> end(String packageName) async => _save((await breaks())..remove(packageName));

  Future<void> _save(Map<String, DateTime> breaks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode({for (final e in breaks.entries) e.key: e.value.millisecondsSinceEpoch}));
    changes.value++;
  }
}
