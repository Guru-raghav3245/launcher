import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../mind_space/action_tab.dart';
import '../mind_space/focus_duration_sheet.dart';
import '../mind_space/reflect_view.dart';
import '../search/app_multi_picker_sheet.dart';
import '../search/app_result_row.dart';
import '../services/focus_mode_service.dart';
import '../services/installed_apps_service.dart';
import '../services/productive_apps_service.dart';
import '../services/usage_stats_service.dart';
import '../state/app_settings_scope.dart';
import '../widgets/segmented_toggle.dart';

/// Total screen time (sum of foreground/background pairs, per package) and
/// pickup count (unlock events) for a set of raw usage events. Exposed
/// top-level so it's testable without a widget harness.
class MindSpaceTotals {
  const MindSpaceTotals({required this.screenTime, required this.pickups});

  final Duration screenTime;
  final int pickups;
}

MindSpaceTotals computeMindSpaceTotals(List<UsageEvent> events) {
  final sorted = [...events]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final foregroundSince = <String, DateTime>{};
  var screenTime = Duration.zero;
  var pickups = 0;
  for (final event in sorted) {
    switch (event.type) {
      case UsageEventType.foreground:
        foregroundSince[event.packageName] = event.timestamp;
      case UsageEventType.background:
        final start = foregroundSince.remove(event.packageName);
        if (start != null) screenTime += event.timestamp.difference(start);
      case UsageEventType.unlocked:
        pickups++;
    }
  }
  return MindSpaceTotals(screenTime: screenTime, pickups: pickups);
}

String formatScreenTime(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours == 0) return '${minutes}m';
  return '${hours}h ${minutes}m';
}

/// Foreground time per hour of [now]'s day, from midnight through the hour
/// containing [now] (index 0 = 12am-1am, etc). An interval spanning an hour
/// boundary is split so each hour only gets the portion inside it.
List<Duration> computeHourlyUsage(List<UsageEvent> events, DateTime now) {
  final buckets = List.generate(now.hour + 1, (_) => Duration.zero);
  final sorted = [...events]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final foregroundSince = <String, DateTime>{};
  for (final event in sorted) {
    switch (event.type) {
      case UsageEventType.foreground:
        foregroundSince[event.packageName] = event.timestamp;
      case UsageEventType.background:
        final start = foregroundSince.remove(event.packageName);
        if (start != null) _addToHourlyBuckets(buckets, start, event.timestamp);
      case UsageEventType.unlocked:
        break;
    }
  }
  return buckets;
}

void _addToHourlyBuckets(List<Duration> buckets, DateTime start, DateTime end) {
  var cursor = start;
  while (cursor.isBefore(end)) {
    final hourEnd = DateTime(cursor.year, cursor.month, cursor.day, cursor.hour + 1);
    final segmentEnd = hourEnd.isBefore(end) ? hourEnd : end;
    if (cursor.hour < buckets.length) {
      buckets[cursor.hour] += segmentEnd.difference(cursor);
    }
    cursor = segmentEnd;
  }
}

/// Opens (foreground transitions) and total foreground time for a single
/// package, for the per-app breakdown (task 4).
class PerAppUsage {
  const PerAppUsage({required this.packageName, required this.opens, required this.duration});

  final String packageName;
  final int opens;
  final Duration duration;

  Duration get averagePerOpen => opens == 0 ? Duration.zero : duration ~/ opens;
}

/// Per-package opens/foreground-time, sorted by most time spent first.
List<PerAppUsage> computePerAppUsage(List<UsageEvent> events) {
  final sorted = [...events]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final foregroundSince = <String, DateTime>{};
  final opens = <String, int>{};
  final durations = <String, Duration>{};
  for (final event in sorted) {
    switch (event.type) {
      case UsageEventType.foreground:
        foregroundSince[event.packageName] = event.timestamp;
        opens[event.packageName] = (opens[event.packageName] ?? 0) + 1;
      case UsageEventType.background:
        final start = foregroundSince.remove(event.packageName);
        if (start != null) {
          durations[event.packageName] =
              (durations[event.packageName] ?? Duration.zero) + event.timestamp.difference(start);
        }
      case UsageEventType.unlocked:
        break;
    }
  }
  final result = [
    for (final entry in durations.entries)
      PerAppUsage(packageName: entry.key, opens: opens[entry.key] ?? 0, duration: entry.value),
  ];
  result.sort((a, b) => b.duration.compareTo(a.duration));
  return result;
}

