import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../../models/my_space_tile.dart';
import '../../search/app_picker_sheet.dart';
import '../../search/app_result_row.dart';
import '../../services/app_customizations_service.dart';
import '../../services/installed_apps_service.dart';
import '../../widgets/launch_app.dart';
import '../tile_card.dart';

/// App Folder tile: a grid of shortcuts to apps the user picked. Packages
/// are stored as `{"packages": List<String>}` in [MySpaceTile.data]; icons
/// and names are looked up live from [InstalledAppsService] (Phase 1 task 5).
class AppFolderTile extends StatefulWidget {
  const AppFolderTile({super.key, required this.tile, required this.onChanged});

  final MySpaceTile tile;
  final ValueChanged<Map<String, dynamic>> onChanged;

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
    _service.loadApps().then((apps) {
      if (mounted) setState(() => _apps = apps);
    });
    AppCustomizationsService.changes.addListener(_loadCustomizations);
    _loadCustomizations();
  }

  @override
  void dispose() {
    AppCustomizationsService.changes.removeListener(_loadCustomizations);
    super.dispose();
  }

  Future<void> _loadCustomizations() async {
    final loaded = await const AppCustomizationsService().load();
    if (mounted) setState(() => _customizations = loaded);
  }

  List<String> get _packages => (widget.tile.data['packages'] as List).cast<String>();

  void _setPackages(List<String> packages) => widget.onChanged({'packages': packages});

  Future<void> _pickApp() async {
    final apps = _apps;
    if (apps == null) return;
    // Hidden apps aren't offered, but ones already in the folder stay.
    final available = _customizations.apply(apps).where((a) => !_packages.contains(a.packageName)).toList();
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

    return TileCard(
      label: 'APP FOLDER',
      icon: Icons.apps,
      trailing: IconButton(
        icon: const Icon(Icons.add_circle_outline, size: 20),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: apps == null ? null : _pickApp,
      ),
      child: selected.isEmpty
          ? Text('No apps yet — tap + to add some.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
          : Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                for (final app in selected)
                  _AppShortcut(
                    app: app,
                    onTap: () => launchApp(context, app),
                    onLongPress: () => _remove(app.packageName),
                  ),
              ],
            ),
    );
  }
}

class _AppShortcut extends StatelessWidget {
  const _AppShortcut({required this.app, required this.onTap, required this.onLongPress});

  final AppInfo app;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            AppIcon(icon: app.icon),
            const SizedBox(height: 4),
            Text(
              app.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
