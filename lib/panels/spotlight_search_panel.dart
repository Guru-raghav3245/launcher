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
  const SpotlightSearchPanel({super.key});

  @override
  State<SpotlightSearchPanel> createState() => _SpotlightSearchPanelState();
}

class _SpotlightSearchPanelState extends State<SpotlightSearchPanel> with ShowsVisibleApps {
  final _service = const InstalledAppsService();
  late final Future<List<AppInfo>> _appsFuture;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _appsFuture = _service.loadApps();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
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
              sortMode: AppSortMode.alphabetical,
              onSortModeChanged: (_) {},
              showSortControl: false,
              hintText: 'Spotlight search',
              // ponytail: no autofocus — this panel is mounted (offscreen)
              // as soon as the app starts since PageView builds all pages
              // eagerly, so autofocus would pop the keyboard on launch.
              // Focus on visibility-change would need page-index listening;
              // tap-to-focus is simpler and matches the App Drawer's search.
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
                    return const Center(
                      child: Text('Type to search apps', style: TextStyle(color: Colors.black45)),
                    );
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
