import 'package:flutter/material.dart';

import '../models/my_space_tile.dart';
import '../models/tile_kind.dart';
import 'tile_card.dart';
import 'tiles/hydration_tile.dart';
import 'tiles/quote_tile.dart';

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
    preview: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('23°  Rain', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('H:26°  L:15°  ·  Your location', style: TextStyle(color: Colors.black54)),
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
    preview: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('☑  Water the plants', style: TextStyle(fontSize: 16, color: Colors.black45)),
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
];

/// How a tile is named in lists like Manage Tiles: its spec's title, or the
/// widget's own label for a From-Apps tile.
String tileTitle(MySpaceTile tile) => tile.kind == TileKind.fromApp
    ? tile.data['label'] as String? ?? 'Widget'
    : builtInTileSpecs.firstWhere((s) => s.kind == tile.kind).title;

IconData tileIcon(MySpaceTile tile) => tile.kind == TileKind.fromApp
    ? Icons.widgets_outlined
    : builtInTileSpecs.firstWhere((s) => s.kind == tile.kind).icon;
