import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/music_service.dart';
import '../tile_card.dart';

/// Explains notification access before sending the user to Android's
/// screen for it, the way the original explains its services first.
Future<void> _askForAccess(BuildContext context) async {
  final allow = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Notification access'),
      content: const Text(
        "To show what's playing and its controls, Android requires notification access. The launcher only "
        'reads the current song from music apps; your other notifications are never read, stored, or shared.\n\n'
        'On the next screen, switch on "Student Launcher music tile".',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Continue')),
      ],
    ),
  );
  if (allow == true) await const MusicService().openAccessSettings();
}

/// Music tile: what's playing (art, title, artist) with previous /
/// play-pause / next. Asks for notification access from a button on the tile.
// ponytail: polls every few seconds while on screen; a MediaController
// callback pushed over a channel would be instant, if the lag ever matters.
class MusicTile extends StatefulWidget {
  const MusicTile({super.key});

  @override
  State<MusicTile> createState() => _MusicTileState();
}

class _MusicTileState extends State<MusicTile> {
  final _music = const MusicService();
  late final _lifecycle = AppLifecycleListener(onResume: _load);
  Timer? _poll;
  bool? _hasAccess;
  NowPlaying? _nowPlaying;

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _load();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final access = await _music.hasAccess();
      final playing = access ? await _music.nowPlaying() : null;
      if (mounted) {
        setState(() {
          _hasAccess = access;
          _nowPlaying = playing;
        });
      }
    } catch (_) {
      _poll?.cancel(); // No music channel (tests): stop asking.
      if (mounted) setState(() => _hasAccess = false);
    }
  }

  Future<void> _control(String action) async {
    await _music.control(action);
    await Future<void>.delayed(const Duration(milliseconds: 300)); // let the player update its state
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return TileCard(
      label: 'MUSIC',
      icon: Icons.music_note_outlined,
      child: switch (_hasAccess) {
        null => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),
        false => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("See what's playing and control it here.", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _askForAccess(context),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('Allow notification access'),
            ),
          ],
        ),
        true => MusicBody(nowPlaying: _nowPlaying, onControl: _control),
      },
    );
  }
}

/// Art, title, artist, and controls; shared with the Add New Tile preview.
class MusicBody extends StatelessWidget {
  const MusicBody({super.key, required this.nowPlaying, this.onControl});

  final NowPlaying? nowPlaying;
  final ValueChanged<String>? onControl;

  @override
  Widget build(BuildContext context) {
    final now = nowPlaying;
    if (now == null) return Text('Nothing playing', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant));
    final art = now.art;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 56,
            height: 56,
            child: art == null
                ? ColoredBox(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    child: Icon(Icons.music_note, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  )
                // Grayscale, like the rest of the launcher.
                : ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      0.2126, 0.7152, 0.0722, 0, 0, //
                      0.2126, 0.7152, 0.0722, 0, 0, //
                      0.2126, 0.7152, 0.0722, 0, 0, //
                      0, 0, 0, 1, 0,
                    ]),
                    child: Image.memory(art, fit: BoxFit.cover, gaplessPlayback: true),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        // Text gets the full width; the controls sit underneath it.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(now.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
              if (now.artist case final artist?)
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              Row(
                children: [
                  for (final (action, icon, tooltip) in [
                    ('previous', Icons.skip_previous, 'Previous'),
                    (
                      now.playing ? 'pause' : 'play',
                      now.playing ? Icons.pause : Icons.play_arrow,
                      now.playing ? 'Pause' : 'Play',
                    ),
                    ('next', Icons.skip_next, 'Next'),
                  ])
                    IconButton(
                      tooltip: tooltip,
                      icon: Icon(icon),
                      visualDensity: VisualDensity.compact,
                      onPressed: onControl == null ? null : () => onControl!(action),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
