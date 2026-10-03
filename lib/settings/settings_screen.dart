import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../models/home_layout_mode.dart';
import '../onboarding/onboarding_flow.dart';
import '../panels/mind_space_panel.dart';
import '../search/app_multi_picker_sheet.dart';
import '../search/app_search.dart';
import '../services/app_customizations_service.dart';
import '../services/tour_service.dart';
import '../services/focus_mode_service.dart';
import '../services/launcher_role_service.dart';
import '../services/usage_stats_service.dart';
import '../search/app_search_bar.dart';
import '../state/app_settings.dart';
import '../state/app_settings_scope.dart';
import '../widgets/segmented_toggle.dart';
import '../widgets/tour.dart';
import '../widgets/wallpaper_gallery.dart';
import 'drawer_look_page.dart';
import 'lock_gesture.dart';

/// Opens Settings as a near-full-height bottom sheet over the launcher,
/// matching the mockup (drag handle, dimmed status bar behind it).
Future<void> showSettingsScreen(BuildContext context) {
  // Press and hold is how the "Customize my home" tour ends.
  TourService.complete(Tour.customizeHome);
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

/// Search terms that keep the Toggles group (Theme, Focus Mode) visible.
const _toggleTerms = ['toggles', 'theme', 'dark', 'light', 'focus mode'];

/// Restarts the launcher process (see MainActivity.kt's `yinyang.launcher/app`).
const _appChannel = MethodChannel('yinyang.launcher/app');

const _entries = <_SettingsEntry>[
  (group: 'Settings', icon: Icons.palette_outlined, title: 'Appearance', onTap: _showAppearance),
  (group: 'Settings', icon: Icons.contrast, title: 'Launcher Settings', onTap: _showLauncherSettings),
  (group: 'Settings', icon: Icons.apps, title: 'App Drawer & Search', onTap: _showDrawerSettings),
  (group: 'Settings', icon: Icons.swipe_outlined, title: 'Gestures', onTap: _showGestures),
  (group: 'Settings', icon: Icons.schedule, title: 'Time & units', onTap: _showTimeAndUnits),
  (group: 'Settings', icon: Icons.settings_outlined, title: 'System Settings', onTap: _showSystemSettings),
  (group: 'Settings', icon: Icons.verified_outlined, title: 'Allowed apps', onTap: _showAllowedApps),
  (group: 'Settings', icon: Icons.visibility_off_outlined, title: 'Hidden apps', onTap: _showHiddenApps),
  (group: 'Settings', icon: Icons.contrast, title: 'Take a look around', onTap: _showTours),
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
    final showToggles = _toggleTerms.any((term) => term.contains(query));
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
          if (groups.isEmpty && !showMindSpace && !showRestart && !showToggles)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Text(
                'No settings match "${_query.text.trim()}"',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          if (showToggles) ...[
            _SectionHeader('Toggles', isDark: isDark),
            _SettingsGroup(isDark: isDark, rows: const [_ThemeToggleRow(), _FocusToggleRow()]),
          ],
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

/// Toggles: the theme at a tap, cycling Light → Dark → Auto.
class _ThemeToggleRow extends StatelessWidget {
  const _ThemeToggleRow();

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final (_, icon, label) = _themeOptions.firstWhere((o) => o.$1 == settings.theme);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Icon(icon),
      title: Text('Theme · $label', style: const TextStyle(fontSize: 18, letterSpacing: 0.5)),
      subtitle: Text(switch (settings.theme) {
        ThemeChoice.light => 'Always light',
        ThemeChoice.dark => 'Always dark',
        ThemeChoice.auto => 'Follows your phone',
      }),
      onTap: () => settings.setTheme(ThemeChoice.values[(settings.theme.index + 1) % ThemeChoice.values.length]),
    );
  }
}

/// Toggles: Focus Mode on (indefinitely) or off. A strict session can't be
/// switched off here, as anywhere else.
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
    final isDark = AppSettingsScope.of(context).isDark;
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      secondary: const Icon(Icons.center_focus_strong),
      title: const Text('Focus Mode', style: TextStyle(fontSize: 18, letterSpacing: 0.5)),
      subtitle: _status.strict ? const Text('Strict session: on until it ends') : null,
      value: _status.active,
      activeThumbColor: isDark ? Colors.black : Colors.white,
      activeTrackColor: isDark ? Colors.white : Colors.black,
      onChanged: _status.strict ? null : (on) => on ? _focusMode.start() : _focusMode.stop(),
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
        Text(label, style: const TextStyle(fontSize: 18, letterSpacing: 0.5)),
        const SizedBox(width: 16),
        // The label keeps its width; the control gets the rest, so a toggle
        // shrinks to fit instead of overflowing.
        Expanded(child: Align(alignment: Alignment.centerRight, child: control)),
      ],
    ),
  );
}

