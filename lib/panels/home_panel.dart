import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';

import '../models/home_layout_mode.dart';
import '../settings/settings_screen.dart';
import '../state/app_settings_scope.dart';

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

/// Pinned apps shown in both layout modes. Static placeholders until the
/// installed-app data source (task 5) lets these open real apps.
const _pinnedApps = [
  (label: 'Phone', icon: Icons.call_outlined),
  (label: 'Messages', icon: Icons.chat_bubble_outline),
  (label: 'Browser', icon: Icons.public),
  (label: 'Camera', icon: Icons.camera_alt_outlined),
];

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

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
    _refreshBattery();
    _batterySub = _battery.onBatteryStateChanged.listen((_) => _refreshBattery());
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
          child: settings.layoutMode == HomeLayoutMode.classic
              ? _ClassicLayout(time: _formatTime(_now), subtitle: subtitle, isDark: isDark)
              : _MinimalLayout(time: _formatTime(_now), subtitle: subtitle, isDark: isDark),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          time,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500, color: primary),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 15, color: secondary)),
      ],
    );
  }
}

class _ClassicLayout extends StatelessWidget {
  const _ClassicLayout({required this.time, required this.subtitle, required this.isDark});

  final String time;
  final String subtitle;
  final bool isDark;

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
              for (final app in _pinnedApps)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(app.icon, color: iconColor, size: 22),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MinimalLayout extends StatelessWidget {
  const _MinimalLayout({required this.time, required this.subtitle, required this.isDark});

  final String time;
  final String subtitle;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return Column(
      children: [
        const Spacer(flex: 2),
        _Clock(time: time, subtitle: subtitle, isDark: isDark),
        const Spacer(flex: 2),
        for (final app in _pinnedApps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(app.label, style: TextStyle(fontSize: 20, color: textColor)),
          ),
        const Spacer(flex: 3),
      ],
    );
  }
}
