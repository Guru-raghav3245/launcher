import 'package:flutter/material.dart';

import '../models/my_space_tile.dart';
import '../models/tile_kind.dart';
import '../my_space/add_tile_sheet.dart';
import '../my_space/built_in_tile_specs.dart';
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
import '../my_space/tiles/system_tile.dart';
import '../my_space/tiles/todo_tile.dart';
import '../my_space/tiles/weather_tile.dart';
import '../my_space/tiles/data_usage_tile.dart';
import '../services/my_space_service.dart';
import '../widgets/skeleton.dart';

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
  var _editing = false;

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

  void _setTiles(List<MySpaceTile> tiles) {
    setState(() {
      _tiles = tiles;
      if (tiles.isEmpty) _editing = false;
    });
    _service.saveTiles(tiles);
  }

  Future<void> _removeTile(MySpaceTile tile) async {
    if (await confirmRemoveTile(context, tile)) _setTiles([for (final t in _tiles!) if (t.id != tile.id) t]);
  }

  Future<void> _renameTile(MySpaceTile tile) async {
    final name = await showDialog<String>(context: context, builder: (_) => _RenameDialog(initial: tile.name ?? ''));
    if (name == null) return;
    // A blank name restores the default title.
    final trimmed = name.trim();
    _setTiles([
      for (final t in _tiles!)
        if (t.id == tile.id) (trimmed.isEmpty ? t.withoutName() : t.copyWith(name: trimmed)) else t,
    ]);
  }

  void _reorder(int from, int to) {
    final tiles = [..._tiles!];
    tiles.insert(to, tiles.removeAt(from));
    _setTiles(tiles);
  }

  @override
  Widget build(BuildContext context) {
    final tiles = _tiles;
    return SafeArea(
      child: tiles == null
          ? const TileListSkeleton()
          : tiles.isEmpty
          ? _EmptyState(onAdd: _addTile)
          : _TileList(
              tiles: tiles,
              editing: _editing,
              onAdd: _addTile,
              onManage: _manageTiles,
              onEdit: () => setState(() => _editing = true),
              onDone: () => setState(() => _editing = false),
              onUpdate: _updateTileData,
              onRemove: _removeTile,
              onRename: _renameTile,
              onReorder: _reorder,
            ),
    );
  }
}

class _TileList extends StatelessWidget {
  const _TileList({
    required this.tiles,
    required this.editing,
    required this.onAdd,
    required this.onManage,
    required this.onEdit,
    required this.onDone,
    required this.onUpdate,
    required this.onRemove,
    required this.onRename,
    required this.onReorder,
  });

  final List<MySpaceTile> tiles;
  final bool editing;
  final VoidCallback onAdd;
  final VoidCallback onManage;
  final VoidCallback onEdit;
  final VoidCallback onDone;
  final void Function(String id, Map<String, dynamic> data) onUpdate;
  final ValueChanged<MySpaceTile> onRemove;
  final ValueChanged<MySpaceTile> onRename;
  final void Function(int from, int to) onReorder;

  Widget _header(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 16),
      child: Row(
        children: [
          const Expanded(
            child: Text('My Space', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 2)),
          ),
          if (editing)
            TextButton(onPressed: onDone, child: const Text('Done'))
          else ...[
            IconButton(tooltip: 'Add tile', onPressed: onAdd, icon: Icon(Icons.add, color: colors.onSurface)),
            IconButton(tooltip: 'Manage tiles', onPressed: onManage, icon: Icon(Icons.tune, color: colors.onSurface)),
          ],
        ],
      ),
    );
  }

  Widget _body(MySpaceTile tile) {
    void changed(Map<String, dynamic> data) => onUpdate(tile.id, data);
    return switch (tile.kind) {
      TileKind.notes => NotesTile(tile: tile, onChanged: changed),
      TileKind.todo => TodoTile(tile: tile, onChanged: changed),
      TileKind.todoTasks => TodoTasksTile(tile: tile, onChanged: changed),
      TileKind.weather => WeatherTile(tile: tile, onChanged: changed),
      TileKind.appFolder => AppFolderTile(tile: tile, onChanged: changed, editing: editing),
      TileKind.fromApp => FromAppTile(tile: tile),
      TileKind.quote => QuoteTile(tile: tile, onChanged: changed),
      TileKind.hydration => HydrationTile(tile: tile, onChanged: changed),
      TileKind.screenTime => const ScreenTimeTile(),
      TileKind.dataUsage => const DataUsageTile(),
      TileKind.calendar => const CalendarTile(),
      TileKind.music => const MusicTile(),
      TileKind.system => const SystemTile(),
    };
  }

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.fromLTRB(16, 0, 16, 32);
    if (editing) {
      // Edit mode: each tile gets a bar to drag, rename (folders), or remove
      // it, and its own controls are switched off (a folder keeps its
      // remove badges).
      return ReorderableListView.builder(
        padding: padding,
        header: _header(context),
        buildDefaultDragHandles: false,
        itemCount: tiles.length,
        onReorderItem: onReorder,
        itemBuilder: (context, index) {
          final tile = tiles[index];
          return Padding(
            key: ValueKey(tile.id),
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EditBar(
                  tile: tile,
                  index: index,
                  onRename: tile.kind == TileKind.appFolder ? () => onRename(tile) : null,
                  onRemove: () => onRemove(tile),
                ),
                AbsorbPointer(absorbing: tile.kind != TileKind.appFolder, child: _body(tile)),
              ],
            ),
          );
        },
      );
    }
    return ListView.builder(
      padding: padding,
      itemCount: tiles.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _header(context);
        final tile = tiles[index - 1];
        // Press and hold any tile to edit; controls inside a tile that handle
        // their own long-press (text fields) keep it.
        return GestureDetector(
          onLongPress: () {
            Feedback.forLongPress(context);
            onEdit();
          },
          child: Padding(padding: const EdgeInsets.only(bottom: 16), child: _body(tile)),
        );
      },
    );
  }
}

/// The strip above a tile in edit mode: drag handle, its name, and the
/// rename and remove buttons.
class _EditBar extends StatelessWidget {
  const _EditBar({required this.tile, required this.index, required this.onRemove, this.onRename});

  final MySpaceTile tile;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback? onRename;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.drag_handle, color: colors.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              tile.name ?? tileTitle(tile),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
          if (onRename != null) IconButton(tooltip: 'Rename', onPressed: onRename, icon: const Icon(Icons.edit_outlined, size: 20)),
          IconButton(tooltip: 'Remove', onPressed: onRemove, icon: const Icon(Icons.delete_outline, size: 22)),
        ],
      ),
    );
  }
}

/// Asks for a new name. Owns its field's controller so it outlives the
/// dialog's exit animation.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'App Folder'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: const Text('Save')),
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
