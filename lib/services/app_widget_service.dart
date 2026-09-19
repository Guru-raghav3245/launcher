import 'package:flutter/services.dart';

/// A native Android AppWidget provider another app exposes for embedding.
class WidgetProvider {
  const WidgetProvider({required this.provider, required this.packageName, required this.label});

  /// Flattened `ComponentName` string, used to re-identify the provider to
  /// Android when binding.
  final String provider;
  final String packageName;
  final String label;
}

/// Bridges to Android's AppWidgetHost/AppWidgetManager so My Space can embed
/// other apps' home-screen widgets (Phase 3 task 7). See
/// `AppWidgetHostBridge.kt` for the native half.
class AppWidgetService {
  const AppWidgetService();

  static const _channel = MethodChannel('yinyang.launcher/appwidget');

  Future<List<WidgetProvider>> listProviders() async {
    final result = await _channel.invokeMethod<List<Object?>>('listProviders') ?? [];
    return [
      for (final entry in result.cast<Map<Object?, Object?>>())
        WidgetProvider(
          provider: entry['provider'] as String,
          packageName: entry['packageName'] as String,
          label: entry['label'] as String,
        ),
    ];
  }

  Future<int> allocateId() async => (await _channel.invokeMethod<int>('allocateId'))!;

  /// Binds [widgetId] to [provider], prompting the user for consent if this
  /// app hasn't already been granted bind access. Returns false if the user
  /// declines.
  Future<bool> bind(int widgetId, String provider) async {
    final bound = await _channel.invokeMethod<bool>('bind', {'widgetId': widgetId, 'provider': provider});
    return bound ?? false;
  }

  Future<void> deleteId(int widgetId) => _channel.invokeMethod('deleteId', {'widgetId': widgetId});
}
