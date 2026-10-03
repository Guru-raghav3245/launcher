import 'package:flutter/material.dart';

import '../../models/my_space_tile.dart';
import '../../services/weather_service.dart';
import '../../state/app_settings_scope.dart';
import '../tile_card.dart';

/// Weather tile: current temp/hi-lo/location + hourly forecast for the
/// device's current location. Fetched data is cached into
/// [MySpaceTile.data]['snapshot'] so a relaunch shows last-known weather
/// instantly while a fresh fetch runs in the background.
class WeatherTile extends StatefulWidget {
  const WeatherTile({super.key, required this.tile, required this.onChanged});

  final MySpaceTile tile;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  State<WeatherTile> createState() => _WeatherTileState();
}

class _WeatherTileState extends State<WeatherTile> {
  static const _service = WeatherService();

  WeatherSnapshot? _snapshot;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final cached = widget.tile.data['snapshot'];
    if (cached != null) {
      _snapshot = WeatherSnapshot.fromJson(Map<String, dynamic>.from(cached as Map));
      _loading = false;
    }
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final snapshot = await _service.fetchForCurrentLocation();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
        _loading = false;
      });
      widget.onChanged({'snapshot': snapshot.toJson()});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return TileCard(
      label: 'WEATHER',
      icon: Icons.cloud_outlined,
      trailing: _loading
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _refresh,
            ),
      child: snapshot == null
          ? _WeatherMessage(error: _error, loading: _loading, onRetry: _refresh)
          : _WeatherBody(snapshot: snapshot),
    );
  }
}

class _WeatherMessage extends StatelessWidget {
  const _WeatherMessage({required this.error, required this.loading, required this.onRetry});

  final Object? error;
  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Text('Fetching weather…', style: TextStyle(color: Colors.black45));
    final message = error is LocationDeniedException
        ? 'Location access is needed for weather.'
        : 'Couldn\'t load weather.';
    return Row(
      children: [
        Expanded(child: Text(message, style: const TextStyle(color: Colors.black45))),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

class _WeatherBody extends StatelessWidget {
  const _WeatherBody({required this.snapshot});

  final WeatherSnapshot snapshot;

  /// "3 PM" or "15:00", per the time format (Settings → Time & units).
  static String _hourLabel(BuildContext context, HourlyForecast hour) {
    final h = hour.hour;
    if (h == null) return hour.hourLabel;
    if (MediaQuery.alwaysUse24HourFormatOf(context)) return '${h.toString().padLeft(2, '0')}:00';
    return '${h % 12 == 0 ? 12 : h % 12} ${h < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              settings.formatTemp(snapshot.tempC),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(snapshot.condition, style: const TextStyle(fontSize: 16, color: Colors.black54)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'H:${settings.formatTemp(snapshot.hiC)}  L:${settings.formatTemp(snapshot.loC)}  ·  ${snapshot.locationName}',
          style: const TextStyle(color: Colors.black45, fontSize: 13),
        ),
        if (snapshot.hourly.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 60,
            child: Row(
              children: [
                for (final hour in snapshot.hourly)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_hourLabel(context, hour), style: const TextStyle(fontSize: 11, color: Colors.black45)),
                        const SizedBox(height: 6),
                        Text(settings.formatTemp(hour.tempC), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