/// For controls too wide to share a row with their label (three segments).
Widget _labeledAbove(String label, Widget control) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 18, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        control,
      ],
    ),
  );
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

/// Hidden apps: the ones kept out of the App Drawer and Spotlight, ticked at
/// the top; untick one to bring it back (or tick more to hide them).
Future<void> _showHiddenApps(BuildContext context) async {
  const customizations = AppCustomizationsService();
  await showAppMultiPicker(
    context,
    title: 'Hidden apps',
    subtitle: "Ticked apps don't show in the App Drawer or search.",
    load: () async => (await customizations.load()).hidden,
    onChanged: customizations.setHidden,
  );
}

/// The theme options, shared by Appearance and the Toggles row.
const _themeOptions = [
  (ThemeChoice.light, Icons.wb_sunny_outlined, 'Light'),
  (ThemeChoice.dark, Icons.nightlight_round, 'Dark'),
  (ThemeChoice.auto, Icons.brightness_auto_outlined, 'Auto'),
];

/// Appearance: Light / Dark / Auto (the onboarding toggle offers just Light
/// and Dark), the font, the app icon tint, and the text size.
void _showAppearance(BuildContext context) {
  _showSubSheet(
    context,
    'Appearance',
    (context, settings) => [
      _labeledAbove(
        'Theme',
        SegmentedToggle<ThemeChoice>(value: settings.theme, onChanged: settings.setTheme, options: _themeOptions),
      ),
      _labeledAbove(
        'Font',
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Each option is shown in its own typeface.
            for (final font in LauncherFont.values)
              ChoiceChip(
                label: Text(font.label),
                selected: settings.font == font,
                showCheckmark: false,
                selectedColor: settings.isDark ? Colors.white : Colors.black,
                labelStyle: TextStyle(
                  fontFamily: font.family ?? 'Roboto',
                  color: settings.font == font
                      ? (settings.isDark ? Colors.black : Colors.white)
                      : (settings.isDark ? Colors.white : Colors.black),
                ),
                onSelected: (_) => settings.setFont(font),
              ),
          ],
        ),
      ),
      _labeledAbove(
        'App icons',
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tint in IconTint.values)
              ChoiceChip(
                label: Text(tint.label),
                selected: settings.iconTint == tint,
                showCheckmark: false,
                selectedColor: settings.isDark ? Colors.white : Colors.black,
                labelStyle: TextStyle(
                  color: settings.iconTint == tint
                      ? (settings.isDark ? Colors.black : Colors.white)
                      : (settings.isDark ? Colors.white : Colors.black),
                ),
                onSelected: (_) => settings.setIconTint(tint),
              ),
          ],
        ),
      ),
      _labeledAbove(
        'Text size',
        SegmentedToggle<TextSize>(
          value: settings.textSize,
          onChanged: settings.setTextSize,
          options: const [
            (TextSize.small, Icons.text_decrease, 'Small'),
            (TextSize.normal, Icons.text_fields, 'Default'),
            (TextSize.large, Icons.text_increase, 'Large'),
          ],
        ),
      ),
    ],
  );
}

/// Time & units: 12/24-hour times everywhere, and the Weather tile's unit.
void _showTimeAndUnits(BuildContext context) {
  _showSubSheet(
    context,
    'Time & units',
    (context, settings) => [
      _labeledAbove(
        'Time format',
        SegmentedToggle<TimeFormat>(
          value: settings.timeFormat,
          onChanged: settings.setTimeFormat,
          options: const [
            (TimeFormat.system, Icons.phone_android, 'Phone'),
            (TimeFormat.h12, Icons.schedule, '12-hour'),
            (TimeFormat.h24, Icons.schedule, '24-hour'),
          ],
        ),
      ),
      _labeled(
        'Temperature',
        SegmentedToggle<TempUnit>(
          value: settings.tempUnit,
          onChanged: settings.setTempUnit,
          options: const [(TempUnit.celsius, Icons.thermostat, '°C'), (TempUnit.fahrenheit, Icons.thermostat, '°F')],
        ),
      ),
    ],
  );
}

