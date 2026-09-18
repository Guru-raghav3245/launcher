import 'package:flutter/material.dart';

import '../models/my_space_tile.dart';
import '../widgets/segmented_toggle.dart';
import 'built_in_tile_specs.dart';

/// Opens the "Add New Tile" bottom sheet. Resolves with the tile the user
/// added, or null if they dismissed the sheet without adding one.
Future<MySpaceTile?> showAddTileSheet(BuildContext context) {
  return showModalBottomSheet<MySpaceTile>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => const _AddTileSheet(),
  );
}

class _AddTileSheet extends StatefulWidget {
  const _AddTileSheet();

  @override
  State<_AddTileSheet> createState() => _AddTileSheetState();
}

class _AddTileSheetState extends State<_AddTileSheet> {
  bool _fromApps = false;

  void _add(BuiltInTileSpec spec) {
    final tile = MySpaceTile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: spec.kind,
      data: spec.defaultData(),
    );
    Navigator.of(context).pop(tile);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Add New Tile',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Center(
                  child: SegmentedToggle<bool>(
                    value: _fromApps,
                    onChanged: (v) => setState(() => _fromApps = v),
                    options: const [
                      (false, Icons.widgets_outlined, 'Built-in'),
                      (true, Icons.apps, 'From Apps'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(child: _fromApps ? const _FromAppsPlaceholder() : _BuiltInList(onAdd: _add)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BuiltInList extends StatelessWidget {
  const _BuiltInList({required this.onAdd});

  final ValueChanged<BuiltInTileSpec> onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: builtInTileSpecs.length,
      separatorBuilder: (_, _) => const Divider(height: 24),
      itemBuilder: (context, index) {
        final spec = builtInTileSpecs[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(spec.icon),
          title: Text(spec.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(spec.subtitle),
          trailing: IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => onAdd(spec),
          ),
          onTap: () => onAdd(spec),
        );
      },
    );
  }
}

// ponytail: native from-app AppWidget browsing is Phase 3 task 7.
class _FromAppsPlaceholder extends StatelessWidget {
  const _FromAppsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Adding widgets from your installed apps\nis coming soon.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black45),
      ),
    );
  }
}
