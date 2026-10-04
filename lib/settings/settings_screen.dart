import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../panels/mind_space_panel.dart';
import '../search/app_multi_picker_sheet.dart';
import '../search/app_search.dart';
import '../services/tour_service.dart';
import '../services/focus_mode_service.dart';
import '../services/launcher_role_service.dart';
import '../services/usage_stats_service.dart';
import '../search/app_search_bar.dart';
import '../state/app_settings.dart';
import '../state/app_settings_scope.dart';
import '../mind_space/focus_duration_sheet.dart';
import 'appearance_editor.dart';
import 'settings_pages.dart';
import '../widgets/tour.dart';

/// Opens Settings as a bottom sheet over the launcher.
Future<void> showSettingsScreen(BuildContext context) {
  // Press and hold is how the "Customize my home" tour ends.
  TourService.complete(Tour.customizeHome);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    // Home all but vanishes behind it, as in the original.
    barrierColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    // Opens most of the way up, like the original, and drags to full height.
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 1,
      builder: (context, controller) => SettingsScreen(scrollController: controller),
    ),
  );
}

/// One searchable settings entry. Only the original's three top-level rows
/// (plus Re-run onboarding) show until something is typed; [searchOnly]
/// ones reach deeper pages.
typedef _SettingsEntry = ({IconData icon, String title, void Function(BuildContext) onTap, bool searchOnly});

/// Every entry the sheet can show, in display order. Later Phase 5 tasks
/// add their entries here so search covers them; the Mind Space section
/// isn't a row list, so it's matched by [_mindSpaceTerms] instead.
/// Search terms that keep the Mind Space quick-actions section visible
/// (the Restart Launcher footer is matched the same way, by its label).
const _mindSpaceTerms = ['mind space', 'pause', 'timer', 'focus mode'];

/// Search terms that keep the Toggles group (Theme, Focus Mode) visible.
const _toggleTerms = ['toggles', 'theme', 'dark', 'light', 'focus mode'];

/// Restarts the launcher process (see MainActivity.kt's `student.launcher/app`).
const _appChannel = MethodChannel('student.launcher/app');

const _entries = <_SettingsEntry>[
  (icon: Icons.palette_outlined, title: 'Appearance', onTap: showAppearanceEditor, searchOnly: false),
  (icon: Icons.contrast, title: 'Launcher Settings', onTap: openLauncherSettings, searchOnly: false),
  (icon: Icons.settings_outlined, title: 'System Settings', onTap: _openSystemSettings, searchOnly: false),
  (icon: Icons.replay, title: 'Re-run onboarding', onTap: rerunOnboarding, searchOnly: false),
  (icon: Icons.home_outlined, title: 'Home Settings', onTap: openHomeSettings, searchOnly: true),
  (icon: Icons.swipe_outlined, title: 'Gestures', onTap: openHomeSettings, searchOnly: true),
  (icon: Icons.apps, title: 'App Drawer', onTap: openDrawerSettings, searchOnly: true),
  (icon: Icons.visibility_off_outlined, title: 'Hidden apps', onTap: showHiddenApps, searchOnly: true),
  (icon: Icons.schedule, title: 'Time & units', onTap: openGeneralSettings, searchOnly: true),
  (icon: Icons.verified_outlined, title: 'Allowed apps', onTap: _showAllowedApps, searchOnly: true),
];

/// Settings sheet: a search field over grouped, outlined rows with hairline
/// dividers. Groups are filled in by Phase 5 tasks 3–7 (Appearance,
/// Launcher, System, Mind Space quick actions, Restart Launcher).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.scrollController});

  final ScrollController? scrollController;

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
    final matches = [
      for (final e in _entries)
        if (query.isEmpty ? !e.searchOnly : e.title.toLowerCase().contains(query)) e,
    ];
    final showMindSpace = _mindSpaceTerms.any((term) => term.contains(query));
    final showToggles = _toggleTerms.any((term) => term.contains(query));
    final showTour = 'take the tour'.contains(query);
    final showRestart = 'restart launcher'.contains(query);
    final faint = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget footer(IconData icon, String label, VoidCallback onTap) => Center(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 15)),
        style: TextButton.styleFrom(foregroundColor: faint),
      ),
    );

    return Padding(
      // Keep the search field above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
        children: [
          AppSearchBar(
            controller: _query,
            hintText: 'Search settings, modes, tools…',
            showSortControl: false,
            sortMode: AppSortMode.alphabetical,
            onSortModeChanged: (_) {},
          ),
          if (matches.isEmpty && !showMindSpace && !showRestart && !showTour && !showToggles)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Text(
                'No settings match "${_query.text.trim()}"',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          if (showToggles) ...[
            _SectionHeader('Toggles', isDark: isDark),
            _SettingsGroup(isDark: isDark, rows: const [_ThemeToggleRow(), _FocusToggleRow()]),
          ],
          if (matches.isNotEmpty) ...[
            _SectionHeader('Settings', isDark: isDark),
            _SettingsGroup(
              isDark: isDark,
              rows: [
                for (final e in matches) _SettingsRow(icon: e.icon, title: e.title, onTap: () => e.onTap(context)),
              ],
            ),
          ],
          if (showMindSpace) ...[_SectionHeader('Mind Space', isDark: isDark), const FocusQuickActions()],
          if (showTour || showRestart) ...[
            const SizedBox(height: 20),
            Divider(indent: 16, endIndent: 16, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 4),
            if (showTour) footer(Icons.lightbulb_outline, 'Take the tour', () => _showTours(context)),
            if (showRestart) footer(Icons.refresh, 'Restart Launcher', () => _appChannel.invokeMethod('restart')),
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
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 12),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          letterSpacing: 0.8,
          color: Color.lerp(Theme.of(context).colorScheme.onSurface, Theme.of(context).colorScheme.surface, 0.25),
        ),
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
    final stroke = Theme.of(context).colorScheme.outline;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: stroke),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 18, endIndent: 18, color: Theme.of(context).colorScheme.outlineVariant),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// A compact sheet row: icon, title (and subtitle), and a chevron.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.icon, required this.title, this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: subtitle == null ? 18 : 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.onSurface),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0.6)),
                  if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Toggles: the theme, picked from a chooser.
