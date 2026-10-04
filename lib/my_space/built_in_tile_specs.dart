import 'package:flutter/material.dart';

import '../models/my_space_tile.dart';
import '../models/tile_kind.dart';
import '../panels/mind_space_panel.dart';
import '../services/calendar_service.dart';
import '../services/music_service.dart';
import '../services/system_stats_service.dart';
import 'tile_card.dart';
import 'tiles/calendar_tile.dart';
import 'tiles/hydration_tile.dart';
import 'tiles/music_tile.dart';
import 'tiles/quote_tile.dart';
import 'tiles/screen_time_tile.dart';
import 'tiles/system_tile.dart';

/// Describes one row in the "Add New Tile" sheet's Built-in tab: what the
/// tile is called, the data a new one starts with, and a sample of how it
/// looks ([preview], shown before it's added).
class BuiltInTileSpec {
  const BuiltInTileSpec({
    required this.kind,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.defaultData,
    required this.preview,
  });

  final TileKind kind;
  final IconData icon;
  final String title;
  final String subtitle;
  final Map<String, dynamic> Function() defaultData;

  /// The tile's body filled with sample content (wrapped in its [TileCard]
  /// by [previewCard]).
  final Widget preview;

  Widget get previewCard => TileCard(label: title.toUpperCase(), icon: icon, child: preview);
}

final builtInTileSpecs = [
  BuiltInTileSpec(
    kind: TileKind.weather,
    icon: Icons.cloud_outlined,
    title: 'Weather',
    subtitle: 'Check daily conditions',
    defaultData: () => {},
    preview: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('23°  Rain', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Builder(builder: (context) => Text('H:26°  L:15°  ·  Your location', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
      ],
    ),
  ),
  BuiltInTileSpec(
    kind: TileKind.appFolder,
    icon: Icons.apps,
    title: 'App Folder',
    subtitle: 'Create a tile with your favorite apps',
    defaultData: () => {'packages': <String>[]},
    preview: Row(
      children: [
        for (final icon in [
          Icons.call_outlined,
          Icons.chat_bubble_outline,
          Icons.camera_alt_outlined,
          Icons.map_outlined,
        ])
          Padding(padding: const EdgeInsets.only(right: 20), child: Icon(icon, size: 32)),
      ],
    ),
  ),
  BuiltInTileSpec(
    kind: TileKind.notes,
    icon: Icons.notes,
    title: 'Notes',
    subtitle: 'Jot quick thoughts',
    defaultData: () => {'text': ''},
    preview: const Text('Pick up the dry cleaning before 6.\nCall Mum back.', style: TextStyle(fontSize: 16)),
  ),
  BuiltInTileSpec(
    kind: TileKind.todo,
    icon: Icons.checklist,
    title: 'Todo',
    subtitle: 'Track your daily tasks',
    defaultData: () => {'items': <Map<String, dynamic>>[]},
    preview: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(builder: (context) => Text('☑  Water the plants', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant))),
        SizedBox(height: 6),
        Text('☐  Call the bank', style: TextStyle(fontSize: 16)),
        SizedBox(height: 6),
        Text('☐  Evening run', style: TextStyle(fontSize: 16)),
      ],
    ),
  ),
  BuiltInTileSpec(
    kind: TileKind.quote,
    icon: Icons.format_quote,
    title: 'Quote',
    subtitle: 'A thought for the day',
    defaultData: () => {},
    preview: const QuoteBody(
      text: 'How we spend our days is, of course, how we spend our lives.',
      author: 'Annie Dillard',
    ),
  ),
  BuiltInTileSpec(
    kind: TileKind.hydration,
    icon: Icons.water_drop_outlined,
    title: 'Hydration',
    subtitle: 'Count your glasses of water',
    defaultData: () => {'goal': defaultGlassGoal},
    preview: const HydrationBody(glasses: 3, goal: defaultGlassGoal),
  ),
  BuiltInTileSpec(
    kind: TileKind.screenTime,
    icon: Icons.hourglass_empty,
    title: 'Screen Time',
    subtitle: "Today's screen time and top apps",
    defaultData: () => {},
    preview: const ScreenTimeBody(
      summary: (
        totals: MindSpaceTotals(screenTime: Duration(hours: 2, minutes: 14), pickups: 37),
        topApps: [
          (PerAppUsage(packageName: 'Browser', opens: 21, duration: Duration(minutes: 48)), null),
          (PerAppUsage(packageName: 'Messages', opens: 34, duration: Duration(minutes: 22)), null),
          (PerAppUsage(packageName: 'Maps', opens: 3, duration: Duration(minutes: 15)), null),
        ],
      ),
    ),
  ),
  BuiltInTileSpec(
    kind: TileKind.calendar,
    icon: Icons.event_outlined,
    title: 'Calendar',
    subtitle: 'Your next events',
    defaultData: () => {},
    preview: CalendarBody(
      now: DateTime(2026, 1, 5, 8),
      events: [
        CalendarEvent(
          id: 0,
          title: 'Team standup',
          begin: DateTime(2026, 1, 5, 9, 30),
          end: DateTime(2026, 1, 5, 10),
          allDay: false,
        ),
        CalendarEvent(
          id: 0,
          title: 'Lunch with Sam',
          begin: DateTime(2026, 1, 5, 13),
          end: DateTime(2026, 1, 5, 14),
          allDay: false,
        ),
        CalendarEvent(
          id: 0,
          title: "Mum's birthday",
          begin: DateTime(2026, 1, 6),
          end: DateTime(2026, 1, 7),
          allDay: true,
        ),
      ],
    ),
  ),
  BuiltInTileSpec(
    kind: TileKind.music,
    icon: Icons.music_note_outlined,
    title: 'Music',
    subtitle: "What's playing, with controls",
    defaultData: () => {},
    preview: const MusicBody(
      nowPlaying: NowPlaying(title: 'Clair de lune', artist: 'Claude Debussy', packageName: '', playing: true),
    ),
  ),
  const BuiltInTileSpec(
    kind: TileKind.system,
    icon: Icons.memory,
    title: 'RAM & Storage',
    subtitle: 'Memory and storage in use, live',
    defaultData: _noData,
    preview: SystemBody(
      stats: SystemStats(ramTotal: 2850000000, ramAvailable: 1080000000, storageTotal: 64000000000, storageFree: 41000000000),
    ),
  ),
];

Map<String, dynamic> _noData() => {};

/// How a tile is named in lists like Manage Tiles: its spec's title, or the
/// widget's own label for a From-Apps tile.
String tileTitle(MySpaceTile tile) => tile.kind == TileKind.fromApp
    ? tile.data['label'] as String? ?? 'Widget'
    : builtInTileSpecs.firstWhere((s) => s.kind == tile.kind).title;

IconData tileIcon(MySpaceTile tile) => tile.kind == TileKind.fromApp
    ? Icons.widgets_outlined
    : builtInTileSpecs.firstWhere((s) => s.kind == tile.kind).icon;
