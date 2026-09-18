import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';

import '../models/home_layout_mode.dart';

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

  // ponytail: local toggle so the layout is verifiable before the real
  // picker (Phase 2 onboarding) and Settings (Phase 5) exist.
  HomeLayoutMode _layoutMode = HomeLayoutMode.classic;

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

  void _toggleLayoutMode() {
    setState(() {
      _layoutMode = _layoutMode == HomeLayoutMode.classic
          ? HomeLayoutMode.minimal
          : HomeLayoutMode.classic;
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _batterySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _batteryLevel == null
        ? _formatDate(_now)
        : '${_formatDate(_now)}, $_batteryLevel%';

    return Container(
      // ponytail: static placeholder gradient; replaced by the user's
      // chosen wallpaper once Phase 2 task 5 lands.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE7E3F0), Color(0xFFD9D4E8)],
        ),
      ),
      child: SafeArea(
        child: GestureDetector(
          onLongPress: _toggleLayoutMode,
          behavior: HitTestBehavior.opaque,
          child: _layoutMode == HomeLayoutMode.classic
              ? _ClassicLayout(time: _formatTime(_now), subtitle: subtitle)
              : _MinimalLayout(time: _formatTime(_now), subtitle: subtitle),
        ),
      ),
    );
  }
}

class _Clock extends StatelessWidget {
  const _Clock({required this.time, required this.subtitle, this.fontSize = 56});

  final String time;
  final String subtitle;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          time,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 15, color: Colors.black54)),
      ],
    );
  }
}

class _ClassicLayout extends StatelessWidget {
  const _ClassicLayout({required this.time, required this.subtitle});

  final String time;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
          _Clock(time: time, subtitle: subtitle, fontSize: 40),
          const Spacer(),
          // Placeholder pill; wired to real Spotlight Search in task 8.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: Colors.black54, size: 20),
                SizedBox(width: 8),
                Text('Spotlight search', style: TextStyle(color: Colors.black54)),
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
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(app.icon, color: Colors.black87, size: 22),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MinimalLayout extends StatelessWidget {
  const _MinimalLayout({required this.time, required this.subtitle});

  final String time;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(flex: 2),
        _Clock(time: time, subtitle: subtitle),
        const Spacer(flex: 2),
        for (final app in _pinnedApps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              app.label,
              style: const TextStyle(fontSize: 20, color: Colors.black87),
            ),
          ),
        const Spacer(flex: 3),
      ],
    );
  }
}