/// App Drawer & Search: the drawer/Spotlight behaviour switches.
void _showDrawerSettings(BuildContext context) {
  _showSubSheet(context, 'App Drawer & Search', (context, settings) {
    final ink = settings.isDark ? Colors.white : Colors.black;
    Widget option(DrawerOption option, String title, String subtitle) => SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 18, letterSpacing: 0.5)),
      subtitle: Text(subtitle),
      value: settings.drawerOption(option),
      activeThumbColor: settings.isDark ? Colors.black : Colors.white,
      activeTrackColor: ink,
      onChanged: (on) => settings.setDrawerOption(option, on),
    );
    return [
      option(DrawerOption.keyboardOnOpen, 'Keyboard on open', 'Start typing as soon as the App Drawer opens'),
      option(
        DrawerOption.autoOpenSingleResult,
        'Open single result',
        'When a search leaves one app, open it (App Drawer and Spotlight)',
      ),
      option(DrawerOption.recentAppsOnTop, 'Recent apps on top', 'Your recently used apps first (needs usage access)'),
      option(
        DrawerOption.hideUnusedApps,
        'Hide unused apps',
        "Leave out apps you haven't opened in 30 days; search still finds them (needs usage access)",
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.tune),
        title: const Text('Drawer look', style: TextStyle(fontSize: 18, letterSpacing: 0.5)),
        subtitle: const Text('List or grid, icons, labels, spacing'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DrawerLookPage())),
      ),
    ];
  });
}

/// Gestures: what swiping down and double-tapping on Home do. Picking a
/// lock method sets up its permission straight away.
void _showGestures(BuildContext context) {
  _showSubSheet(context, 'Gestures', (context, settings) {
    final ink = settings.isDark ? Colors.white : Colors.black;
    Widget group<T>(String label, T value, ValueChanged<T> onChanged, List<(T, String, String)> choices) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: ink.withValues(alpha: 0.6))),
        RadioGroup<T>(
          groupValue: value,
          onChanged: (v) => onChanged(v as T),
          child: Column(
            children: [
              for (final (choice, title, subtitle) in choices)
                RadioListTile<T>(
                  contentPadding: EdgeInsets.zero,
                  value: choice,
                  activeColor: ink,
                  title: Text(title, style: const TextStyle(fontSize: 17)),
                  subtitle: Text(subtitle),
                ),
            ],
          ),
        ),
      ],
    );

    return [
      group('Swipe down', settings.swipeDown, settings.setSwipeDown, [
        (SwipeDownAction.spotlight, 'Spotlight Search', 'Quickly search apps from your home screen'),
        (SwipeDownAction.notifications, 'Notification tray', 'Pull down to see notifications and toggles'),
        (SwipeDownAction.none, 'None', 'Disable this gesture'),
      ]),
      const SizedBox(height: 16),
      group('Double tap', settings.doubleTap, (action) {
        settings.setDoubleTap(action);
        setUpLock(context, action);
      }, [
        (DoubleTapAction.none, 'None', 'Disable this gesture'),
        (DoubleTapAction.lockAccessibility, 'Lock screen (Accessibility)', 'Recommended; works with fingerprint or face unlock'),
        (DoubleTapAction.lockDeviceAdmin, 'Lock screen (Device admin)', 'Legacy method; may disable fingerprint unlock'),
      ]),
    ];
  });
}

/// Launcher Settings: home layout, clock style and position, the search and
/// status bars, wallpaper, and re-running onboarding.
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
      _labeledAbove(
        'Clock',
        SegmentedToggle<ClockStyle>(
          value: settings.clockStyle,
          onChanged: settings.setClockStyle,
          options: const [
            (ClockStyle.standard, Icons.schedule, 'Standard'),
            (ClockStyle.large, Icons.format_size, 'Large'),
            (ClockStyle.compact, Icons.short_text, 'Compact'),
          ],
        ),
      ),
      _labeledAbove(
        'Clock position',
        SegmentedToggle<ClockPosition>(
          value: settings.clockPositionFor(settings.layoutMode),
          onChanged: settings.setClockPosition,
          options: const [
            (ClockPosition.top, Icons.vertical_align_top, 'Top'),
            (ClockPosition.center, Icons.vertical_align_center, 'Center'),
            (ClockPosition.bottom, Icons.vertical_align_bottom, 'Bottom'),
          ],
        ),
      ),
      for (final (title, value, onChanged) in [
        if (settings.layoutMode == HomeLayoutMode.classic)
          ('Spotlight search bar', settings.showSearchBar, settings.setShowSearchBar),
        ('Status bar', settings.showStatusBar, settings.setShowStatusBar),
      ])
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: const TextStyle(fontSize: 18, letterSpacing: 0.5)),
          value: value,
          activeThumbColor: settings.isDark ? Colors.black : Colors.white,
          activeTrackColor: settings.isDark ? Colors.white : Colors.black,
          onChanged: onChanged,
        ),
      const SizedBox(height: 8),
      WallpaperGallery(settings: settings),
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
