import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../search/app_result_row.dart';
import '../search/app_search.dart';
import '../search/app_search_bar.dart';
import '../services/focus_mode_service.dart';
import '../services/installed_apps_service.dart';

/// Picker for the apps Focus Mode lets through. Modeled on the App Folder
/// tile's app picker: search + sort over installed apps, one checkbox each.
Future<void> showEssentialAppsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => const _EssentialAppsSheet(),
  );
}

class _EssentialAppsSheet extends StatefulWidget {
  const _EssentialAppsSheet();

  @override
  State<_EssentialAppsSheet> createState() => _EssentialAppsSheetState();
}

class _EssentialAppsSheetState extends State<_EssentialAppsSheet> {
  final _focusMode = const FocusModeService();
  final _controller = TextEditingController();
  var _sortMode = AppSortMode.alphabetical;
  List<AppInfo>? _apps;
  Set<String> _essentials = {};

  /// Essentials as of opening the sheet. These sort to the top; the order
  /// is fixed while the sheet is open so rows don't jump when toggled.
  Set<String> _pinned = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (apps, essentials) = await (const InstalledAppsService().loadApps(), _focusMode.essentials()).wait;
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _essentials = essentials;
      _pinned = {...essentials};
    });
  }

  Future<void> _toggle(String packageName, bool essential) async {
    setState(() => essential ? _essentials.add(packageName) : _essentials.remove(packageName));
    await _focusMode.setEssential(packageName, essential);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apps = _apps;
    // Selected = solid ink (no accent color), per DESIGN_LANGUAGE.md.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Essential apps',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'These still open while Focus Mode is on.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              AppSearchBar(
                controller: _controller,
                sortMode: _sortMode,
                onSortModeChanged: (mode) => setState(() => _sortMode = mode),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: apps == null
                    ? const Center(child: CircularProgressIndicator())
                    : ListenableBuilder(
                        listenable: _controller,
                        builder: (context, _) {
                          final results = filterAndSortApps(apps, query: _controller.text, sortMode: _sortMode);
                          final ordered = [
                            ...results.where((app) => _pinned.contains(app.packageName)),
                            ...results.where((app) => !_pinned.contains(app.packageName)),
                          ];
                          return ListView.builder(
                            itemCount: ordered.length,
                            itemBuilder: (context, index) {
                              final app = ordered[index];
                              final essential = _essentials.contains(app.packageName);
                              return AppResultRow(
                                app: app,
                                onTap: () => _toggle(app.packageName, !essential),
                                trailing: Checkbox(
                                  value: essential,
                                  activeColor: isDark ? Colors.white : Colors.black,
                                  checkColor: isDark ? Colors.black : Colors.white,
                                  onChanged: (value) => _toggle(app.packageName, value ?? false),
                                ),
                              );
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
