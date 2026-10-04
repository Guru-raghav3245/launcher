import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../models/my_space_tile.dart';
import '../models/tile_kind.dart';
import '../search/app_result_row.dart';
import '../search/app_search.dart';
import '../search/app_search_bar.dart';
import '../services/app_widget_service.dart';
import '../services/installed_apps_service.dart';
import 'built_in_tile_specs.dart';
import 'widget_preview.dart';

/// Opens "Add New Tile" over a dark scrim, full screen, as in the original.
/// Resolves with the tile the user added, or null if they backed out.
Future<MySpaceTile?> showAddTileSheet(BuildContext context) {
  final ground = Theme.of(context).colorScheme.surface;
  return showGeneralDialog<MySpaceTile>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: ground.withValues(alpha: 0.96),
    pageBuilder: (context, _, _) => const Material(
      type: MaterialType.transparency,
      child: SafeArea(child: _AddTileSheet()),
    ),
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

  void _add(BuiltInTileSpec spec) {
    Navigator.of(
      context,
    ).pop(MySpaceTile(id: DateTime.now().microsecondsSinceEpoch.toString(), kind: spec.kind, data: spec.defaultData()));
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
    final colors = Theme.of(context).colorScheme;
    // The original's switch: two outlined halves in an outlined pill, the
    // chosen one ringed in ink.
    Widget half(String label, bool value) {
      final on = _fromApps == value;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _fromApps = value),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: on ? colors.onSurface : Colors.transparent),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(label, style: TextStyle(fontSize: 18, color: on ? colors.onSurface : colors.onSurfaceVariant)),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add New Tile',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              border: Border.all(color: colors.outline),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(children: [half('From Apps', true), half('Built-in', false)]),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _fromApps ? _FromAppsList(onAdd: _addWidget, busy: _bindingWidget) : _BuiltInList(onAdd: _add),
          ),
        ],
      ),
    );
  }
}

/// The built-in tiles, each a row with ▾ that opens its sample tile and
/// "Add tile" right underneath (the original previews inline).
class _BuiltInList extends StatefulWidget {
  const _BuiltInList({required this.onAdd});

  final ValueChanged<BuiltInTileSpec> onAdd;

  @override
  State<_BuiltInList> createState() => _BuiltInListState();
}

class _BuiltInListState extends State<_BuiltInList> {
  int? _open;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView.builder(
      itemCount: builtInTileSpecs.length,
      itemBuilder: (context, index) {
        final spec = builtInTileSpecs[index];
        final open = _open == index;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _open = open ? null : index),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                child: Row(
                  children: [
                    Icon(spec.icon, size: 28, color: colors.onSurface),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(spec.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            spec.subtitle,
                            style: TextStyle(fontSize: 15, color: Color.lerp(colors.onSurface, colors.surface, 0.25)),
                          ),
                        ],
                      ),
                    ),
                    Icon(open ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: colors.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            if (open) ...[
              IgnorePointer(child: spec.previewCard),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => widget.onAdd(spec),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Add tile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

/// Lists other apps' home-screen widgets, searchable by app or widget name,
/// each with a thumbnail of the widget. Tapping one expands its preview
/// (Phase 12 task 6); its "Add tile" triggers [onAdd], which allocates +
/// binds it natively before the tile is created (Phase 3 task 7).
class _FromAppsList extends StatefulWidget {
  const _FromAppsList({required this.onAdd, required this.busy});

  final ValueChanged<WidgetProvider> onAdd;
  final bool busy;

  @override
  State<_FromAppsList> createState() => _FromAppsListState();
}

class _FromAppsListState extends State<_FromAppsList> {
  final _controller = TextEditingController();
  // The expanded row's provider.
  String? _open;
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
                          return appName.toLowerCase().contains(query) || provider.label.toLowerCase().contains(query);
                        }).toList();
                        return ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final provider = filtered[index];
                            final app = appsByPackage[provider.packageName];
                            final open = _open == provider.provider;
                            final colors = Theme.of(context).colorScheme;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: AppIcon(icon: app?.icon, size: 40),
                                  title: Text(app?.name ?? provider.packageName),
                                  subtitle: Text(provider.label),
                                  trailing: open
                                      ? Icon(Icons.arrow_drop_up, color: colors.onSurfaceVariant)
                                      : WidgetPreview(provider: provider.provider, height: 40, width: 64),
                                  onTap: () => setState(() => _open = open ? null : provider.provider),
                                ),
                                if (open) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    // The card fill, so the sheet's backdrop doesn't show through.
                                    decoration: BoxDecoration(
                                      color: colors.surfaceContainer,
                                      border: Border.all(color: colors.outline),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: WidgetPreview(provider: provider.provider, height: 180),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    onPressed: () => widget.onAdd(provider),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: colors.primary,
                                      foregroundColor: colors.onPrimary,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text(
                                      'Add tile',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ],
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
