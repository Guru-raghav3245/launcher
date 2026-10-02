import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../models/home_layout_mode.dart';
import '../onboarding/onboarding_flow.dart';
import '../onboarding/wallpaper_picker.dart';
import '../panels/mind_space_panel.dart';
import '../search/app_search.dart';
import '../services/launcher_role_service.dart';
import 'essential_apps_sheet.dart';
import '../services/usage_stats_service.dart';
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
/// add their entries here so search covers them; the Mind Space section
/// isn't a row list, so it's matched by [_mindSpaceTerms] instead.
/// Search terms that keep the Mind Space quick-actions section visible
/// (the Restart Launcher footer is matched the same way, by its label).
const _mindSpaceTerms = ['mind space', 'pause', 'timer', 'focus mode'];

/// Restarts the launcher process (see MainActivity.kt's `yinyang.launcher/app`).
const _appChannel = MethodChannel('yinyang.launcher/app');

const _entries = <_SettingsEntry>[
  (group: 'Settings', icon: Icons.palette_outlined, title: 'Appearance', onTap: _showAppearance),
  (group: 'Settings', icon: Icons.contrast, title: 'Launcher Settings', onTap: _showLauncherSettings),
  (group: 'Settings', icon: Icons.settings_outlined, title: 'System Settings', onTap: _showSystemSettings),
  (group: 'Settings', icon: Icons.verified_outlined, title: 'Essential apps', onTap: showEssentialAppsSheet),
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
    final showMindSpace = _mindSpaceTerms.any((term) => term.contains(query));
    final showRestart = 'restart launcher'.contains(query);

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
          if (groups.isEmpty && !showMindSpace && !showRestart)
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
          if (showMindSpace) ...[
            _SectionHeader('Mind Space', isDark: isDark),
            const FocusQuickActions(),
          ],
          if (showRestart) ...[
            const SizedBox(height: 24),
            Divider(indent: 24, endIndent: 24, color: isDark ? Colors.white24 : Colors.black12),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => _appChannel.invokeMethod('restart'),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Restart Launcher', style: TextStyle(fontSize: 18, letterSpacing: 0.5)),
                style: TextButton.styleFrom(foregroundColor: isDark ? Colors.white60 : Colors.black54),
              ),
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

/// System Settings: the permissions other features depend on, plus the
/// default-launcher switch. Each one is granted on a system screen, so
/// statuses are re-read whenever the app resumes.
void _showSystemSettings(BuildContext context) {
  _showSubSheet(context, 'System Settings', (context, settings) => const [_SystemSettingsRows()]);
}

class _SystemSettingsRows extends StatefulWidget {
  const _SystemSettingsRows();

  @override
  State<_SystemSettingsRows> createState() => _SystemSettingsRowsState();
}

class _SystemSettingsRowsState extends State<_SystemSettingsRows> {
  final _role = const LauncherRoleService();
  final _usage = const UsageStatsService();
  late final AppLifecycleListener _lifecycle;

  bool? _isDefault;
  bool? _hasUsageAccess;
  LocationPermission? _location;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final (isDefault, usage, location) = await (
      _role.isDefaultLauncher(),
      _usage.hasAccess(),
      Geolocator.checkPermission(),
    ).wait;
    if (!mounted) return;
    setState(() {
      _isDefault = isDefault;
      _hasUsageAccess = usage;
      _location = location;
    });
  }

  bool get _hasLocation => _location == LocationPermission.whileInUse || _location == LocationPermission.always;

  Future<void> _onLocationTap() async {
    // Only "denied" can still show the runtime dialog; otherwise (granted,
    // or denied forever) the app's system settings page is the only place
    // to change it.
    if (_location == LocationPermission.denied) {
      await Geolocator.requestPermission();
      await _refresh();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  String _status(bool? value, String yes, String no) => value == null ? '…' : (value ? yes : no);

  @override
  Widget build(BuildContext context) {
    final isDark = AppSettingsScope.of(context).isDark;
    return _SettingsGroup(
      isDark: isDark,
      rows: [
        _StatusRow(
          icon: Icons.home_outlined,
          title: 'Default launcher',
          status: _status(_isDefault, 'Yin Yang Launcher', 'Another app'),
          onTap: _role.openHomeSettings,
        ),
        _StatusRow(
          icon: Icons.insights_outlined,
          title: 'Usage access',
          status: _status(_hasUsageAccess, 'Allowed · used by Mind Space', 'Not allowed · Mind Space needs this'),
          onTap: _usage.requestAccess,
        ),
        _StatusRow(
          icon: Icons.location_on_outlined,
          title: 'Location',
          status: _status(
            _location == null ? null : _hasLocation,
            'Allowed · used by the Weather tile',
            'Not allowed · the Weather tile needs this',
          ),
          onTap: _onLocationTap,
        ),
      ],
    );
  }
}

/// A settings row with a status subtitle under the title.
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.icon, required this.title, required this.status, required this.onTap});

  final IconData icon;
  final String title;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontSize: 18, letterSpacing: 0.5)),
      subtitle: Text(status),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