class _ThemeToggleRow extends StatelessWidget {
  const _ThemeToggleRow();

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final (_, icon, label, subtitle) = _themeOptions.firstWhere((o) => o.$1 == settings.theme);
    return _SettingsRow(
      icon: icon,
      title: 'Theme · $label',
      subtitle: subtitle,
      onTap: () async {
        final choice = await showChoiceSheet(
          context,
          title: 'Choose Theme',
          selected: settings.theme,
          options: [for (final (value, _, label, subtitle) in _themeOptions) (value, label, subtitle)],
        );
        if (choice != null) settings.setTheme(choice);
      },
    );
  }
}

/// Toggles: Focus Mode. Off, it opens the start sheet; on, a tap stops it
/// (a strict session can't be stopped here, as anywhere else).
class _FocusToggleRow extends StatefulWidget {
  const _FocusToggleRow();

  @override
  State<_FocusToggleRow> createState() => _FocusToggleRowState();
}

class _FocusToggleRowState extends State<_FocusToggleRow> {
  final _focusMode = const FocusModeService();
  FocusStatus _status = const FocusStatus(active: false);

  @override
  void initState() {
    super.initState();
    FocusModeService.changes.addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    FocusModeService.changes.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final status = await _focusMode.status();
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsRow(
      icon: Icons.center_focus_strong,
      title: 'Focus Mode',
      subtitle: !_status.active ? null : (_status.strict ? 'Strict session · on until it ends' : 'On · tap to stop'),
      onTap: _status.strict
          ? null
          : () async {
              if (_status.active) return _focusMode.stop();
              final choice = await showFocusDurationSheet(context);
              if (choice != null) await _focusMode.start(duration: choice.duration, strict: choice.strict);
            },
    );
  }
}

/// Focus Mode's allowed apps: the ones that still open during a session.
void _showAllowedApps(BuildContext context) {
  const focusMode = FocusModeService();
  showAppMultiPicker(
    context,
    title: 'Allowed apps',
    subtitle: 'These still open while Focus Mode is on.',
    load: focusMode.essentials,
    onChanged: focusMode.setEssential,
  );
}

/// The guided tours, reopenable anytime: closes Settings first so the
/// chosen tour's hint shows on Home.
void _showTours(BuildContext context) {
  final navigator = Navigator.of(context);
  navigator.pop();
  showTourPicker(navigator.context);
}

/// The theme options, for the Toggles row.
const _themeOptions = [
  (ThemeChoice.light, Icons.wb_sunny_outlined, 'Light', 'Always light'),
  (ThemeChoice.dark, Icons.nightlight_round, 'Dark', 'Always dark'),
  (ThemeChoice.auto, Icons.brightness_auto_outlined, 'Auto', 'Follows your phone'),
];

/// System Settings: the permissions other features depend on, plus the
/// default-launcher switch. Each one is granted on a system screen, so
/// statuses are re-read whenever the app resumes.
void _openSystemSettings(BuildContext context) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => const SettingsPage(title: 'System Settings', children: [_SystemSettingsRows()]),
  ),
);

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
    return SettingsBox(
      children: [
        _StatusRow(
          icon: Icons.home_outlined,
          title: 'Default launcher',
          status: _status(_isDefault, 'Student Launcher', 'Another app'),
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
  Widget build(BuildContext context) => SettingsRow(
    icon: icon,
    title: title,
    subtitle: status,
    trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
    onTap: onTap,
  );
}
