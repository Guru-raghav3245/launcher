import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../search/app_menu_sheet.dart';
import '../search/app_result_row.dart';
import '../search/app_search.dart';
import '../search/app_search_bar.dart';
import '../search/visible_apps.dart';
import '../services/installed_apps_service.dart';
import '../state/app_settings.dart';
import '../state/app_settings_scope.dart';
import '../widgets/launch_app.dart';

const _headerHeight = 32.0;
const _recentKey = 'Recent';
const _itemHeight = 64.0;

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

                  if (showSections) {
                    final byPackage = {for (final app in apps) app.packageName: app};
                    final hideUnused = settings.drawerOption(DrawerOption.hideUnusedApps);
                    return _DrawerList(
                      // Unused apps leave the list but stay searchable.
                      apps: [
                        for (final app in apps)
                          if (!hideUnused || !isUnused(app)) app,
                      ],
                      pinned: [for (final p in pinned) ?byPackage[p]],
                      recent: settings.drawerOption(DrawerOption.recentAppsOnTop) ? recentApps(visible) : const [],
                      scrollController: _scrollController,
                      onLaunch: (app) => launchApp(context, app),
                      onMenu: openMenu,
                    );
                  }
                  return _FlatList(apps: apps, onLaunch: (app) => launchApp(context, app), onMenu: openMenu);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlatList extends StatelessWidget {
  const _FlatList({required this.apps, required this.onLaunch, required this.onMenu});

  final List<AppInfo> apps;
  final ValueChanged<AppInfo> onLaunch;
  final ValueChanged<AppInfo> onMenu;

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) {
      return const Center(child: Text('No apps found', style: TextStyle(color: Colors.black54)));
    }
    return ListView.builder(
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        return AppResultRow(app: app, onTap: () => onLaunch(app), onLongPress: () => onMenu(app));
      },
    );
  }
}

class _DrawerList extends StatelessWidget {
  const _DrawerList({
    required this.apps,
    required this.pinned,
    required this.recent,
    required this.scrollController,
    required this.onLaunch,
    required this.onMenu,
  });

  final List<AppInfo> apps;

  /// Shown first, under ★, in pin order (they stay in their letter too).
  final List<AppInfo> pinned;

  /// Shown next, under Recent, most recent first (also still in their letter).
  final List<AppInfo> recent;
  final ScrollController scrollController;
  final ValueChanged<AppInfo> onLaunch;
  final ValueChanged<AppInfo> onMenu;

  @override
  Widget build(BuildContext context) {
    // Flatten apps into a [header, app, app, ..., header, app, ...] list,
    // tracking each section's pixel offset so the index strip can jump to
    // it directly (rows have a fixed height, so this is an exact O(1) map
    // rather than measuring the list at scroll time).
    final flatItems = <Object>[];
    final sectionOffsets = <String, double>{};
    var runningHeight = 0.0;
    for (final (key, app) in [
      for (final app in pinned) ('★', app),
      for (final app in recent) (_recentKey, app),
      for (final app in apps) (_sectionKey(app.name), app),
    ]) {
      if (!sectionOffsets.containsKey(key)) {
        sectionOffsets[key] = runningHeight;
        flatItems.add(key);
        runningHeight += _headerHeight;
      }
      flatItems.add(app);
      runningHeight += _itemHeight;
    }
    final letters = sectionOffsets.keys.toList();

    return Stack(
      children: [
        ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.only(right: 28),
          itemCount: flatItems.length,
          itemBuilder: (context, index) {
            final item = flatItems[index];
            if (item is String) return _SectionHeader(letter: item);
            final app = item as AppInfo;
            return AppResultRow(app: app, onTap: () => onLaunch(app), onLongPress: () => onMenu(app));
          },
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: _FastScrollIndex(
            letters: letters,
            onLetterSelected: (letter) {
              final target = sectionOffsets[letter]!;
              final maxScroll = scrollController.position.maxScrollExtent;
              scrollController.jumpTo(target.clamp(0, maxScroll));
            },
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _headerHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 20),
      child: Text(
        letter,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
      ),
    );
  }
}

/// A-Z/#/★-style side strip: tap or drag to jump the list to a section.
class _FastScrollIndex extends StatelessWidget {
  const _FastScrollIndex({required this.letters, required this.onLetterSelected});

  final List<String> letters;
  final ValueChanged<String> onLetterSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      child: Builder(
        builder: (indexContext) {
          void handlePointer(Offset globalPosition) {
            final box = indexContext.findRenderObject() as RenderBox;
            final local = box.globalToLocal(globalPosition);
            final index = (local.dy / box.size.height * letters.length)
                .floor()
                .clamp(0, letters.length - 1);
            onLetterSelected(letters[index]);
          }

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (d) => handlePointer(d.globalPosition),
            onVerticalDragUpdate: (d) => handlePointer(d.globalPosition),
            child: Column(
              children: [
                for (final letter in letters)
                  Expanded(
                    child: Center(
                      child: Text(
                        letter == _recentKey ? '◷' : letter,
                        style: const TextStyle(fontSize: 10, color: Colors.black45),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
