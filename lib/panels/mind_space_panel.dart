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
  // Yesterday, for Reflect.
  List<UsageEvent>? _yesterdayEvents;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadApps();
    InstalledAppsService.changes.addListener(_loadApps);
    _refresh();
  }

  void _loadApps() => _appsService.loadApps().then((apps) {
    if (mounted) setState(() => _appsByPackage = {for (final app in apps) app.packageName: app});
  });

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    InstalledAppsService.changes.removeListener(_loadApps);
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
    final startOfYesterday = DateTime(now.year, now.month, now.day - 1);
    if (mounted) {
      setState(() {
        _hasAccess = true;
        _yesterdayEvents = [
          for (final e in events)
            if (!e.timestamp.isBefore(startOfYesterday) && e.timestamp.isBefore(startOfDay)) e,
        ];
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

  void _setReflect(bool reflect) {
    setState(() => _reflect = reflect);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppSettingsScope.of(context).isDark;
    final hasAccess = _hasAccess;
    final Widget awareness = hasAccess == null
        ? const Center(child: CircularProgressIndicator())
        : hasAccess
        ? Column(
            children: [
              _Header(reflect: _reflect, onReflect: _setReflect, onSettings: _editProductiveApps),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(25, 8, 25, 24),
                  children: _reflect ? _reflectChildren() : _nowChildren(),
                ),
              ),
            ],
          )
        : Center(
            child: FilledButton(onPressed: _service.requestAccess, child: const Text('Grant usage access')),
          );
    return Container(
      color: Theme.of(context).colorScheme.surface,
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

  List<Widget> _nowChildren() {
    final now = DateTime.now();
    final hourly = [..._hourly ?? const <Duration>[]];
    while (hourly.length < 24) {
      hourly.add(Duration.zero);
    }
    return [
      _DayView(
        title: 'Today so far',
        breakdownTitle: 'Where the time goes',
        chartTitle: 'YOUR DAY, HOUR BY HOUR',
        totals: _totals ?? const MindSpaceTotals(screenTime: Duration.zero, pickups: 0),
        perApp: _perApp ?? const [],
        hourly: hourly,
        currentHour: now.hour,
        appsByPackage: _appsByPackage,
      ),
      if (_habits case final habits?) ...[
        const SizedBox(height: 36),
        _HabitsSection(habits: habits, appsByPackage: _appsByPackage),
      ],
      const SizedBox(height: 28),
      _ArrowLink(label: 'See yesterday', onTap: () => _setReflect(true)),
    ];
  }

  List<Widget> _reflectChildren() {
    final daily = _daily;
    final events = _yesterdayEvents;
    if (daily == null || events == null) return const [Center(child: CircularProgressIndicator())];
    final now = DateTime.now();
    final endOfYesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(milliseconds: 1));
    return [
      _DayView(
        title: 'Yesterday',
        breakdownTitle: 'Where it went',
        chartTitle: 'WHEN IT HAPPENED',
        totals: computeMindSpaceTotals(events),
        perApp: computePerAppUsage(events),
        hourly: computeHourlyUsage(events, endOfYesterday),
        appsByPackage: _appsByPackage,
      ),
      const SizedBox(height: 36),
      ReflectView(daily: daily),
    ];
  }
}

enum _MindSpaceTab { awareness, action }

/// Now / Reflect as underlined text tabs, with the settings gear (productive
/// apps) on the right, as in the original. Stays put while the page scrolls.
class _Header extends StatelessWidget {
  const _Header({required this.reflect, required this.onReflect, required this.onSettings});

  final bool reflect;
  final ValueChanged<bool> onReflect;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget tab(String label, bool value) {
      final selected = reflect == value;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onReflect(value),
        child: Padding(
          padding: const EdgeInsets.only(right: 22),
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 15, color: selected ? colors.onSurface : colors.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Container(height: 1.5, color: selected ? colors.onSurface : Colors.transparent),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 4, 0),
      child: Row(
        children: [
          tab('Now', false),
          tab('Reflect', true),
          const Spacer(),
          IconButton(
            tooltip: 'Productive apps',
            onPressed: onSettings,
            icon: Icon(Icons.settings_outlined, size: 18, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Awareness / Action switch along the bottom of Mind Space: selected tab
/// in full ink, the other faint, on a raised strip (no divider), as in the
/// original.
class _BottomTabs extends StatelessWidget {
  const _BottomTabs({required this.selected, required this.isDark, required this.onSelected});

  final _MindSpaceTab selected;
  final bool isDark;
  final ValueChanged<_MindSpaceTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget tab(_MindSpaceTab value, IconData icon, String label) {
      final on = value == selected;
      final color = on ? colors.onSurface : colors.outlineVariant;
      return Expanded(
        child: InkWell(
          onTap: () => onSelected(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    letterSpacing: 1,
                    fontWeight: on ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: colors.surfaceContainer,
      child: Row(
        children: [
          tab(_MindSpaceTab.awareness, Icons.lightbulb_outline, 'Awareness'),
          tab(_MindSpaceTab.action, Icons.auto_awesome_outlined, 'Action'),
        ],
      ),
    );
  }
}

/// The original's captions: a softer ink than primary, brighter than
/// secondary (`#B2B2B2` on black).
Color _soft(ColorScheme colors) => Color.lerp(colors.onSurface, colors.surface, 0.25)!;

/// "<1m" for a little use, as the original shows it; otherwise as usual.
String _shortTime(Duration d) => d > Duration.zero && d < const Duration(minutes: 1) ? '<1m' : formatScreenTime(d);

/// One day's Awareness, in the original's layout: a title, the total in big
/// fading numerals, unlocks and apps, a per-app breakdown with bars (top
/// three, then See all), and an hour-by-hour chart. Now shows today, Reflect
/// yesterday.
class _DayView extends StatefulWidget {
  const _DayView({
    required this.title,
    required this.breakdownTitle,
    required this.chartTitle,
    required this.totals,
    required this.perApp,
    required this.hourly,
    required this.appsByPackage,
    this.currentHour,
  });

  final String title;
  final String breakdownTitle;
  final String chartTitle;
  final MindSpaceTotals totals;
  final List<PerAppUsage> perApp;
  final List<Duration> hourly;
  final Map<String, AppInfo> appsByPackage;

  /// Today's hour, drawn in full ink; null for a finished day.
  final int? currentHour;

  @override
  State<_DayView> createState() => _DayViewState();
}

class _DayViewState extends State<_DayView> {
  var _seeAll = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ink = colors.onSurface;
    final soft = _soft(colors);
    final caption = TextStyle(fontSize: 13, color: soft);
    // Only apps you can open: background system packages (permission
    // controller, settings intelligence, ...) count toward the total but get
    // no row. Until the app list loads, nothing is filtered.
    final apps = widget.appsByPackage;
    final perApp = [
      for (final u in widget.perApp)
        if (apps.isEmpty || apps.containsKey(u.packageName)) u,
    ];
    final shown = _seeAll ? perApp : perApp.take(3).toList();
    final longest = perApp.isEmpty ? 1 : perApp.first.duration.inSeconds.clamp(1, 1 << 31);
    Widget stat(int value, String label) => Padding(
      padding: const EdgeInsets.only(right: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: TextStyle(fontSize: 38, height: 1.1, color: ink)),
          Text(label, style: caption),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: ink),
        ),
        const SizedBox(height: 2),
        Text('You spent', style: TextStyle(fontSize: 14, color: soft)),
        const SizedBox(height: 14),
        // Fades from ink at the top to grey at the bottom, like the original.
        ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [ink, ink.withValues(alpha: 0.35)],
          ).createShader(rect),
          child: Text(
            formatScreenTime(widget.totals.screenTime),
            style: const TextStyle(fontSize: 64, height: 1.1, fontWeight: FontWeight.w500, color: Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        Text('on your phone', style: caption),
        const SizedBox(height: 28),
        Row(children: [stat(widget.totals.pickups, 'unlocks'), stat(perApp.length, 'apps')]),
        const SizedBox(height: 28),
        Divider(height: 1, color: colors.outlineVariant),
        const SizedBox(height: 28),
        Text(
          widget.breakdownTitle,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: ink),
        ),
        const SizedBox(height: 12),
        for (final usage in shown)
          SizedBox(
            height: 36,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        apps[usage.packageName]?.name ?? usage.packageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: ink),
                      ),
                    ),
                    Text('×${usage.opens}', style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
                    const SizedBox(width: 12),
                    Text(_shortTime(usage.duration), style: TextStyle(fontSize: 13, color: ink)),
                  ],
                ),
                const SizedBox(height: 4),
                // Each app's share against the day's biggest.
                ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: LinearProgressIndicator(
                    value: usage.duration.inSeconds / longest,
                    minHeight: 2,
                    color: ink,
                    backgroundColor: colors.outlineVariant,
                  ),
                ),
              ],
            ),
          ),
        if (perApp.length > 3) ...[
          const SizedBox(height: 12),
          _ArrowLink(label: _seeAll ? 'Show less' : 'See all', onTap: () => setState(() => _seeAll = !_seeAll)),
        ],
        const SizedBox(height: 24),
        Text(widget.chartTitle, style: TextStyle(fontSize: 14, letterSpacing: 1, color: soft)),
        const SizedBox(height: 24),
        _HourlyChart(hourly: widget.hourly, currentHour: widget.currentHour),
      ],
    );
  }
}

