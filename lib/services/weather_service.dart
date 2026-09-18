import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// One hour of forecast: local hour label ("3 PM") + temperature in °C.
class HourlyForecast {
  const HourlyForecast({required this.hourLabel, required this.tempC});

  final String hourLabel;
  final double tempC;

  Map<String, dynamic> toJson() => {'hourLabel': hourLabel, 'tempC': tempC};

  factory HourlyForecast.fromJson(Map<String, dynamic> json) => HourlyForecast(
    hourLabel: json['hourLabel'] as String,
    tempC: (json['tempC'] as num).toDouble(),
  );
}

/// A fetched weather snapshot, cached in [MySpaceTile.data] so the tile has
/// something to show immediately on the next app launch while it refetches.
class WeatherSnapshot {
  const WeatherSnapshot({
    required this.locationName,
    required this.tempC,
    required this.hiC,
    required this.loC,
    required this.condition,
    required this.hourly,
    required this.fetchedAt,
  });

  final String locationName;
  final double tempC;
  final double hiC;
  final double loC;
  final String condition;
  final List<HourlyForecast> hourly;
  final DateTime fetchedAt;

  Map<String, dynamic> toJson() => {
    'locationName': locationName,
    'tempC': tempC,
    'hiC': hiC,
    'loC': loC,
    'condition': condition,
    'hourly': hourly.map((h) => h.toJson()).toList(),
    'fetchedAt': fetchedAt.toIso8601String(),
  };

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) => WeatherSnapshot(
    locationName: json['locationName'] as String,
    tempC: (json['tempC'] as num).toDouble(),
    hiC: (json['hiC'] as num).toDouble(),
    loC: (json['loC'] as num).toDouble(),
    condition: json['condition'] as String,
    hourly: (json['hourly'] as List)
        .map((h) => HourlyForecast.fromJson(Map<String, dynamic>.from(h as Map)))
        .toList(),
    fetchedAt: DateTime.parse(json['fetchedAt'] as String),
  );
}

/// WMO weather codes (https://open-meteo.com/en/docs), collapsed to the
/// handful of conditions the tile actually shows.
(String, IconData) describeWeatherCode(int code) => switch (code) {
  0 => ('Clear', Icons.wb_sunny_outlined),
  1 || 2 => ('Partly cloudy', Icons.wb_cloudy_outlined),
  3 => ('Cloudy', Icons.cloud_outlined),
  45 || 48 => ('Fog', Icons.foggy),
  51 || 53 || 55 || 56 || 57 => ('Drizzle', Icons.grain),
  61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 => ('Rain', Icons.umbrella_outlined),
  71 || 73 || 75 || 77 || 85 || 86 => ('Snow', Icons.ac_unit),
  95 || 96 || 99 => ('Storm', Icons.thunderstorm_outlined),
  _ => ('Unknown', Icons.cloud_outlined),
};

class LocationDeniedException implements Exception {}

/// Fetches weather for the device's current location via Open-Meteo (no API
/// key required) and reverse-geocodes the coordinates to a place name.
class WeatherService {
  const WeatherService();

  Future<WeatherSnapshot> fetchForCurrentLocation() async {
    final position = await _currentPosition();
    final locationName = await _locationName(position.latitude, position.longitude);

    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${position.latitude}',
      'longitude': '${position.longitude}',
      'current': 'temperature_2m,weather_code',
      'hourly': 'temperature_2m',
      'daily': 'temperature_2m_max,temperature_2m_min',
      'forecast_days': '1',
      'timezone': 'auto',
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Weather request failed: ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;

    final current = json['current'] as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;
    final hourly = json['hourly'] as Map<String, dynamic>;

    final code = current['weather_code'] as int;
    final now = DateTime.parse(current['time'] as String);

    final hourlyTimes = (hourly['time'] as List).cast<String>();
    final hourlyTemps = (hourly['temperature_2m'] as List).cast<num>();
    final upcoming = <HourlyForecast>[];
    for (var i = 0; i < hourlyTimes.length; i++) {
      final time = DateTime.parse(hourlyTimes[i]);
      if (time.isBefore(now)) continue;
      upcoming.add(HourlyForecast(hourLabel: _hourLabel(time), tempC: hourlyTemps[i].toDouble()));
      if (upcoming.length == 6) break;
    }

    return WeatherSnapshot(
      locationName: locationName,
      tempC: (current['temperature_2m'] as num).toDouble(),
      hiC: (daily['temperature_2m_max'] as List).cast<num>().first.toDouble(),
      loC: (daily['temperature_2m_min'] as List).cast<num>().first.toDouble(),
      condition: describeWeatherCode(code).$1,
      hourly: upcoming,
      fetchedAt: DateTime.now(),
    );
  }

  Future<Position> _currentPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw LocationDeniedException();
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationDeniedException();
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  /// Reverse-geocodes via BigDataCloud's free client-side endpoint (no API
  /// key). Kept as a plain HTTP call rather than a native geocoder plugin —
  /// the `geocoding` package's platform call blocked the Android main
  /// thread on the test emulator (no Play Services geocoder backend),
  /// causing an ANR. A bounded HTTP request can only ever time out.
  Future<String> _locationName(double lat, double lon) async {
    try {
      final uri = Uri.https('api.bigdatacloud.net', '/data/reverse-geocode-client', {
        'latitude': '$lat',
        'longitude': '$lon',
        'localityLanguage': 'en',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return 'Current location';
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final city = json['city'] as String?;
      final locality = json['locality'] as String?;
      if (city?.isNotEmpty == true) return city!;
      if (locality?.isNotEmpty == true) return locality!;
      return 'Current location';
    } catch (_) {
      return 'Current location';
    }
  }

  String _hourLabel(DateTime time) {
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final suffix = time.hour < 12 ? 'AM' : 'PM';
    return '$hour12 $suffix';
  }
}
