import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../mind_space/focus_session_view.dart';
import '../models/home_layout_mode.dart';
import '../search/app_picker_sheet.dart';
import '../search/app_result_row.dart';
import '../services/app_customizations_service.dart';
import '../services/dock_service.dart';
import '../services/installed_apps_service.dart';
import '../services/focus_mode_service.dart';
import '../settings/lock_gesture.dart';
import '../settings/settings_screen.dart';
import '../state/app_settings.dart';
import '../state/app_settings_scope.dart';
import '../widgets/launch_app.dart';

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatDate(DateTime date) {
  final weekday = _weekdayNames[date.weekday - 1];
  final month = _monthNames[date.month - 1];
  return '$weekday, ${date.day} $month';
}

const _glyphIcons = {
  DockGlyph.phone: Icons.call_outlined,
  DockGlyph.messages: Icons.chat_bubble_outline,
  DockGlyph.browser: Icons.public,
  DockGlyph.camera: Icons.camera_alt_outlined,
};

/// A dock slot resolved for display: its app (null if empty or no longer
/// installed) and the glyph to draw instead of the app's icon, if any.
typedef _DockItem = ({AppInfo? app, IconData? glyph});

/// Home panel: wallpaper background, live clock, date, battery, and
/// pinned apps in either Classic or Minimal layout.
class HomePanel extends StatefulWidget {
  const HomePanel({super.key});

  @override
  State<HomePanel> createState() => _HomePanelState();
}

class _HomePanelState extends State<HomePanel> {
  final _battery = Battery();
  late final Timer _clockTimer;
  DateTime _now = DateTime.now();
  int? _batteryLevel;
  StreamSubscription<BatteryState>? _batterySub;
  FocusStatus _focus = const FocusStatus(active: false);
  List<_DockItem> _dock = const [];
  List<AppInfo> _apps = const [];

  @override
  void initState() {
    super.initState();
    DockService.changes.addListener(_refreshDock);
    AppCustomizationsService.changes.addListener(_refreshDock);
    _refreshDock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
      // A timed session ends on its own; status() notices and clears it.
      final endsAt = _focus.endsAt;
      if (endsAt != null && _now.isAfter(endsAt)) _refreshFocus();
    });
    FocusModeService.changes.addListener(_refreshFocus);
    _refreshFocus();
    _refreshBattery();
    _batterySub = _battery.onBatteryStateChanged.listen((_) => _refreshBattery());
  }

  Future<void> _refreshFocus() async {
    final status = await const FocusModeService().status();
    if (mounted) setState(() => _focus = status);
  }

  /// Resolves the dock's slots against the installed apps (renamed, and
  /// including hidden ones: the user put them there).
  Future<void> _refreshDock() async {
    final (slots, apps) = await (const DockService().slots(), loadCustomizedApps(includeHidden: true)).wait;
    final byPackage = {for (final app in apps) app.packageName: app};
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _dock = [
        for (final slot in slots)
          (app: byPackage[slot.packageName], glyph: slot.glyph == null ? null : _glyphIcons[slot.glyph]),
      ];
    });
  }

  void _openSlot(int index) {
    final app = _dock[index].app;
    app == null ? _changeSlot(index) : launchApp(context, app);
  }

  Future<void> _changeSlot(int index) async {
    final app = await showAppPicker(context, _apps, title: 'Dock app');
    if (app != null) await const DockService().setSlot(index, app.packageName);
  }

  Future<void> _refreshBattery() async {
    // ponytail: batteryLevel throws on platforms/emulators without a
    // battery (e.g. some desktop targets) — swallow and just hide the %.
    try {
      final level = await _battery.batteryLevel;
      if (mounted) setState(() => _batteryLevel = level);
    } catch (_) {
      if (mounted) setState(() => _batteryLevel = null);
    }
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _batterySub?.cancel();
    FocusModeService.changes.removeListener(_refreshFocus);
    DockService.changes.removeListener(_refreshDock);
    AppCustomizationsService.changes.removeListener(_refreshDock);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final isDark = settings.isDark;
    final subtitle = _batteryLevel == null
        ? _formatDate(_now)
        : '${_formatDate(_now)}, $_batteryLevel%';

    return GestureDetector(
      onLongPress: () => showSettingsScreen(context),
      // Only listened for when set: a double-tap recognizer makes every
      // single tap on Home wait out the double-tap window first.
      onDoubleTap: settings.doubleTap == DoubleTapAction.none ? null : () => lockScreen(context, settings.doubleTap),
      child: Container(
        // Dark theme always uses a near-black background; light theme uses
        // the user's chosen wallpaper swatch as a subtle diagonal gradient.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF000000), Color(0xFF0B0B0D)]
                : [settings.wallpaperColor, Color.lerp(settings.wallpaperColor, Colors.black, 0.06)!],
          ),
        ),
        child: SafeArea(
          child: _focus.active
              ? FocusSessionView(status: _focus, now: _now)
              : settings.layoutMode == HomeLayoutMode.classic
              ? _ClassicLayout(
                  time: _formatTime(_now),
                  subtitle: subtitle,
                  isDark: isDark,
                  dock: _dock,
                  onOpen: _openSlot,
                  onChange: _changeSlot,
                )
              : _MinimalLayout(
                  time: _formatTime(_now),
                  subtitle: subtitle,
                  isDark: isDark,
                  dock: _dock,
                  onOpen: _openSlot,
                  onChange: _changeSlot,
                ),
        ),
      ),
    );
  }
}

