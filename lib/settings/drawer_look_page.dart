import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../models/drawer_look.dart';
import '../search/drawer_apps_view.dart';
import '../services/app_customizations_service.dart';
import '../state/app_settings_scope.dart';
import '../widgets/segmented_toggle.dart';

/// Drawer look editor: list or grid, icon and label sizes, row height, and
/// section headers, with a live preview of the real drawer above the
/// controls, and Reset. Changes save as they're made.
class DrawerLookPage extends StatefulWidget {
  const DrawerLookPage({super.key});

  @override
  State<DrawerLookPage> createState() => _DrawerLookPageState();
}

class _DrawerLookPageState extends State<DrawerLookPage> {
  List<AppInfo> _sample = const [];

  @override
  void initState() {
    super.initState();
    loadCustomizedApps().then((apps) {
      if (mounted) setState(() => _sample = apps.take(10).toList());
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final look = settings.drawerLook;
    final stroke = settings.isDark ? Colors.white24 : Colors.black26;
    void update(DrawerLook next) => settings.setDrawerLook(next);
    const sizes = [
      (DrawerItemSize.none, Icons.block, 'None'),
      (DrawerItemSize.small, Icons.photo_size_select_small, 'S'),
      (DrawerItemSize.medium, Icons.photo_size_select_large, 'M'),
      (DrawerItemSize.large, Icons.photo_size_select_actual, 'L'),
    ];
    Widget labeled(String label, Widget control) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 17)),
          const SizedBox(width: 16),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: control),
          ),
        ],
      ),
    );
    final sections = <String, List<AppInfo>>{};
    for (final app in _sample) {
      (sections[app.name.isEmpty ? '#' : app.name[0].toUpperCase()] ??= []).add(app);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drawer look'),
        actions: [
          TextButton(
            onPressed: look == const DrawerLook() ? null : () => update(const DrawerLook()),
            child: const Text('Reset'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Live preview: the real drawer view with a few of your apps.
          Container(
            height: 260,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              border: Border.all(color: stroke),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: IgnorePointer(
              child: DrawerAppsView(
                sections: [for (final MapEntry(:key, :value) in sections.entries) (key: key, apps: value)],
                look: look,
                onLaunch: (_) {},
                showIndex: false,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                labeled(
                  'Layout',
                  SegmentedToggle<bool>(
                    value: look.grid,
                    onChanged: (grid) => update(look.copyWith(grid: grid)),
                    options: const [(false, Icons.view_list, 'List'), (true, Icons.grid_view, 'Grid')],
                  ),
                ),
                if (look.grid)
                  labeled(
                    'Columns',
                    SegmentedToggle<int>(
                      value: look.columns,
                      onChanged: (columns) => update(look.copyWith(columns: columns)),
                      options: [
                        for (var c = DrawerLook.minColumns; c <= DrawerLook.maxColumns; c++)
                          (c, Icons.view_column, '$c'),
                      ],
                    ),
                  )
                else
                  labeled(
                    'Row height',
                    SegmentedToggle<DrawerRowHeight>(
                      value: look.rowHeight,
                      onChanged: (h) => update(look.copyWith(rowHeight: h)),
                      options: const [
                        (DrawerRowHeight.compact, Icons.density_small, 'Compact'),
                        (DrawerRowHeight.normal, Icons.density_medium, 'Normal'),
                        (DrawerRowHeight.roomy, Icons.density_large, 'Roomy'),
                      ],
                    ),
                  ),
                labeled(
                  'Icons',
                  SegmentedToggle<DrawerItemSize>(
                    value: look.iconSize,
                    // Never both hidden: something has to show each app.
                    onChanged: (size) => update(
                      look.copyWith(
                        iconSize: size,
                        labelSize: size == DrawerItemSize.none && look.labelSize == DrawerItemSize.none
                            ? DrawerItemSize.medium
                            : null,
                      ),
                    ),
                    options: sizes,
                  ),
                ),
                labeled(
                  'Labels',
                  SegmentedToggle<DrawerItemSize>(
                    value: look.labelSize,
                    onChanged: (size) => update(
                      look.copyWith(
                        labelSize: size,
                        iconSize: size == DrawerItemSize.none && look.iconSize == DrawerItemSize.none
                            ? DrawerItemSize.medium
                            : null,
                      ),
                    ),
                    options: sizes,
                  ),
                ),
                for (final (title, value, onChanged) in [
                  ('Labels on two lines', look.twoLineLabels, (bool v) => update(look.copyWith(twoLineLabels: v))),
                  ('A-Z section headers', look.headers, (bool v) => update(look.copyWith(headers: v))),
                ])
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(title, style: const TextStyle(fontSize: 17)),
                    value: value,
                    activeThumbColor: settings.isDark ? Colors.black : Colors.white,
                    activeTrackColor: settings.isDark ? Colors.white : Colors.black,
                    onChanged: onChanged,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
