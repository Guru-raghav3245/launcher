import 'package:installed_apps/app_info.dart';

/// Sort applied on top of a (possibly filtered) app list.
enum AppSortMode { alphabetical, recentlyInstalled }

/// Filters [apps] by [query] (case-insensitive substring of the app name)
/// and sorts the result per [sortMode]. Used by the App Drawer's search and
/// the app pickers.
List<AppInfo> filterAndSortApps(
  List<AppInfo> apps, {
  required String query,
  required AppSortMode sortMode,
}) {
  final trimmed = query.trim().toLowerCase();
  final filtered = trimmed.isEmpty
      ? apps
      : apps.where((app) => app.name.toLowerCase().contains(trimmed)).toList();

  final sorted = [...filtered];
  switch (sortMode) {
    case AppSortMode.alphabetical:
      sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case AppSortMode.recentlyInstalled:
      sorted.sort((a, b) => b.installedTimestamp.compareTo(a.installedTimestamp));
  }
  return sorted;
}
