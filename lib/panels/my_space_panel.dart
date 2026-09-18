import 'package:flutter/material.dart';

import '../models/my_space_tile.dart';
import '../my_space/add_tile_sheet.dart';
import '../services/my_space_service.dart';

/// My Space panel: a persisted list of dashboard tiles (Weather, Notes,
/// Todo, App Folder, from-app widgets — built out across Phase 3 tasks
/// 3-7). Shows an empty-state teaser until the user adds their first tile.
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

  @override
  Widget build(BuildContext context) {
    final tiles = _tiles;
    return SafeArea(
      child: tiles == null
          ? const Center(child: CircularProgressIndicator())
          : tiles.isEmpty
          ? _EmptyState(onAdd: _addTile)
          : _TileList(tiles: tiles, onAdd: _addTile),
    );
  }
}

class _TileList extends StatelessWidget {
  const _TileList({required this.tiles, required this.onAdd});

  final List<MySpaceTile> tiles;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    // Per-kind tile widgets land in tasks 3-7; for now just prove the
    // persisted list round-trips.
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: tiles.length,
          itemBuilder: (context, index) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(title: Text(tiles[index].kind.name)),
          ),
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
          Opacity(
            opacity: 0.35,
            child: IgnorePointer(
              child: Column(
                children: const [_WeatherPreviewCard(), SizedBox(height: 16), _TodoPreviewCard()],
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

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.label, required this.icon, required this.child});

  final String label;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.black45),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black45,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _WeatherPreviewCard extends StatelessWidget {
  const _WeatherPreviewCard();

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      label: 'WEATHER',
      icon: Icons.cloud_outlined,
      child: const Text('23°  Rain', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    );
  }
}

class _TodoPreviewCard extends StatelessWidget {
  const _TodoPreviewCard();

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      label: 'TO-DO',
      icon: Icons.checklist,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('☑ Water the plants'),
          SizedBox(height: 6),
          Text('☐ Call the bank'),
        ],
      ),
    );
  }
}
