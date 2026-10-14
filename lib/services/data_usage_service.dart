import 'package:flutter/services.dart';

/// Bytes over mobile data and Wi-Fi, and the biggest apps. See
/// `DataUsageBridge.kt`; it needs the same usage access as Mind Space.
typedef AppDataUse = ({String packageName, int mobile, int wifi});

class DataUsage {
  const DataUsage({required this.mobile, required this.wifi, this.apps = const []});

  final int mobile;
  final int wifi;
  final List<AppDataUse> apps;
}

class DataUsageService {
  const DataUsageService();

  static const _channel = MethodChannel('student.launcher/datausage');

  /// Data used in [start, end), with the [topApps] biggest apps by total.
  Future<DataUsage> usage({required DateTime start, required DateTime end, int topApps = 0}) async {
    final result = (await _channel.invokeMapMethod<String, Object?>('usage', {
      'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
      'topApps': topApps,
    }))!;
    return DataUsage(
      mobile: result['mobile'] as int,
      wifi: result['wifi'] as int,
      apps: [
        for (final app in (result['apps'] as List).cast<Map<Object?, Object?>>())
          (packageName: app['package'] as String, mobile: app['mobile'] as int, wifi: app['wifi'] as int),
      ],
    );
  }
}

/// "0 B", "12 KB", "3.4 MB", "1.2 GB" (decimal, like phone data counters).
String formatBytes(int bytes) {
  if (bytes < 1000) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1000;
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  return '${value >= 10 ? value.round() : value.toStringAsFixed(1)} ${units[unit]}';
}
