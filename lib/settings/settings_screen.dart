import 'package:flutter/material.dart';

import '../search/app_search.dart';
import '../search/app_search_bar.dart';
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
  (group: 'Settings', icon: Icons.contrast, title: 'Launcher Settings', onTap: null),
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

/// Appearance sub-sheet: the onboarding Light/Dark toggle, bound to the
/// same [AppSettings.isDark] so both places stay in sync.
void _showAppearance(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) {
      final settings = AppSettingsScope.of(context);
      final isDark = settings.isDark;
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader('Appearance', isDark: isDark),
            Row(
              children: [
                const Expanded(child: Text('Theme', style: TextStyle(fontSize: 18, letterSpacing: 0.5))),
                SegmentedToggle<bool>(
                  value: isDark,
                  onChanged: settings.setDark,
                  options: const [
                    (false, Icons.wb_sunny_outlined, 'Light'),
                    (true, Icons.nightlight_round, 'Dark'),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
