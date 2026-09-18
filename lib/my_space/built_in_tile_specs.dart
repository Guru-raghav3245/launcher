import 'package:flutter/material.dart';

import '../models/tile_kind.dart';

/// Describes one row in the "Add New Tile" sheet's Built-in tab. Bodies
/// for each kind land in Phase 3 tasks 3-6; this only needs enough to
/// create a tile with sensible starting data.
class BuiltInTileSpec {
  const BuiltInTileSpec({
    required this.kind,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.defaultData,
  });

  final TileKind kind;
  final IconData icon;
  final String title;
  final String subtitle;
  final Map<String, dynamic> Function() defaultData;
}

final builtInTileSpecs = [
  BuiltInTileSpec(
    kind: TileKind.weather,
    icon: Icons.cloud_outlined,
    title: 'Weather',
    subtitle: 'Check daily conditions',
    defaultData: () => {},
  ),
  BuiltInTileSpec(
    kind: TileKind.appFolder,
    icon: Icons.apps,
    title: 'App Folder',
    subtitle: 'Create a tile with your favorite apps',
    defaultData: () => {'packages': <String>[]},
  ),
  BuiltInTileSpec(
    kind: TileKind.notes,
    icon: Icons.notes,
    title: 'Notes',
    subtitle: 'Jot quick thoughts',
    defaultData: () => {'text': ''},
  ),
  BuiltInTileSpec(
    kind: TileKind.todo,
    icon: Icons.checklist,
    title: 'Todo',
    subtitle: 'Track your daily tasks',
    defaultData: () => {'items': <Map<String, dynamic>>[]},
  ),
];
