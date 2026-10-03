import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../search/app_result_row.dart';
import '../search/app_search.dart';
import '../search/app_search_bar.dart';
import '../search/visible_apps.dart';
import '../services/installed_apps_service.dart';
import '../widgets/launch_app.dart';

/// Spotlight Search panel (swipe down from Home): a search-first overlay
/// for opening an app "with intention" — no browsing/sectioned list, just
/// type and tap. Reuses the App Drawer's (task 7) search/filter logic.
class SpotlightSearchPanel extends StatefulWidget {
  const SpotlightSearchPanel({super.key, this.shown});

  /// True while Spotlight is the page on screen (from the shell).
  final ValueListenable<bool>? shown;

  @override
  State<SpotlightSearchPanel> createState() => _SpotlightSearchPanelState();
}

class _SpotlightSearchPanelState extends State<SpotlightSearchPanel> with ShowsVisibleApps {
  final _service = const InstalledAppsService();
  late final Future<List<AppInfo>> _appsFuture;
  List<AppInfo>? _apps;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

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

  // Spotlight is for typing, so the keyboard comes up as it arrives (not via
  // autofocus: every page is built at launch) and goes down as it leaves.
  void _onShownChanged() => widget.shown!.value ? _searchFocus.requestFocus() : _searchFocus.unfocus();

  @override
  void dispose() {
    widget.shown?.removeListener(_onShownChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// What's shown: the four best matches for the query (most recently used
  /// first, like the original), or recent apps before typing.
  List<AppInfo> _shownApps(List<AppInfo> apps) {
    final query = _searchController.text;
    if (query.trim().isEmpty) return recentApps(visibleApps(apps));
    return byRecency(filterAndSortApps(visibleApps(apps), query: query, sortMode: AppSortMode.alphabetical))
        .take(4)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          children: [
            AppSearchBar(
              controller: _searchController,
              focusNode: _searchFocus,
              sortMode: AppSortMode.alphabetical,
              onSortModeChanged: (_) {},
              showSortControl: false,
              // Enter opens the outlined first card, as in the original.
              onSubmitted: (_) {
                final first = _apps == null ? null : _shownApps(_apps!).firstOrNull;
                if (first != null) launchApp(context, first);
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<AppInfo>>(
                future: _appsFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final apps = _shownApps(snapshot.data!);
                  if (apps.isEmpty) {
                    final typed = _searchController.text.trim().isNotEmpty;
                    return Center(
                      child: Text(
                        typed ? 'No apps found' : 'Type to search apps',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    );
                  }
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      child: _AppCards(apps: apps, onOpen: (app) => launchApp(context, app)),
                    ),
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

/// The original's Spotlight results: app cards four to a row in an outlined
/// box, the first outlined in ink as the one Enter opens.
class _AppCards extends StatelessWidget {
  const _AppCards({required this.apps, required this.onOpen});

  final List<AppInfo> apps;
  final ValueChanged<AppInfo> onOpen;

  static const _perRow = 4;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget card(int i) {
      final app = apps[i];
      return Material(
        color: colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: i == 0 ? BorderSide(color: colors.onSurface, width: 1.5) : BorderSide.none,
        ),
        child: InkWell(
          onTap: () => onOpen(app),
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: SizedBox(
            height: 88,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(icon: app.icon, size: 34),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    app.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var start = 0; start < apps.length; start += _perRow)
            Padding(
              padding: EdgeInsets.only(top: start == 0 ? 0 : 8),
              child: Row(
                children: [
                  for (var i = start; i < start + _perRow; i++) ...[
                    if (i > start) const SizedBox(width: 8),
                    Expanded(child: i < apps.length ? card(i) : const SizedBox.shrink()),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