class _Clock extends StatelessWidget {
  const _Clock({
    required this.time,
    required this.subtitle,
    required this.isDark,
    this.fontSize = 56,
  });

  final String time;
  final String subtitle;
  final bool isDark;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? Colors.white : Colors.black87;
    final secondary = isDark ? Colors.white60 : Colors.black54;
    // Tapping the clock or date opens the clock app, as on most launchers.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: const InstalledAppsService().openClock,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            time,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500, color: primary),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 15, color: secondary)),
        ],
      ),
    );
  }
}

class _ClassicLayout extends StatelessWidget {
  const _ClassicLayout({
    required this.time,
    required this.subtitle,
    required this.isDark,
    required this.dock,
    required this.onOpen,
    required this.onChange,
  });

  final String time;
  final String subtitle;
  final bool isDark;
  final List<_DockItem> dock;
  final ValueChanged<int> onOpen;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final tint = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.white : Colors.black87;
    final textColor = isDark ? Colors.white70 : Colors.black54;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
          _Clock(time: time, subtitle: subtitle, isDark: isDark, fontSize: 40),
          const Spacer(),
          // Placeholder pill; wired to real Spotlight Search in task 8.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: textColor, size: 20),
                const SizedBox(width: 8),
                Text('Spotlight search', style: TextStyle(color: textColor)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Tap opens the app (or picks one for an empty slot); long-press
              // swaps it. Default slots keep their line glyph; others show
              // the app's icon.
              for (final (i, item) in dock.indexed)
                GestureDetector(
                  onTap: () => onOpen(i),
                  onLongPress: () => onChange(i),
                  child: Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: switch (item) {
                      (glyph: final glyph?, app: _?) => Icon(glyph, color: iconColor, size: 22),
                      (app: final app?, glyph: _) => AppIcon(icon: app.icon, size: 28),
                      _ => Icon(Icons.add, color: iconColor.withValues(alpha: 0.5), size: 22),
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MinimalLayout extends StatelessWidget {
  const _MinimalLayout({
    required this.time,
    required this.subtitle,
    required this.isDark,
    required this.dock,
    required this.onOpen,
    required this.onChange,
  });

  final String time;
  final String subtitle;
  final bool isDark;
  final List<_DockItem> dock;
  final ValueChanged<int> onOpen;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return Column(
      children: [
        const Spacer(flex: 2),
        _Clock(time: time, subtitle: subtitle, isDark: isDark),
        const Spacer(flex: 2),
        for (final (i, item) in dock.indexed)
          GestureDetector(
            onTap: () => onOpen(i),
            onLongPress: () => onChange(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
              child: Text(
                item.app?.name ?? 'Add app',
                style: TextStyle(fontSize: 20, color: item.app == null ? textColor.withValues(alpha: 0.4) : textColor),
              ),
            ),
          ),
        const Spacer(flex: 3),
      ],
    );
  }
}
