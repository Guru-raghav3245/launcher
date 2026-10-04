import 'package:flutter/material.dart';

import '../models/my_space_tile.dart';
import '../models/tile_kind.dart';
import '../services/app_widget_service.dart';
import '../services/system_stats_service.dart';
import 'built_in_tile_specs.dart';
import 'widget_preview.dart';
import 'tiles/hydration_tile.dart';
import 'tiles/quote_tile.dart';

/// One line describing what a tile holds, so similar tiles can be told apart.
String _summary(MySpaceTile tile) {
  final data = tile.data;
  switch (tile.kind) {
    case TileKind.notes:
      final text = (data['text'] as String? ?? '').trim();
      return text.isEmpty ? 'Empty' : text.split('\n').first;
    case TileKind.todo:
      final items = (data['items'] as List? ?? const []).cast<Map>();
      return items.isEmpty ? 'No items' : '${items.where((i) => i['done'] == true).length} of ${items.length} done';
    case TileKind.appFolder:
      final count = (data['packages'] as List? ?? const []).length;
      return '$count ${count == 1 ? 'app' : 'apps'}';
    case TileKind.weather:
      return (data['snapshot'] as Map?)?['locationName'] as String? ?? 'Your location';
    case TileKind.fromApp:
      return 'App widget';
    case TileKind.hydration:
      return '${glassesToday(data, DateTime.now())} of ${glassGoal(data)} glasses today';
    case TileKind.music:
      return "What's playing";
    case TileKind.calendar:
      return 'Your next events';
    case TileKind.screenTime:
      return "Today's usage and top apps";
    case TileKind.system:
      return systemStatsSummary(SystemStatsService.last);
    case TileKind.quote:
      return 'Today: ${quotes[quoteIndex(data, DateTime.now())].$2}';
  }
}

/// Manage Tiles: drag My Space's tiles into a new order, or remove them.
/// Every change is handed to [onChanged] (which saves) right away.
class ManageTilesPage extends StatefulWidget {
  const ManageTilesPage({super.key, required this.tiles, required this.onChanged});

  final List<MySpaceTile> tiles;
  final ValueChanged<List<MySpaceTile>> onChanged;

  @override
  State<ManageTilesPage> createState() => _ManageTilesPageState();
}

class _ManageTilesPageState extends State<ManageTilesPage> {
  late final _tiles = [...widget.tiles];

  void _update(void Function() change) {
    setState(change);
    widget.onChanged([..._tiles]);
  }

  Future<void> _remove(MySpaceTile tile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${tileTitle(tile)}?'),
        content: const Text("Its contents can't be brought back."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    _update(() => _tiles.remove(tile));
    // A From-Apps tile holds a native widget id; give it back to the host.
    if (tile.kind == TileKind.fromApp && tile.data['widgetId'] is int) {
      try {
        await const AppWidgetService().deleteId(tile.data['widgetId'] as int);
      } catch (_) {
        // No widget channel (tests).
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage tiles')),
      body: _tiles.isEmpty
          ? Center(
              child: Text('No tiles', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              buildDefaultDragHandles: false,
              itemCount: _tiles.length,
              onReorderItem: (from, to) => _update(() => _tiles.insert(to, _tiles.removeAt(from))),
              itemBuilder: (context, index) {
                final tile = _tiles[index];
                final provider = tile.kind == TileKind.fromApp ? tile.data['provider'] as String? : null;
                final row = ListTile(
                  leading: Icon(tileIcon(tile)),
                  title: Text(tileTitle(tile)),
                  subtitle: Text(_summary(tile), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _remove(tile),
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_handle)),
                      ),
                    ],
                  ),
                );
                // A From-Apps tile shows what its widget looks like, as in
                // the Add New Tile sheet.
                if (provider == null) return KeyedSubtree(key: ValueKey(tile.id), child: row);
                return Column(
                  key: ValueKey(tile.id),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    row,
                    Padding(
                      padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
                      child: WidgetPreview(provider: provider, height: 96),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
