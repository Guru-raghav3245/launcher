import 'package:flutter/services.dart';

/// What a media app is playing (or has paused).
class NowPlaying {
  const NowPlaying({required this.title, this.artist, required this.packageName, required this.playing, this.art});

  final String title;
  final String? artist;
  final String packageName;
  final bool playing;
  final Uint8List? art;
}

/// Reads and controls the active media session through `MusicBridge.kt`,
/// which needs notification access (granted on Android's settings screen).
class MusicService {
  const MusicService();

  static const _channel = MethodChannel('yinyang.launcher/music');

  Future<bool> hasAccess() async => await _channel.invokeMethod<bool>('hasAccess') ?? false;

  /// Opens Android's Notification access screen (no result reported).
  Future<void> openAccessSettings() => _channel.invokeMethod('openAccessSettings');

  Future<NowPlaying?> nowPlaying() async {
    final m = await _channel.invokeMapMethod<String, Object?>('nowPlaying');
    if (m == null) return null;
    return NowPlaying(
      title: (m['title'] as String?) ?? 'Unknown',
      artist: m['artist'] as String?,
      packageName: m['packageName'] as String,
      playing: m['playing'] as bool,
      art: m['art'] as Uint8List?,
    );
  }

  /// [action] is play, pause, next, or previous.
  Future<void> control(String action) => _channel.invokeMethod('control', {'action': action});
}