/// The original's quiet italic "See all →" style link, right-aligned.
class _ArrowLink extends StatelessWidget {
  const _ArrowLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: color),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward, size: 13, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Habits & Reflexes: the app most often opened right after unlocking.
class _HabitsSection extends StatelessWidget {
  const _HabitsSection({required this.habits, required this.appsByPackage});

  final HabitsInsight habits;
  final Map<String, AppInfo> appsByPackage;

  @override
  Widget build(BuildContext context) {
    final topPackage = habits.topPackage;
    if (topPackage == null) return const SizedBox.shrink();
    final primary = Theme.of(context).colorScheme.onSurface;
    final name = appsByPackage[topPackage]?.name ?? topPackage;
    final percent = (habits.topCount / habits.totalUnlocks * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HABITS & REFLEXES',
          style: TextStyle(fontSize: 14, letterSpacing: 1, color: _soft(Theme.of(context).colorScheme)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            AppIcon(icon: appsByPackage[topPackage]?.icon, size: 34),
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
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 14, color: primary)),
          ),
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
          child: _QuickActionTile(icon: Icons.center_focus_strong, label: 'Focus Mode', isDark: isDark, onTap: _start),
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

/// A bar per hour of the day, 12 AM to 12 AM, as in the original: used hours
/// in grey, the current one in full ink, unused ones a faint baseline.
class _HourlyChart extends StatelessWidget {
  const _HourlyChart({required this.hourly, this.currentHour});

  final List<Duration> hourly;
  final int? currentHour;

  static const _barHeight = 67.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final longest = hourly.fold<int>(1, (max, d) => d.inSeconds > max ? d.inSeconds : max);
    return Column(
      children: [
        SizedBox(
          height: _barHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var hour = 0; hour < 24; hour++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: FractionallySizedBox(
                      alignment: Alignment.bottomCenter,
                      heightFactor: hour < hourly.length && hourly[hour] > Duration.zero
                          ? (hourly[hour].inSeconds / longest).clamp(0.08, 1.0)
                          : 0.02,
                      child: Container(
                        color: hour == currentHour
                            ? colors.onSurface
                            : hour < hourly.length && hourly[hour] > Duration.zero
                            ? Color.lerp(colors.onSurface, colors.surface, 0.8)
                            : colors.outlineVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final label in const ['12 AM', '6 AM', '12 PM', '6 PM', '12 AM'])
              Text(label, style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}