/// The app most often opened first after unlocking the phone, derived from
/// task 1's raw event sequence: each `unlocked` event starts a window that
/// closes on the next `foreground` event, whichever package that is.
class HabitsInsight {
  const HabitsInsight({required this.topPackage, required this.topCount, required this.totalUnlocks});

  final String? topPackage;
  final int topCount;
  final int totalUnlocks;
}

HabitsInsight computeHabits(List<UsageEvent> events) {
  final sorted = [...events]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final afterUnlockCounts = <String, int>{};
  var totalUnlocks = 0;
  var awaitingFirstOpen = false;
  for (final event in sorted) {
    switch (event.type) {
      case UsageEventType.unlocked:
        awaitingFirstOpen = true;
      case UsageEventType.foreground:
        if (awaitingFirstOpen) {
          afterUnlockCounts[event.packageName] = (afterUnlockCounts[event.packageName] ?? 0) + 1;
          totalUnlocks++;
          awaitingFirstOpen = false;
        }
      case UsageEventType.background:
        break;
    }
  }
  String? topPackage;
  var topCount = 0;
  for (final entry in afterUnlockCounts.entries) {
    if (entry.value > topCount) {
      topPackage = entry.key;
      topCount = entry.value;
    }
  }
  return HabitsInsight(topPackage: topPackage, topCount: topCount, totalUnlocks: totalUnlocks);
}

/// Mind Space panel: screen-time insights, all derived from Phase 4 task 1's
/// raw usage-event stream — today's total screen time and pickup count, an
/// hourly bar chart, a per-app opens/time breakdown, a Habits & Reflexes
/// insight (what's opened first after unlocking), and Pause/Timer/Focus Mode
/// quick actions backed by [FocusModeService].
class MindSpacePanel extends StatefulWidget {
  const MindSpacePanel({super.key});

  @override
  State<MindSpacePanel> createState() => _MindSpacePanelState();
}

class _MindSpacePanelState extends State<MindSpacePanel> with WidgetsBindingObserver {
  final _service = const UsageStatsService();
  final _appsService = const InstalledAppsService();
  bool? _hasAccess;
  MindSpaceTotals? _totals;
  List<Duration>? _hourly;
  List<PerAppUsage>? _perApp;
  HabitsInsight? _habits;
  Map<String, AppInfo> _appsByPackage = const {};
  var _tab = _MindSpaceTab.awareness;
  var _reflect = false;
  List<DayTotals>? _daily;
  var _productiveCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appsService.loadApps().then((apps) {
      if (mounted) setState(() => _appsByPackage = {for (final app in apps) app.packageName: app});
    });
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Usage access has no runtime-permission callback — re-check when the
    // user comes back from Settings.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final hasAccess = await _service.hasAccess();
    if (!hasAccess) {
      if (mounted) setState(() => _hasAccess = false);
      return;
    }
    final now = DateTime.now();
    final productive = await const ProductiveAppsService().apps();
    // Reflect needs the last 14 days; Now only today.
    final start = DateTime(now.year, now.month, now.day - (_reflect ? 13 : 0));
    final events = withoutProductive(await _service.queryEvents(start: start, end: now), productive);
    final startOfDay = DateTime(now.year, now.month, now.day);
    final today = [
      for (final e in events)
        if (!e.timestamp.isBefore(startOfDay)) e,
    ];
    if (mounted) {
      setState(() {
        _hasAccess = true;
        _productiveCount = productive.length;
        _totals = computeMindSpaceTotals(today);
        _hourly = computeHourlyUsage(today, now);
        _perApp = computePerAppUsage(today);
        _habits = computeHabits(today);
        if (_reflect) _daily = computeDailyTotals(events, now);
      });
    }
  }

  Future<void> _editProductiveApps() async {
    const productive = ProductiveAppsService();
    await showAppMultiPicker(
      context,
      title: 'Productive apps',
      subtitle: "Time in these isn't counted in Mind Space.",
      load: productive.apps,
      onChanged: productive.setProductive,
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppSettingsScope.of(context).isDark;
    final hasAccess = _hasAccess;
    final Widget awareness = hasAccess == null
        ? const Center(child: CircularProgressIndicator())
        : hasAccess
        ? ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            children: [
              Center(
                child: SegmentedToggle<bool>(
                  options: const [(false, Icons.today, 'Now'), (true, Icons.insights, 'Reflect')],
                  value: _reflect,
                  onChanged: (reflect) {
                    setState(() => _reflect = reflect);
                    _refresh();
                  },
                ),
              ),
              const SizedBox(height: 32),
              if (_reflect)
                _daily == null
                    ? const Center(child: CircularProgressIndicator())
                    : ReflectView(daily: _daily!, isDark: isDark)
              else ...[
                _Totals(
                  totals: _totals ?? const MindSpaceTotals(screenTime: Duration.zero, pickups: 0),
                  isDark: isDark,
                ),
                const SizedBox(height: 40),
                _HourlyChart(hourly: _hourly ?? const [], isDark: isDark),
                const SizedBox(height: 40),
                _PerAppBreakdown(perApp: _perApp ?? const [], appsByPackage: _appsByPackage, isDark: isDark),
                const SizedBox(height: 40),
                _HabitsSection(
                  habits: _habits ?? const HabitsInsight(topPackage: null, topCount: 0, totalUnlocks: 0),
                  appsByPackage: _appsByPackage,
                  isDark: isDark,
                ),
              ],
              const SizedBox(height: 32),
              Material(
                type: MaterialType.transparency,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.work_outline),
                  title: const Text('Productive apps'),
                  subtitle: Text(
                    _productiveCount == 0
                        ? "Leave apps you need out of these stats"
                        : "$_productiveCount ${_productiveCount == 1 ? 'app' : 'apps'} not counted",
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _editProductiveApps,
                ),
              ),
            ],
          )
        : Center(
            child: FilledButton(onPressed: _service.requestAccess, child: const Text('Grant usage access')),
          );
    return Container(
      color: isDark ? const Color(0xFF000000) : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(child: _tab == _MindSpaceTab.awareness ? awareness : const ActionTab()),
            _BottomTabs(selected: _tab, isDark: isDark, onSelected: (tab) => setState(() => _tab = tab)),
          ],
        ),
      ),
    );
  }
}

