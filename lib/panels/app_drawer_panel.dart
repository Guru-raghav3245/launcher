import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../search/app_result_row.dart';
import '../search/app_search.dart';
import '../search/app_search_bar.dart';
import '../search/visible_apps.dart';
import '../services/installed_apps_service.dart';
import '../widgets/launch_app.dart';

const _headerHeight = 32.0;
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
  const AppDrawerPanel({super.key});

  @override
  State<AppDrawerPanel> createState() => _AppDrawerPanelState();
}

class _AppDrawerPanelState extends State<AppDrawerPanel> with ShowsVisibleApps {
  final _service = const InstalledAppsService();
  late final Future<List<AppInfo>> _appsFuture;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  AppSortMode _sortMode = AppSortMode.alphabetical;

  @override
  void initState() {
    super.initState();
    _appsFuture = _service.loadApps();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
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
                  final query = _searchController.text;
                  final showSections = query.trim().isEmpty && _sortMode == AppSortMode.alphabetical;
                  final apps = filterAndSortApps(
                    visibleApps(snapshot.data!),
                    query: query,
                    sortMode: _sortMode,
                  );

                  if (showSections) {
                    return _DrawerList(
                      apps: apps,
                      scrollController: _scrollController,
                      onLaunch: (app) => launchApp(context, app),
                    );
                  }
                  return _FlatList(apps: apps, onLaunch: (app) => launchApp(context, app));
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
  const _FlatList({required this.apps, required this.onLaunch});

  final List<AppInfo> apps;
  final ValueChanged<AppInfo> onLaunch;

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) {
      return const Center(child: Text('No apps found', style: TextStyle(color: Colors.black54)));
    }
    return ListView.builder(
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        return AppResultRow(app: app, onTap: () => onLaunch(app));
      },
    );
  }
}

class _DrawerList extends StatelessWidget {
  const _DrawerList({
    required this.apps,
    required this.scrollController,
    required this.onLaunch,
  });

  final List<AppInfo> apps;
  final ScrollController scrollController;
  final ValueChanged<AppInfo> onLaunch;

  @override
  Widget build(BuildContext context) {
    // Flatten apps into a [header, app, app, ..., header, app, ...] list,
    // tracking each section's pixel offset so the index strip can jump to
    // it directly (rows have a fixed height, so this is an exact O(1) map
    // rather than measuring the list at scroll time).
    final flatItems = <Object>[];
    final sectionOffsets = <String, double>{};
    var runningHeight = 0.0;
    for (final app in apps) {
      final key = _sectionKey(app.name);
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
            return AppResultRow(app: item as AppInfo, onTap: () => onLaunch(item));
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
                        letter,
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
