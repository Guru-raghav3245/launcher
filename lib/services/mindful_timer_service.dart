import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A named set of apps sharing one daily time budget, with an optional
/// cooldown between sessions.
class TimerGroup {
  const TimerGroup({
    required this.id,
    required this.name,
    required this.packages,
    required this.dailyMinutes,
    this.cooldownMinutes = 0,
  });

  final String id;
  final String name;
  final Set<String> packages;
  final int dailyMinutes;
  final int cooldownMinutes;

  factory TimerGroup.fromJson(Map<String, dynamic> json) => TimerGroup(
    id: json['id'] as String,
    name: json['name'] as String,
    packages: (json['packages'] as List).cast<String>().toSet(),
    dailyMinutes: json['dailyMinutes'] as int,
    cooldownMinutes: json['cooldownMinutes'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'packages': packages.toList(),
    'dailyMinutes': dailyMinutes,
    'cooldownMinutes': cooldownMinutes,
  };
}

/// Why a timed app can't open right now, or null if it can.
sealed class TimerBlock {
  const TimerBlock();
}

class BudgetSpent extends TimerBlock {
  const BudgetSpent();
}

class CoolingDown extends TimerBlock {
  const CoolingDown(this.until);
  final DateTime until;
}

/// Persists Mindful Timer groups plus today's session log (session count and
/// last session end per group, for "Session N" and cooldowns). Time used is
/// not stored: callers pass today's foreground time from usage events.
class MindfulTimerService {
  const MindfulTimerService();

  static const _groupsKey = 'mindful_timer_groups';
  static const _logKey = 'mindful_timer_log';
  static const _channel = MethodChannel('yinyang.launcher/timer');

  Future<List<TimerGroup>> groups() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_groupsKey);
    if (raw == null) return [];
    return [for (final g in jsonDecode(raw) as List) TimerGroup.fromJson(g as Map<String, dynamic>)];
  }

  Future<void> saveGroup(TimerGroup group) async {
    final all = await groups();
    final i = all.indexWhere((g) => g.id == group.id);
    if (i == -1) {
      all.add(group);
    } else {
      all[i] = group;
    }
    await _saveGroups(all);
  }

  Future<void> deleteGroup(String id) async => _saveGroups((await groups())..removeWhere((g) => g.id == id));

  Future<void> _saveGroups(List<TimerGroup> all) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_groupsKey, jsonEncode([for (final g in all) g.toJson()]));
  }

  /// The group timing [packageName], if any (first match wins).
  Future<TimerGroup?> groupFor(String packageName) async {
    for (final g in await groups()) {
      if (g.packages.contains(packageName)) return g;
    }
    return null;
  }

  /// Sessions started today in [group].
  Future<int> sessionsToday(TimerGroup group, DateTime now) async =>
      ((await _log(now))['sessions'] as Map)[group.id] as int? ?? 0;

  Future<TimerBlock?> blockFor(TimerGroup group, Duration usedToday, DateTime now) async {
    if (usedToday.inMinutes >= group.dailyMinutes) return const BudgetSpent();
    if (group.cooldownMinutes == 0) return null;
    final lastEnd = ((await _log(now))['lastEnd'] as Map)[group.id] as int?;
    if (lastEnd == null) return null;
    final until = DateTime.fromMillisecondsSinceEpoch(lastEnd).add(Duration(minutes: group.cooldownMinutes));
    return until.isAfter(now) ? CoolingDown(until) : null;
  }

  /// Logs a session and asks the native side to show the "Time's up" overlay
  /// if [packageName] is still in front when it ends.
  Future<void> startSession(TimerGroup group, String packageName, String appName, int minutes, DateTime now) async {
    final log = await _log(now);
    final sessions = log['sessions'] as Map;
    sessions[group.id] = (sessions[group.id] as int? ?? 0) + 1;
    (log['lastEnd'] as Map)[group.id] = now.add(Duration(minutes: minutes)).millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_logKey, jsonEncode(log));
    try {
      await _channel.invokeMethod('startSession', {'packageName': packageName, 'appName': appName, 'minutes': minutes});
    } on MissingPluginException {
      // Tests: no native timer.
    }
  }

  Future<bool> canDrawOverlays() async {
    try {
      return await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
    } on MissingPluginException {
      return true;
    }
  }

  Future<void> requestOverlay() => _channel.invokeMethod('requestOverlay');

  /// Today's log, reset when the date changes.
  // ponytail: a cooldown running past midnight ends at midnight with the log.
  Future<Map<String, dynamic>> _log(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final today = '${now.year}-${now.month}-${now.day}';
    final raw = prefs.getString(_logKey);
    final log = raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    if (log == null || log['date'] != today) {
      return {'date': today, 'sessions': <String, dynamic>{}, 'lastEnd': <String, dynamic>{}};
    }
    return log;
  }
}
