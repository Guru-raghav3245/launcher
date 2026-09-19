import 'package:flutter/services.dart';

/// The Mind Space events derived so far: an app coming to the foreground or
/// background, or the keyguard being dismissed (used to detect "what's
/// opened right after unlock" in Phase 4 task 5). Other `UsageEvents` types
/// are filtered out natively — see `UsageStatsBridge.kt`.
enum UsageEventType { foreground, background, unlocked }

class UsageEvent {
  const UsageEvent({required this.packageName, required this.type, required this.timestamp});

  final String packageName;
  final UsageEventType type;
  final DateTime timestamp;
}

/// Bridges to Android's UsageStatsManager for Mind Space (Phase 4). Reading
/// usage stats needs the PACKAGE_USAGE_STATS special permission, which the
/// user grants via Settings — there's no runtime dialog, so [hasAccess]
/// should be re-checked whenever the app resumes rather than assumed after
/// [requestAccess] returns.
class UsageStatsService {
  const UsageStatsService();

  static const _channel = MethodChannel('yinyang.launcher/usage');

  Future<bool> hasAccess() async => (await _channel.invokeMethod<bool>('hasAccess')) ?? false;

  Future<void> requestAccess() => _channel.invokeMethod('requestAccess');

  Future<List<UsageEvent>> queryEvents({required DateTime start, required DateTime end}) async {
    final result = await _channel.invokeMethod<List<Object?>>('queryEvents', {
      'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
    });
    return [
      for (final entry in (result ?? []).cast<Map<Object?, Object?>>())
        UsageEvent(
          packageName: entry['packageName'] as String,
          type: UsageEventType.values.byName(entry['type'] as String),
          timestamp: DateTime.fromMillisecondsSinceEpoch(entry['timestamp'] as int),
        ),
    ];
  }
}
