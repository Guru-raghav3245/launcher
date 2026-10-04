import 'package:flutter/services.dart';

/// Memory and storage at one moment (bytes), for the RAM & Storage tile.
class SystemStats {
  const SystemStats({
    required this.ramTotal,
    required this.ramAvailable,
    required this.storageTotal,
    required this.storageFree,
    this.lowMemory = false,
  });

  final int ramTotal;
  final int ramAvailable;
  final int storageTotal;
  final int storageFree;

  /// Android considers memory low and has started stopping background apps.
  final bool lowMemory;

  int get ramUsed => ramTotal - ramAvailable;
  int get storageUsed => storageTotal - storageFree;
  double get ramFraction => ramTotal == 0 ? 0 : ramUsed / ramTotal;
  double get storageFraction => storageTotal == 0 ? 0 : storageUsed / storageTotal;
}

/// Reads [SystemStats] from MainActivity's `systemStats` method.
class SystemStatsService {
  const SystemStatsService();

  static const _channel = MethodChannel('student.launcher/app');

  /// The latest reading, for Manage Tiles' one-line summary.
  static SystemStats? last;

  Future<SystemStats> read() async {
    final map = (await _channel.invokeMapMethod<String, Object?>('systemStats'))!;
    return last = SystemStats(
      ramTotal: map['ramTotal']! as int,
      ramAvailable: map['ramAvailable']! as int,
      storageTotal: map['storageTotal']! as int,
      storageFree: map['storageFree']! as int,
      lowMemory: map['lowMemory'] as bool? ?? false,
    );
  }
}

/// Bytes as gigabytes the way phones label storage (1 GB = 10⁹ bytes): one
/// decimal under 10 GB ("2.8 GB"), whole numbers above ("41 GB").
String formatGigabytes(int bytes) {
  final gb = bytes / 1e9;
  return gb < 10 ? '${gb.toStringAsFixed(1)} GB' : '${gb.round()} GB';
}

/// Manage Tiles' summary, e.g. "RAM 62% · 41 GB free".
String systemStatsSummary(SystemStats? stats) => stats == null
    ? 'Live memory and storage'
    : 'RAM ${(stats.ramFraction * 100).round()}% · ${formatGigabytes(stats.storageFree)} free';
