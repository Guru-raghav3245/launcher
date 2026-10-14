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

  static const _channel = MethodChannel('student.launcher/appwidget');

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

  /// A PNG picture of [provider]'s widget (its preview layout, preview
  /// image, or icon), or null if it has none. Rendered once per provider
  /// and kept, so the sheet and Manage tiles share it.
  Future<Uint8List?> preview(String provider) => _previews[provider] ??= _channel
      .invokeMethod<Uint8List>('preview', {'provider': provider})
      .catchError((Object _) => null);

  static final _previews = <String, Future<Uint8List?>>{};

  /// Height over width of a bound widget's designed size, or null if unknown.
  /// Kept per id, so a tile built twice asks once.
  Future<double?> aspect(int widgetId) => _aspects[widgetId] ??= _channel
      .invokeMethod<double>('aspect', {'widgetId': widgetId})
      .catchError((Object _) => null);

  static final _aspects = <int, Future<double?>>{};

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
