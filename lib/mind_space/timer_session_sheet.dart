import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../panels/mind_space_panel.dart';
import '../services/mindful_timer_service.dart';
import '../services/usage_stats_service.dart';

/// Today's foreground time across [group]'s apps; zero without usage access.
Future<Duration> groupUsageToday(TimerGroup group, DateTime now) async {
  const usage = UsageStatsService();
  try {
    if (!await usage.hasAccess()) return Duration.zero;
    final events = await usage.queryEvents(start: DateTime(now.year, now.month, now.day), end: now);
    return computePerAppUsage(events)
        .where((u) => group.packages.contains(u.packageName))
        .fold<Duration>(Duration.zero, (sum, u) => sum + u.duration);
  } catch (_) {
    return Duration.zero; // No usage channel (tests).
  }
}

/// Mindful Timer's "Choose session length" sheet, shown before a timed app
/// opens: a minute wheel (1 min up to what's left of the daily budget,
/// starting at 3), today's usage, and the budget left. Resolves to the
/// chosen minutes, or null on Close.
Future<int?> showTimerSessionSheet(
  BuildContext context, {
  required AppInfo app,
  required TimerGroup group,
  required Duration usedToday,
  required int sessionsToday,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) =>
        _TimerSessionSheet(app: app, group: group, usedToday: usedToday, sessionsToday: sessionsToday),
  );
}

class _TimerSessionSheet extends StatefulWidget {
  const _TimerSessionSheet({
    required this.app,
    required this.group,
    required this.usedToday,
    required this.sessionsToday,
  });

  final AppInfo app;
  final TimerGroup group;
  final Duration usedToday;
  final int sessionsToday;

  @override
  State<_TimerSessionSheet> createState() => _TimerSessionSheetState();
}

class _TimerSessionSheetState extends State<_TimerSessionSheet> {
  late final int _maxMinutes = (widget.group.dailyMinutes - widget.usedToday.inMinutes).clamp(1, 24 * 60);
  late int _minutes = _maxMinutes < 3 ? _maxMinutes : 3;
  late final _wheel = FixedExtentScrollController(initialItem: _minutes - 1);

  @override
  void dispose() {
    _wheel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : Colors.black;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final group = widget.group;
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined, size: 32),
            const SizedBox(height: 8),
            const Text('Choose session length', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(
              'Today · ${formatScreenTime(widget.usedToday)} · Session ${widget.sessionsToday + 1}',
              style: TextStyle(color: secondary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IgnorePointer(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        border: Border.symmetric(horizontal: BorderSide(color: ink.withValues(alpha: 0.3))),
                      ),
                    ),
                  ),
                  ListWheelScrollView(
                    controller: _wheel,
                    itemExtent: 44,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (i) => setState(() => _minutes = i + 1),
                    children: [
                      for (var m = 1; m <= _maxMinutes; m++)
                        Center(
                          child: Text(
                            '$m min',
                            style: TextStyle(fontSize: 22, color: ink.withValues(alpha: m == _minutes ? 1 : 0.35)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(group.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text('${_maxMinutes - _minutes} min left after this', style: TextStyle(color: secondary)),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: (widget.usedToday.inMinutes + _minutes) / group.dailyMinutes,
              color: ink,
              backgroundColor: ink.withValues(alpha: 0.12),
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ink,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: buttonShape,
                    ),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_minutes),
                    style: FilledButton.styleFrom(
                      backgroundColor: ink,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: buttonShape,
                    ),
                    child: const Text('Start Session', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
