import 'package:flutter/material.dart';

import '../models/my_space_tile.dart';
import '../models/tile_kind.dart';
import '../my_space/add_tile_sheet.dart';
import '../my_space/manage_tiles_page.dart';
import '../my_space/tile_card.dart';
import '../my_space/tiles/app_folder_tile.dart';
import '../my_space/tiles/from_app_tile.dart';
import '../my_space/tiles/calendar_tile.dart';
import '../my_space/tiles/hydration_tile.dart';
import '../my_space/tiles/music_tile.dart';
import '../my_space/tiles/notes_tile.dart';
import '../my_space/tiles/quote_tile.dart';
import '../my_space/tiles/screen_time_tile.dart';
import '../my_space/tiles/todo_tile.dart';
import '../my_space/tiles/weather_tile.dart';
import '../services/my_space_service.dart';

/// My Space panel: a persisted list of dashboard tiles (Weather, Notes,
/// Todo, App Folder, from-app widgets — built out across Phase 3 tasks
/// 3-7, all now implemented). Shows an empty-state teaser until the user
/// adds their first tile.
class MySpacePanel extends StatefulWidget {
  const MySpacePanel({super.key});

  @override
  State<MySpacePanel> createState() => _MySpacePanelState();
}

class _MySpacePanelState extends State<MySpacePanel> {
  final _service = const MySpaceService();
  List<MySpaceTile>? _tiles;

  @override
  void initState() {
    super.initState();
    _service.loadTiles().then((tiles) {
      if (mounted) setState(() => _tiles = tiles);
    });
  }

  Future<void> _addTile() async {
    final tile = await showAddTileSheet(context);
    if (tile == null) return;
    final updated = [...?_tiles, tile];
    setState(() => _tiles = updated);
    await _service.saveTiles(updated);
  }

  Future<void> _updateTileData(String id, Map<String, dynamic> data) async {
    final updated = [
      for (final tile in _tiles!)
        if (tile.id == id) tile.copyWith(data: data) else tile,
    ];
    setState(() => _tiles = updated);
    await _service.saveTiles(updated);
  }

  Future<void> _manageTiles() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ManageTilesPage(
          tiles: _tiles!,
          onChanged: (tiles) {
            setState(() => _tiles = tiles);
            _service.saveTiles(tiles);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tiles = _tiles;
    return SafeArea(
      child: tiles == null
          ? const Center(child: CircularProgressIndicator())
          : tiles.isEmpty
          ? _EmptyState(onAdd: _addTile)
          : _TileList(tiles: tiles, onAdd: _addTile, onManage: _manageTiles, onUpdate: _updateTileData),
    );
  }
}

class _TileList extends StatelessWidget {
  const _TileList({required this.tiles, required this.onAdd, required this.onManage, required this.onUpdate});

  final List<MySpaceTile> tiles;
  final VoidCallback onAdd;
  final VoidCallback onManage;
  final void Function(String id, Map<String, dynamic> data) onUpdate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Header, the tiles, then Edit Tile / Add Tile, as in the original.
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: tiles.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 0, 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'My Space',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 2),
                  ),
                ),
                IconButton(
                  tooltip: 'Manage tiles',
                  onPressed: onManage,
                  icon: Icon(Icons.tune, color: colors.onSurface),
                ),
              ],
            ),
          );
        }
        if (index == tiles.length + 1) {
          return Row(
            children: [
              Expanded(
                child: _FaintButton(icon: Icons.edit_outlined, label: 'Edit Tile', onTap: onManage),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _FaintButton(icon: Icons.add, label: 'Add Tile', onTap: onAdd),
              ),
            ],
          );
        }
        final tile = tiles[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: switch (tile.kind) {
            TileKind.notes => NotesTile(tile: tile, onChanged: (data) => onUpdate(tile.id, data)),
            TileKind.todo => TodoTile(tile: tile, onChanged: (data) => onUpdate(tile.id, data)),
            TileKind.weather => WeatherTile(tile: tile, onChanged: (data) => onUpdate(tile.id, data)),
            TileKind.appFolder => AppFolderTile(tile: tile, onChanged: (data) => onUpdate(tile.id, data)),
            TileKind.fromApp => FromAppTile(tile: tile),
            TileKind.quote => QuoteTile(tile: tile, onChanged: (data) => onUpdate(tile.id, data)),
            TileKind.hydration => HydrationTile(tile: tile, onChanged: (data) => onUpdate(tile.id, data)),
            TileKind.screenTime => const ScreenTimeTile(),
            TileKind.calendar => const CalendarTile(),
            TileKind.music => const MusicTile(),
          },
        );
      },
    );
  }
}

/// The original's quiet buttons under the tiles: a barely-there fill and
/// grey ink.
class _FaintButton extends StatelessWidget {
  const _FaintButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: colors.onSurfaceVariant),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(fontSize: 16, color: colors.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MY SPACE',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 2, fontSize: 13),
          ),
          const SizedBox(height: 12),
          const Text(
            'A space for what matters.',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, height: 1.15),
          ),
          const SizedBox(height: 12),
          Text(
            'Keep the information you care about within a glance.',
            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          const Opacity(
            opacity: 0.35,
            child: IgnorePointer(
              child: Column(
                children: [
                  TileCard(
                    label: 'WEATHER',
                    icon: Icons.cloud_outlined,
                    child: Text('23°  Rain', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(height: 16),
                  TileCard(
                    label: 'TO-DO',
                    icon: Icons.checklist,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text('☑ Water the plants'), SizedBox(height: 6), Text('☐ Call the bank')],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: onAdd,
              child: const Text('Add Your First Tile', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