enum _MindSpaceTab { awareness, action }

/// Awareness / Action switch along the bottom of Mind Space: selected tab
/// in full ink, the other faded (no accent color, per DESIGN_LANGUAGE.md).
class _BottomTabs extends StatelessWidget {
  const _BottomTabs({required this.selected, required this.isDark, required this.onSelected});

  final _MindSpaceTab selected;
  final bool isDark;
  final ValueChanged<_MindSpaceTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final ink = isDark ? Colors.white : Colors.black;
    Widget tab(_MindSpaceTab value, IconData icon, String label) {
      final color = value == selected ? ink : ink.withValues(alpha: 0.35);
      return Expanded(
        child: InkWell(
          onTap: () => onSelected(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: value == selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: ink.withValues(alpha: 0.08)))),
      child: Row(
        children: [
          tab(_MindSpaceTab.awareness, Icons.lightbulb_outline, 'Awareness'),
          tab(_MindSpaceTab.action, Icons.auto_awesome_outlined, 'Action'),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.totals, required this.isDark});

  final MindSpaceTotals totals;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.onSurface;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Screen time today', style: TextStyle(fontSize: 15, color: secondary)),
        const SizedBox(height: 8),
        Text(
          formatScreenTime(totals.screenTime),
          style: TextStyle(fontSize: 48, fontWeight: FontWeight.w500, color: primary),
        ),
        const SizedBox(height: 24),
        Text('${totals.pickups} pickups', style: TextStyle(fontSize: 18, color: secondary)),
      ],
    );
  }
}

/// Opens/time per app, with a one-line behavioral insight (average session
/// length) per row. Icons/names are cross-referenced from [InstalledAppsService]
/// the same way the App Folder/From-Apps picker sheets do.
class _PerAppBreakdown extends StatelessWidget {
  const _PerAppBreakdown({required this.perApp, required this.appsByPackage, required this.isDark});

