import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../search/app_menu_sheet.dart';
import '../search/app_search.dart';
import '../search/app_search_bar.dart';
import '../search/drawer_apps_view.dart';
import '../search/visible_apps.dart';
import '../services/installed_apps_service.dart';
import '../state/app_settings.dart';
import '../state/app_settings_scope.dart';
import '../widgets/launch_app.dart';

/// Groups a name under its uppercase first letter, or '#' for anything
/// that doesn't start with A-Z (digits, symbols, emoji, etc.).
String _sectionKey(String name) {
  if (name.isEmpty) return '#';
  final letter = name[0].toUpperCase();
  return RegExp(r'^[A-Z]$').hasMatch(letter) ? letter : '#';
}

/// App Drawer panel: alphabetical installed-app list with a draggable
/// fast-scroll index. Search (task 7) layers on top of this list.
class AppDrawerPanel extends StatefulWidget {
  const AppDrawerPanel({super.key, this.shown});

  /// True while the drawer is the page on screen (from the shell).
  final ValueListenable<bool>? shown;

  @override
  State<AppDrawerPanel> createState() => _AppDrawerPanelState();
}

class _AppDrawerPanelState extends State<AppDrawerPanel> with ShowsVisibleApps {
  final _service = const InstalledAppsService();
  late final Future<List<AppInfo>> _appsFuture;
  List<AppInfo>? _apps;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  AppSortMode _sortMode = AppSortMode.alphabetical;

  @override
  void initState() {
    super.initState();
    _appsFuture = _service.loadApps()..then((apps) => _apps = apps);
    _searchController.addListener(() {
      setState(() {});
      openIfSingleResult(_searchController, _apps);
    });
    widget.shown?.addListener(_onShownChanged);
  }

  /// Keyboard up on arrival if the option is on; always down on leaving.
  void _onShownChanged() {
    if (!widget.shown!.value) {
      _searchFocus.unfocus();
    } else if (AppSettingsScope.of(context).drawerOption(DrawerOption.keyboardOnOpen)) {
      _searchFocus.requestFocus();
    }
  }

  @override
  void dispose() {
    widget.shown?.removeListener(_onShownChanged);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            AppSearchBar(
              controller: _searchController,
              focusNode: _searchFocus,
              sortMode: _sortMode,
              onSortModeChanged: (mode) => setState(() => _sortMode = mode),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<AppInfo>>(
                future: _appsFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final settings = AppSettingsScope.of(context);
                  final query = _searchController.text;
                  final showSections = query.trim().isEmpty && _sortMode == AppSortMode.alphabetical;
                  final visible = visibleApps(snapshot.data!);
                  final apps = filterAndSortApps(
                    visible,
                    query: query,
                    sortMode: _sortMode,
                  );

                  final pinned = customizations.pinned;
                  void openMenu(AppInfo app) => showAppMenu(context, app, pinned: pinned.contains(app.packageName));
                  void open(AppInfo app) => launchApp(context, app);

                  if (!showSections) {
                    // Search results or another sort: one plain section.
                    return DrawerAppsView(
                      sections: [(key: '', apps: apps)],
                      look: settings.drawerLook,
                      onLaunch: open,
                      onMenu: openMenu,
                      showIndex: false,
                    );
                  }
                  final byPackage = {for (final app in apps) app.packageName: app};
                  final hideUnused = settings.drawerOption(DrawerOption.hideUnusedApps);
                  // Pinned under ★ and recent under ◷ first (they stay under
                  // their letter too); unused apps leave the list but stay
                  // searchable.
                  final letters = <String, List<AppInfo>>{};
                  for (final app in apps) {
                    if (!hideUnused || !isUnused(app)) (letters[_sectionKey(app.name)] ??= []).add(app);
                  }
                  return DrawerAppsView(
                    sections: [
                      (key: '★', apps: [for (final p in pinned) ?byPackage[p]]),
                      (
                        key: recentSectionKey,
                        apps: settings.drawerOption(DrawerOption.recentAppsOnTop) ? recentApps(visible) : const [],
                      ),
                      for (final MapEntry(:key, :value) in letters.entries) (key: key, apps: value),
                    ],
                    look: settings.drawerLook,
                    scrollController: _scrollController,
                    onLaunch: open,
                    onMenu: openMenu,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
