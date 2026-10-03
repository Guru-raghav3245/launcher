import 'package:flutter/material.dart';

import '../models/my_space_tile.dart';
import '../models/tile_kind.dart';
import '../my_space/add_tile_sheet.dart';
import '../my_space/manage_tiles_page.dart';
import '../my_space/tile_card.dart';
import '../my_space/tiles/app_folder_tile.dart';
import '../my_space/tiles/from_app_tile.dart';
import '../my_space/tiles/notes_tile.dart';
import '../my_space/tiles/quote_tile.dart';
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
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: tiles.length + 1,
          itemBuilder: (context, index) {
            // After the last tile: the way into reordering and removing them.
            if (index == tiles.length) {
              return Center(
                child: TextButton.icon(
                  onPressed: onManage,
                  icon: const Icon(Icons.tune),
                  label: const Text('Manage tiles'),
                  style: TextButton.styleFrom(foregroundColor: Colors.black54),
                ),
              );
            }
            final tile = tiles[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: switch (tile.kind) {
                TileKind.notes => NotesTile(
                  tile: tile,
                  onChanged: (data) => onUpdate(tile.id, data),
                ),
                TileKind.todo => TodoTile(
                  tile: tile,
                  onChanged: (data) => onUpdate(tile.id, data),
                ),
                TileKind.weather => WeatherTile(
                  tile: tile,
                  onChanged: (data) => onUpdate(tile.id, data),
                ),
                TileKind.appFolder => AppFolderTile(
                  tile: tile,
                  onChanged: (data) => onUpdate(tile.id, data),
                ),
                TileKind.fromApp => FromAppTile(tile: tile),
                TileKind.quote => QuoteTile(tile: tile, onChanged: (data) => onUpdate(tile.id, data)),
              },
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            onPressed: onAdd,
            child: const Icon(Icons.add),
          ),
        ),
      ],
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
          const Text(
            'MY SPACE',
            style: TextStyle(color: Colors.black45, letterSpacing: 2, fontSize: 13),
          ),
          const SizedBox(height: 12),
          const Text(
            'A space for what matters.',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, height: 1.15),
          ),
          const SizedBox(height: 12),
          const Text(
            'Keep the information you care about within a glance.',
            style: TextStyle(fontSize: 16, color: Colors.black54),
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
                      children: [
                        Text('☑ Water the plants'),
                        SizedBox(height: 6),
                        Text('☐ Call the bank'),
                      ],
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
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
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
