import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../../models/my_space_tile.dart';
import '../../search/app_picker_sheet.dart';
import '../../search/app_result_row.dart';
import '../../services/app_customizations_service.dart';
import '../../services/installed_apps_service.dart';
import '../../widgets/launch_app.dart';
import '../../widgets/skeleton.dart';
import '../tile_card.dart';

/// App Folder tile: a grid of shortcuts to apps the user picked. Packages
/// are stored as `{"packages": List<String>}` in [MySpaceTile.data]; icons
/// and names are looked up live from [InstalledAppsService] (Phase 1 task 5),
/// for just these packages so the folder doesn't wait on the whole app list.
/// The tile's [MySpaceTile.name] titles it. In [editing] (My Space's edit
/// mode) each shortcut gets a remove badge and an add chip ends the list.
class AppFolderTile extends StatefulWidget {
  const AppFolderTile({super.key, required this.tile, required this.onChanged, this.editing = false});

  final MySpaceTile tile;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool editing;

  @override
  State<AppFolderTile> createState() => _AppFolderTileState();
}

class _AppFolderTileState extends State<AppFolderTile> {
  final _service = const InstalledAppsService();
  List<AppInfo>? _apps;
  AppCustomizations _customizations = const AppCustomizations();

  @override
  void initState() {
    super.initState();
    _loadApps();
    InstalledAppsService.changes.addListener(_loadApps);
    AppCustomizationsService.changes.addListener(_loadCustomizations);
    _loadCustomizations();
  }

  @override
  void didUpdateWidget(AppFolderTile old) {
    super.didUpdateWidget(old);
    // Packages added or removed: fetch the new set (cached ones come back at once).
    if (_packagesOf(old.tile).join(',') != _packages.join(',')) _loadApps();
  }

  void _loadApps() => _service.loadPackages(_packages).then((apps) {
    if (mounted) setState(() => _apps = apps);
  });

  @override
  void dispose() {
    InstalledAppsService.changes.removeListener(_loadApps);
    AppCustomizationsService.changes.removeListener(_loadCustomizations);
    super.dispose();
  }

  Future<void> _loadCustomizations() async {
    final loaded = await const AppCustomizationsService().load();
    if (mounted) setState(() => _customizations = loaded);
  }

  static List<String> _packagesOf(MySpaceTile tile) => (tile.data['packages'] as List).cast<String>();

  List<String> get _packages => _packagesOf(widget.tile);

  void _setPackages(List<String> packages) => widget.onChanged({'packages': packages});

  Future<void> _pickApp() async {
    // The picker needs every app; hidden ones aren't offered, nor ones already in the folder.
    final all = await _service.loadApps();
    if (!mounted) return;
    final available = _customizations.apply(all).where((a) => !_packages.contains(a.packageName)).toList();
    final picked = await showAppPicker(context, available);
    if (picked != null) _setPackages([..._packages, picked.packageName]);
  }

  void _remove(String packageName) => _setPackages(_packages.where((p) => p != packageName).toList());

  @override
  Widget build(BuildContext context) {
    final apps = _apps;
    final shown = apps == null ? null : _customizations.apply(apps, includeHidden: true);
    final selected = [
      for (final package in _packages)
        if (shown != null)
          for (final app in shown)
            if (app.packageName == package) app,
    ];
    final colors = Theme.of(context).colorScheme;

    return TileCard(
      label: (widget.tile.name ?? 'App Folder').toUpperCase(),
      icon: Icons.apps,
      // In edit mode the tile's own buttons sit in this corner.
      trailing: widget.editing
          ? null
          : IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _pickApp,
            ),
      child: apps == null
          ? Skeleton(
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < (_packages.isEmpty ? 1 : _packages.length); i++)
                    const SizedBox(
                      width: 64,
                      child: Column(children: [SkeletonBar(height: 40, circle: true), SizedBox(height: 6), SkeletonBar(width: 44, height: 8)]),
                    ),
                ],
              ),
            )
          : selected.isEmpty && !widget.editing
          ? Text('No apps yet — tap + to add some.', style: TextStyle(color: colors.onSurfaceVariant))
          : Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                for (final app in selected)
                  _AppShortcut(
                    app: app,
                    onTap: widget.editing ? null : () => launchApp(context, app),
                    onRemove: widget.editing ? () => _remove(app.packageName) : null,
                  ),
                if (widget.editing)
                  InkWell(
                    onTap: _pickApp,
                    child: SizedBox(
                      width: 64,
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colors.outline)),
                            child: const Icon(Icons.add, size: 22),
                          ),
                          const SizedBox(height: 4),
                          const Text('Add', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _AppShortcut extends StatelessWidget {
  const _AppShortcut({required this.app, this.onTap, this.onRemove});

  final AppInfo app;
  final VoidCallback? onTap;

  /// Shown as a badge on the icon (edit mode).
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    // No long-press here: it bubbles up to My Space's edit mode.
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AppIcon(icon: app.icon),
                if (onRemove != null)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        child: Icon(Icons.close, size: 14, color: Theme.of(context).colorScheme.surface),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
