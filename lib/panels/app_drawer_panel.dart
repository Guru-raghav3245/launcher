import '../widgets/skeleton.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../search/app_cards.dart';
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

/// The search + apps screen (swipe up from Home; Spotlight was merged in
/// here in Phase 12 task 7): search with the keyboard up, the recent apps
/// as cards, then the alphabetical list with its fast-scroll index. Typing
/// shows every match, most recently used first, and Enter opens the top one.
class AppDrawerPanel extends StatefulWidget {
  const AppDrawerPanel({super.key, this.shown, this.onClose});

  /// True while this screen is the page on screen (from the shell).
  final ValueListenable<bool>? shown;

  /// The search bar's ✕ (with nothing typed): back to Home.
  final VoidCallback? onClose;

  @override
  State<AppDrawerPanel> createState() => _AppDrawerPanelState();
}

class _AppDrawerPanelState extends State<AppDrawerPanel> with ShowsVisibleApps {
  final _service = const InstalledAppsService();
  late Future<List<AppInfo>> _appsFuture;
  List<AppInfo>? _apps;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  AppSortMode _sortMode = AppSortMode.alphabetical;

  @override
  void initState() {
    super.initState();
    _appsFuture = _fetchApps();
    InstalledAppsService.changes.addListener(_reloadApps);
    _searchController.addListener(() {
      setState(() {});
      openIfSingleResult(_searchController, _apps);
    });
    _searchFocus.addListener(() => setState(() {}));
    widget.shown?.addListener(_onShownChanged);
  }

  /// Keyboard up on arrival (not via autofocus: every page is built at
  /// launch); on leaving, keyboard down and the search cleared, so each
  /// visit starts fresh.
  void _onShownChanged() {
    if (widget.shown!.value) {
      _searchFocus.requestFocus();
    } else {
      _searchFocus.unfocus();
      _searchController.clear();
    }
  }

  /// The matches for [query], most recently used first: the top one is
  /// what Enter opens.
  List<AppInfo> _matches(List<AppInfo> apps, String query) =>
      byRecency(filterAndSortApps(visibleApps(apps), query: query, sortMode: AppSortMode.alphabetical));

  Future<List<AppInfo>> _fetchApps() => _service.loadApps()..then((apps) => _apps = apps);

  void _reloadApps() => setState(() => _appsFuture = _fetchApps());

  @override
  void dispose() {
    InstalledAppsService.changes.removeListener(_reloadApps);
    widget.shown?.removeListener(_onShownChanged);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  var _pulledDown = false;

  bool _onListScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification) _pulledDown = false;
    if (notification is OverscrollNotification &&
        notification.overscroll < 0 &&
        notification.dragDetails != null &&
        !_pulledDown) {
      _pulledDown = true;
      _searchFocus.unfocus();
      widget.onClose?.call();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                AppSearchBar(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  sortMode: _sortMode,
                  onSortModeChanged: (mode) => setState(() => _sortMode = mode),
                  onClose: widget.onClose,
                  onSubmitted: (query) {
                    final first = _apps == null || query.trim().isEmpty ? null : _matches(_apps!, query).firstOrNull;
                    if (first != null) launchApp(context, first);
                  },
                ),
                // Before typing, the recent apps as cards (none without usage data).
                if (_searchController.text.trim().isEmpty && _apps != null)
                  if (recentApps(visibleApps(_apps!)) case final recent when recent.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    AppCards(apps: recent, onOpen: (app) => launchApp(context, app)),
                  ],
                const SizedBox(height: 23),
                Expanded(
                  // The list takes every vertical drag, so the shell's pager
                  // never sees a pull down. Like the original, pulling down
                  // past the top of the list goes back Home, once per drag.
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onListScroll,
                    child: FutureBuilder<List<AppInfo>>(
                      future: _appsFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const AppListSkeleton();
                        }
                        final settings = AppSettingsScope.of(context);
                        final query = _searchController.text;
                        final typing = query.trim().isNotEmpty;
                        final showSections = !typing && _sortMode == AppSortMode.alphabetical;
                        final visible = visibleApps(snapshot.data!);
                        final apps = typing
                            ? _matches(snapshot.data!, query)
                            : filterAndSortApps(visible, query: query, sortMode: _sortMode);

                        final pinned = customizations.pinned;
                        void openMenu(AppInfo app) =>
                            showAppMenu(context, app, pinned: pinned.contains(app.packageName));
                        void open(AppInfo app) => launchApp(context, app);

                        if (!showSections) {
                          // Search results or another sort: one plain section.
                          return DrawerAppsView(
                            sections: [(key: '', apps: apps)],
                            look: settings.drawerLook,
                            onLaunch: open,
                            onMenu: openMenu,
                            showIndex: false,
                            highlightFirst: typing,
                          );
                        }
                        final byPackage = {for (final app in apps) app.packageName: app};
                        final hideUnused = settings.drawerOption(DrawerOption.hideUnusedApps);
                        // Pinned under ★ first (they stay under their letter too);
                        // unused apps leave the list but stay searchable.
                        final letters = <String, List<AppInfo>>{};
                        for (final app in apps) {
                          if (!hideUnused || !isUnused(app)) (letters[_sectionKey(app.name)] ??= []).add(app);
                        }
                        return DrawerAppsView(
                          sections: [
                            (key: '★', apps: [for (final p in pinned) ?byPackage[p]]),
                            for (final MapEntry(:key, :value) in letters.entries) (key: key, apps: value),
                          ],
                          look: settings.drawerLook,
                          scrollController: _scrollController,
                          onLaunch: open,
                          onMenu: openMenu,
                          // Squeezed above the keyboard the letters overlap, so it's
                          // hidden while search has focus (the keyboard is up then;
                          // the shell's Scaffold hides its height from viewInsets).
                          // Dragging the list drops the keyboard and brings it back.
                          showIndex: !_searchFocus.hasFocus,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // The original's keyboard button: raises the search keyboard.
          if (!_searchFocus.hasFocus)
            Positioned(
              right: 14,
              bottom: 32,
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _searchFocus.requestFocus,
                  child: SizedBox.square(
                    dimension: 60,
                    child: Icon(Icons.keyboard_outlined, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