  final List<PerAppUsage> perApp;
  final Map<String, AppInfo> appsByPackage;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (perApp.isEmpty) return const SizedBox.shrink();
    final primary = Theme.of(context).colorScheme.onSurface;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Per app', style: TextStyle(fontSize: 13, color: secondary)),
        const SizedBox(height: 12),
        for (final usage in perApp)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                AppIcon(icon: appsByPackage[usage.packageName]?.icon, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appsByPackage[usage.packageName]?.name ?? usage.packageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, color: primary),
                      ),
                      Text(
                        '${usage.opens} opens · avg ${formatScreenTime(usage.averagePerOpen)} per open',
                        style: TextStyle(fontSize: 12, color: secondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatScreenTime(usage.duration),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: primary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Habits & Reflexes: the app most often opened right after unlocking.
class _HabitsSection extends StatelessWidget {
  const _HabitsSection({required this.habits, required this.appsByPackage, required this.isDark});

  final HabitsInsight habits;
  final Map<String, AppInfo> appsByPackage;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final topPackage = habits.topPackage;
    if (topPackage == null) return const SizedBox.shrink();
    final primary = Theme.of(context).colorScheme.onSurface;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final name = appsByPackage[topPackage]?.name ?? topPackage;
    final percent = (habits.topCount / habits.totalUnlocks * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Habits & Reflexes', style: TextStyle(fontSize: 13, color: secondary)),
        const SizedBox(height: 12),
        Row(
          children: [
            AppIcon(icon: appsByPackage[topPackage]?.icon, size: 36),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'After unlocking, you open $name first $percent% of the time '
                '(${habits.topCount} of ${habits.totalUnlocks} unlocks).',
                style: TextStyle(fontSize: 14, color: primary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Quick actions: Pause, Timer, and Focus Mode all start or stop the same
/// [FocusModeService] session (Pause/Focus Mode start it indefinitely,
/// Timer for a picked duration); while active, a single status row with a
/// Stop button replaces the three tiles.
/// Pause / Timer / Focus Mode tiles, collapsing to a "Focus Mode is on …
/// Stop" row while a session is active. Self-contained (owns its
/// [FocusModeService] status) so Mind Space and Settings share it.
class FocusQuickActions extends StatefulWidget {
  const FocusQuickActions({super.key});

  @override
  State<FocusQuickActions> createState() => _FocusQuickActionsState();
}

class _FocusQuickActionsState extends State<FocusQuickActions> {
  final _focusMode = const FocusModeService();
  late final AppLifecycleListener _lifecycle;
  FocusStatus _status = const FocusStatus(active: false);

  @override
  void initState() {
    super.initState();
    // A timed session can expire while the app is backgrounded.
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    FocusModeService.changes.addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    FocusModeService.changes.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final status = await _focusMode.status();
    if (mounted) setState(() => _status = status);
  }

  Future<void> _start([Duration? duration]) => _focusMode.start(duration: duration);

  Future<void> _stop() => _focusMode.stop();

  Future<void> _pickTimer() async {
    final choice = await showFocusDurationSheet(context);
    if (choice != null) await _focusMode.start(duration: choice.duration, strict: choice.strict);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppSettingsScope.of(context).isDark;
    final primary = Theme.of(context).colorScheme.onSurface;
    if (_status.active) {
      final remaining = _status.remaining;
      final label = remaining == null ? 'Focus Mode is on' : 'Focus Mode is on · ${formatScreenTime(remaining)} left';
      return Row(
        children: [
          Icon(Icons.center_focus_strong, color: primary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: primary))),
          if (!_status.strict) TextButton(onPressed: _stop, child: const Text('Stop')),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: _QuickActionTile(icon: Icons.self_improvement, label: 'Pause', isDark: isDark, onTap: _start),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionTile(icon: Icons.timer_outlined, label: 'Timer', isDark: isDark, onTap: _pickTimer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionTile(
            icon: Icons.center_focus_strong,
            label: 'Focus Mode',
            isDark: isDark,
            onTap: _start,
          ),
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.icon, required this.label, required this.isDark, required this.onTap});

  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 13, color: color)),
          ],
        ),
      ),
    );
  }
}

/// 12am-through-now bar chart of per-hour foreground time.
class _HourlyChart extends StatelessWidget {
  const _HourlyChart({required this.hourly, required this.isDark});

  final List<Duration> hourly;
  final bool isDark;

  static const _barHeight = 100.0;

  @override
  Widget build(BuildContext context) {
    if (hourly.isEmpty) return const SizedBox.shrink();
    final barColor = Theme.of(context).colorScheme.onSurface;
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hourly usage',
          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _barHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var hour = 0; hour < hourly.length; hour++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: FractionallySizedBox(
                      alignment: Alignment.bottomCenter,
                      heightFactor: (hourly[hour].inSeconds / 3600).clamp(0.02, 1.0),
                      child: Container(color: barColor),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final hour in const [0, 6, 12, 18])
              if (hour < hourly.length)
                Expanded(
                  child: Text(
                    hour == 0 ? '12am' : hour < 12 ? '${hour}am' : hour == 12 ? '12pm' : '${hour - 12}pm',
                    style: TextStyle(fontSize: 11, color: labelColor),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}
