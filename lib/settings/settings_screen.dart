import 'package:flutter/material.dart';

import '../models/home_layout_mode.dart';
import '../onboarding/onboarding_flow.dart';
import '../onboarding/wallpaper_picker.dart';
import '../search/app_search.dart';
import '../search/app_search_bar.dart';
import '../state/app_settings.dart';
import '../state/app_settings_scope.dart';
import '../widgets/segmented_toggle.dart';

/// Opens Settings as a near-full-height bottom sheet over the launcher,
/// matching the mockup (drag handle, dimmed status bar behind it).
Future<void> showSettingsScreen(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => const SettingsScreen(),
  );
}

/// One searchable settings entry, shown as a row inside its [group].
/// [onTap] is null for rows whose destination a later task builds.
typedef _SettingsEntry = ({String group, IconData icon, String title, void Function(BuildContext)? onTap});

/// Every entry the sheet can show, in display order. Later Phase 5 tasks
/// add Toggles / Mind Space / Restart entries here so search covers them.
const _entries = <_SettingsEntry>[
  (group: 'Settings', icon: Icons.palette_outlined, title: 'Appearance', onTap: _showAppearance),
  (group: 'Settings', icon: Icons.contrast, title: 'Launcher Settings', onTap: _showLauncherSettings),
  (group: 'Settings', icon: Icons.settings_outlined, title: 'System Settings', onTap: null),
];

/// Settings sheet: a search field over grouped, outlined rows with hairline
/// dividers. Groups are filled in by Phase 5 tasks 3–7 (Appearance,
/// Launcher, System, Mind Space quick actions, Restart Launcher).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppSettingsScope.of(context).isDark;
    final query = _query.text.trim().toLowerCase();
    final matches = _entries.where((e) => e.title.toLowerCase().contains(query));
    final groups = <String, List<_SettingsEntry>>{};
    for (final entry in matches) {
      (groups[entry.group] ??= []).add(entry);
    }

    return Padding(
      // Keep the search field above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          AppSearchBar(
            controller: _query,
            hintText: 'Search settings, modes, tools…',
            showSortControl: false,
            sortMode: AppSortMode.alphabetical,
            onSortModeChanged: (_) {},
          ),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Text(
                'No settings match "${_query.text.trim()}"',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          for (final MapEntry(key: group, value: entries) in groups.entries) ...[
            _SectionHeader(group, isDark: isDark),
            _SettingsGroup(
              isDark: isDark,
              rows: [for (final e in entries) _SettingsRow(icon: e.icon, title: e.title, onTap: e.onTap)],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, {required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
      child: Text(
        label,
        style: TextStyle(fontSize: 18, letterSpacing: 1.5, color: isDark ? Colors.white60 : Colors.black54),
      ),
    );
  }
}

/// One outlined container holding several rows separated by hairlines.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.rows, required this.isDark});

  final List<Widget> rows;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final stroke = isDark ? Colors.white24 : Colors.black26;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: stroke),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 20, endIndent: 20, color: stroke),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final void Function(BuildContext)? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontSize: 18, letterSpacing: 0.5)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap == null ? null : () => onTap!(context),
    );
  }
}

/// Opens a short sub-sheet titled [title] whose rows are rebuilt from the
/// live [AppSettings] each time it changes.
void _showSubSheet(BuildContext context, String title, List<Widget> Function(BuildContext, AppSettings) rows) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) {
      final settings = AppSettingsScope.of(context);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title, isDark: settings.isDark),
            ...rows(context, settings),
          ],
        ),
      );
    },
  );
}

/// A sub-sheet row: label on the left, control on the right.
Widget _labeled(String label, Widget control) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 18, letterSpacing: 0.5))),
        control,
      ],
    ),
  );
}

/// Appearance: the onboarding Light/Dark toggle, bound to the same
/// [AppSettings.isDark] so both places stay in sync.
void _showAppearance(BuildContext context) {
  _showSubSheet(
    context,
    'Appearance',
    (context, settings) => [
      _labeled(
        'Theme',
        SegmentedToggle<bool>(
          value: settings.isDark,
          onChanged: settings.setDark,
          options: const [(false, Icons.wb_sunny_outlined, 'Light'), (true, Icons.nightlight_round, 'Dark')],
        ),
      ),
    ],
  );
}

/// Launcher Settings: home layout, wallpaper, and re-running onboarding,
/// reusing the onboarding Customize step's controls.
void _showLauncherSettings(BuildContext context) {
  _showSubSheet(
    context,
    'Launcher Settings',
    (context, settings) => [
      _labeled(
        'Layout',
        SegmentedToggle<HomeLayoutMode>(
          value: settings.layoutMode,
          onChanged: settings.setLayoutMode,
          options: const [
            (HomeLayoutMode.classic, Icons.dashboard_outlined, 'Classic'),
            (HomeLayoutMode.minimal, Icons.short_text, 'Minimal'),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Text(
        settings.isDark ? 'Wallpaper (shown in light theme)' : 'Wallpaper',
        style: const TextStyle(fontSize: 18, letterSpacing: 0.5),
      ),
      const SizedBox(height: 12),
      WallpaperPicker(
        colors: wallpaperPresets,
        selectedIndex: settings.wallpaperIndex,
        onSelected: settings.setWallpaperIndex,
      ),
      const SizedBox(height: 16),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.replay),
        title: const Text('Re-run onboarding', style: TextStyle(fontSize: 18, letterSpacing: 0.5)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // Close both sheets, then show onboarding over the shell; it
          // pops itself when finished (the completion flag stays set).
          final navigator = Navigator.of(context);
          navigator.popUntil((route) => route.isFirst);
          navigator.push(
            MaterialPageRoute<void>(
              builder: (context) => OnboardingFlow(onFinished: () => Navigator.of(context).pop()),
            ),
          );
        },
      ),
    ],
  );
}
