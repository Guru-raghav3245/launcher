import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../models/my_space_tile.dart';
import '../models/tile_kind.dart';
import '../search/app_result_row.dart';
import '../search/app_search.dart';
import '../search/app_search_bar.dart';
import '../services/app_widget_service.dart';
import '../services/installed_apps_service.dart';
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
  bool _bindingWidget = false;

  /// Shows [spec]'s sample tile first; adds it only on "Add tile".
  Future<void> _add(BuiltInTileSpec spec) async {
    final add = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(spec.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(spec.subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            IgnorePointer(child: spec.previewCard),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
            child: const Text('Add tile'),
          ),
        ],
      ),
    );
    if (add != true || !mounted) return;
    final tile = MySpaceTile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: spec.kind,
      data: spec.defaultData(),
    );
    Navigator.of(context).pop(tile);
  }

  Future<void> _addWidget(WidgetProvider provider) async {
    if (_bindingWidget) return;
    setState(() => _bindingWidget = true);
    const service = AppWidgetService();
    final widgetId = await service.allocateId();
    final bound = await service.bind(widgetId, provider.provider);
    if (!bound) {
      await service.deleteId(widgetId);
      if (mounted) setState(() => _bindingWidget = false);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(
      MySpaceTile(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        kind: TileKind.fromApp,
        data: {'widgetId': widgetId, 'provider': provider.provider, 'label': provider.label},
      ),
    );
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
                      color: Theme.of(context).colorScheme.outlineVariant,
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
                Expanded(
                  child: _fromApps
                      ? _FromAppsList(onAdd: _addWidget, busy: _bindingWidget)
                      : _BuiltInList(onAdd: _add),
                ),
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

/// Lists other apps' home-screen widgets, searchable by app or widget name.
/// Tapping one triggers [onAdd], which allocates + binds it natively before
/// the tile is created (Phase 3 task 7).
class _FromAppsList extends StatefulWidget {
  const _FromAppsList({required this.onAdd, required this.busy});

  final ValueChanged<WidgetProvider> onAdd;
  final bool busy;

  @override
  State<_FromAppsList> createState() => _FromAppsListState();
}

class _FromAppsListState extends State<_FromAppsList> {
  final _controller = TextEditingController();
  late final Future<(List<AppInfo>, List<WidgetProvider>)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<AppInfo>, List<WidgetProvider>)> _load() async {
    const apps = InstalledAppsService();
    const widgets = AppWidgetService();
    final results = await Future.wait([apps.loadApps(), widgets.listProviders()]);
    return (results[0] as List<AppInfo>, results[1] as List<WidgetProvider>);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<AppInfo>, List<WidgetProvider>)>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const Center(child: CircularProgressIndicator());
        final (apps, providers) = data;
        if (providers.isEmpty) {
          return Center(
            child: Text(
              'No apps on this device offer a\nhome-screen widget.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          );
        }
        final appsByPackage = {for (final app in apps) app.packageName: app};

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSearchBar(
              controller: _controller,
              sortMode: AppSortMode.alphabetical,
              onSortModeChanged: (_) {},
              showSortControl: false,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: widget.busy
                  ? const Center(child: CircularProgressIndicator())
                  : ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) {
                        final query = _controller.text.trim().toLowerCase();
                        final filtered = providers.where((provider) {
                          if (query.isEmpty) return true;
                          final appName = appsByPackage[provider.packageName]?.name ?? provider.packageName;
                          return appName.toLowerCase().contains(query) ||
                              provider.label.toLowerCase().contains(query);
                        }).toList();
                        return ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final provider = filtered[index];
                            final app = appsByPackage[provider.packageName];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: AppIcon(icon: app?.icon, size: 40),
                              title: Text(app?.name ?? provider.packageName),
                              subtitle: Text(provider.label),
                              onTap: () => widget.onAdd(provider),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
