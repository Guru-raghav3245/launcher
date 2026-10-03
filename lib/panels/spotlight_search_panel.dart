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
              sortMode: AppSortMode.alphabetical,
              onSortModeChanged: (_) {},
              showSortControl: false,
              hintText: 'Spotlight search',
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
                  if (query.trim().isEmpty) {
                    final recent = recentApps(visibleApps(snapshot.data!));
                    if (recent.isEmpty) {
                      return const Center(
                        child: Text('Type to search apps', style: TextStyle(color: Colors.black45)),
                      );
                    }
                    return _RecentRow(apps: recent, onOpen: (app) => launchApp(context, app));
                  }
                  final results = filterAndSortApps(
                    visibleApps(snapshot.data!),
                    query: query,
                    sortMode: AppSortMode.alphabetical,
                  );
                  if (results.isEmpty) {
                    return const Center(
                      child: Text('No apps found', style: TextStyle(color: Colors.black45)),
                    );
                  }
                  return ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final app = results[index];
                      return AppResultRow(app: app, onTap: () => launchApp(context, app));
                    },
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

/// Spotlight's recent apps (from usage stats) while nothing is typed.
class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.apps, required this.onOpen});

  final List<AppInfo> apps;
  final ValueChanged<AppInfo> onOpen;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54;
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent', style: TextStyle(fontSize: 13, color: secondary)),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final app in apps)
                  Expanded(
                    child: InkWell(
                      onTap: () => onOpen(app),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            AppIcon(icon: app.icon),
                            const SizedBox(height: 6),
                            Text(
                              app.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
