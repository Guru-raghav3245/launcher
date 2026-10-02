import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../services/installed_apps_service.dart';
import 'app_result_row.dart';
import 'app_search.dart';
import 'app_search_bar.dart';

/// Checkbox picker over installed apps, for any feature that keeps a set of
/// package names (Focus Mode's essential apps, Mindful Pause, ...). Modeled
/// on the App Folder tile's single-app picker: search + sort, one checkbox
/// per app. [load] reads the current selection; every toggle is saved
/// immediately through [onChanged], so there's no Save button.
Future<void> showAppMultiPicker(
  BuildContext context, {
  required String title,
  required String subtitle,
  required Future<Set<String>> Function() load,
  required Future<void> Function(String packageName, bool selected) onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => _AppMultiPickerSheet(title: title, subtitle: subtitle, load: load, onChanged: onChanged),
  );
}

class _AppMultiPickerSheet extends StatefulWidget {
  const _AppMultiPickerSheet({
    required this.title,
    required this.subtitle,
    required this.load,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final Future<Set<String>> Function() load;
  final Future<void> Function(String packageName, bool selected) onChanged;

  @override
  State<_AppMultiPickerSheet> createState() => _AppMultiPickerSheetState();
}

class _AppMultiPickerSheetState extends State<_AppMultiPickerSheet> {
  final _controller = TextEditingController();
  var _sortMode = AppSortMode.alphabetical;
  List<AppInfo>? _apps;
  Set<String> _selected = {};

  /// Selection as of opening the sheet. These sort to the top; the order
  /// is fixed while the sheet is open so rows don't jump when toggled.
  Set<String> _pinned = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (apps, selected) = await (const InstalledAppsService().loadApps(), widget.load()).wait;
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _selected = selected;
      _pinned = {...selected};
    });
  }

  Future<void> _toggle(String packageName, bool selected) async {
    setState(() => selected ? _selected.add(packageName) : _selected.remove(packageName));
    await widget.onChanged(packageName, selected);
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
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
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
                              final selected = _selected.contains(app.packageName);
                              return AppResultRow(
                                app: app,
                                onTap: () => _toggle(app.packageName, !selected),
                                trailing: Checkbox(
                                  value: selected,
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
