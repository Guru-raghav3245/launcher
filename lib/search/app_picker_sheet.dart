import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import 'app_result_row.dart';
import 'app_search.dart';
import 'app_search_bar.dart';

/// Bottom sheet listing [apps] with search, resolving to the one tapped (or
/// null if dismissed). Mirrors the App Drawer's search UI (Phase 1 task 7)
/// since it's browsing the same installed-apps list. Used by the App Folder
/// tile and Mindful Break.
Future<AppInfo?> showAppPicker(BuildContext context, List<AppInfo> apps, {String title = 'Add App'}) {
  return showModalBottomSheet<AppInfo>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => _AppPickerSheet(apps: apps, title: title),
  );
}

class _AppPickerSheet extends StatefulWidget {
  const _AppPickerSheet({required this.apps, required this.title});

  final List<AppInfo> apps;
  final String title;

  @override
  State<_AppPickerSheet> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends State<_AppPickerSheet> {
  final _controller = TextEditingController();
  var _sortMode = AppSortMode.alphabetical;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              AppSearchBar(
                controller: _controller,
                sortMode: _sortMode,
                onSortModeChanged: (mode) => setState(() => _sortMode = mode),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) {
                    final results = filterAndSortApps(
                      widget.apps,
                      query: _controller.text,
                      sortMode: _sortMode,
                    );
                    return ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final app = results[index];
                        return AppResultRow(app: app, onTap: () => Navigator.of(context).pop(app));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
