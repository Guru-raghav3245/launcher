import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../panels/mind_space_panel.dart';
import '../search/app_multi_picker_sheet.dart';
import '../search/app_picker_sheet.dart';
import '../search/app_result_row.dart';
import '../services/focus_mode_service.dart';
import '../services/focus_schedule_service.dart';
import '../services/installed_apps_service.dart';
import '../services/mindful_break_service.dart';
import '../services/mindful_pause_service.dart';
import '../services/mindful_timer_service.dart';
import '../services/usage_stats_service.dart';
import 'action_tab.dart';
import 'break_block_screen.dart';
import 'focus_schedules.dart';
import 'timer_group_editor.dart';
import 'timer_session_sheet.dart';

/// Mindful Pause settings, laid out like the original's: the pause length
/// on a 10s-60s slider, and the paused apps with Manage Apps.
class MindfulPausePage extends StatefulWidget {
  const MindfulPausePage({super.key});

  @override
  State<MindfulPausePage> createState() => _MindfulPausePageState();
}

class _MindfulPausePageState extends State<MindfulPausePage> {
  final _pause = const MindfulPauseService();
  int? _seconds;
  List<AppInfo> _apps = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final (seconds, paused, apps) = await (
      _pause.seconds(),
      _pause.pausedApps(),
      const InstalledAppsService().loadApps(),
    ).wait;
    if (!mounted) return;
    setState(() {
      _seconds = seconds;
      _apps = [
        for (final app in apps)
          if (paused.contains(app.packageName)) app,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _seconds;
    final colors = Theme.of(context).colorScheme;
    return _ToolScaffold(
      toolId: 'mindful_pause',
      title: 'Mindful Pause',
      children: seconds == null
          ? const []
          : [
              _Section(
                title: 'Pause Duration',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('${MindfulPauseService.minSeconds}s', style: const TextStyle(fontSize: 15)),
                        Expanded(
                          child: Slider(
                            value: seconds.toDouble(),
                            min: MindfulPauseService.minSeconds.toDouble(),
                            max: MindfulPauseService.maxSeconds.toDouble(),
                            divisions: (MindfulPauseService.maxSeconds - MindfulPauseService.minSeconds) ~/ 5,
                            label: '${seconds}s',
                            activeColor: colors.onSurface,
                            inactiveColor: colors.outlineVariant,
                            onChanged: (value) => setState(() => _seconds = value.round()),
                            onChangeEnd: (value) => _pause.setSeconds(value.round()),
                          ),
                        ),
                        Text('${MindfulPauseService.maxSeconds}s', style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                    Text.rich(
                      TextSpan(
                        text: 'You have set a mindful pause of ',
                        children: [
                          TextSpan(
                            text: '$seconds',
                            style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface),
                          ),
                          const TextSpan(text: ' seconds'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              _Section(
                title: 'Pause Enabled Apps',
                child: _AppsBox(
                  apps: _apps,
                  onManage: () async {
                    await showAppMultiPicker(
                      context,
                      title: 'Mindful Pause',
                      subtitle: 'These open after a short breathing pause.',
                      load: _pause.pausedApps,
                      onChanged: _pause.setPaused,
                    );
                    await _refresh();
                  },
                ),
              ),
            ],
    );
  }
}

/// Focus Mode, like the original's page: start a session now, the apps that
/// stay usable during one, and weekly schedules.
class FocusModePage extends StatefulWidget {
  const FocusModePage({super.key});

  @override
  State<FocusModePage> createState() => _FocusModePageState();
}

class _FocusModePageState extends State<FocusModePage> {
  final _focusMode = const FocusModeService();
  List<AppInfo> _allowed = const [];
  int _scheduleCount = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final (allowed, schedules, apps) = await (
      _focusMode.essentials(),
      const FocusScheduleService().schedules(),
      const InstalledAppsService().loadApps(),
    ).wait;
    if (!mounted) return;
    setState(() {
      _allowed = [
        for (final app in apps)
          if (allowed.contains(app.packageName)) app,
      ];
      _scheduleCount = schedules.length;
    });
  }

  Future<void> _openSchedules() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FocusSchedulesPage()));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final count = _allowed.length;
    return _ToolScaffold(
      toolId: 'focus_mode',
      title: 'Focus Mode',
      children: [
        const _Box(child: FocusQuickActions()),
        const SizedBox(height: 32),
        _Section(
          title: 'Allowed apps',
          subtitle: 'Stay usable while focus is on',
          child: _Box(
            onTap: () async {
              await showAppMultiPicker(
                context,
                title: 'Allowed apps',
                subtitle: 'These still open while Focus Mode is on.',
                load: _focusMode.essentials,
                onChanged: _focusMode.setEssential,
              );
              await _refresh();
            },
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (count > 0) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [for (final app in _allowed.take(8)) AppIcon(icon: app.icon, size: 30)],
                        ),
                        const SizedBox(height: 10),
                      ],
                      Text(
                        count == 0
                            ? 'No apps · tap to choose'
                            : '$count ${count == 1 ? 'app' : 'apps'} · tap to manage',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: colors.onSurfaceVariant),
              ],
            ),
          ),
        ),
        _Section(
          title: 'Focus schedules',
          subtitle: 'At each scheduled time, Focus reminds you to start.',
          child: _Box(
            onTap: _openSchedules,
            child: _scheduleCount == 0
                ? SizedBox(
                    width: double.infinity,
                    height: 72,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 20, color: colors.onSurfaceVariant),
                        const SizedBox(height: 10),
                        Text(
                          'Nothing scheduled yet',
                          style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$_scheduleCount ${_scheduleCount == 1 ? 'schedule' : 'schedules'}',
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 18, color: colors.onSurfaceVariant),
                    ],
                  ),
          ),
        ),
        _OutlinedButton(label: 'Add schedule', onPressed: _openSchedules),
      ],
    );
  }
}

/// Mindful Timer: a card per app group with its daily budget bar, a nudge to
/// grant usage access (budgets are measured from it), and + for a new timer.
class MindfulTimerPage extends StatefulWidget {
  const MindfulTimerPage({super.key});

  @override
  State<MindfulTimerPage> createState() => _MindfulTimerPageState();
}

class _MindfulTimerPageState extends State<MindfulTimerPage> {
  final _timer = const MindfulTimerService();
  late final _lifecycle = AppLifecycleListener(onResume: _refresh);
  List<(TimerGroup, Duration)>? _groups;
  Map<String, AppInfo> _apps = const {};
  var _hasUsageAccess = true;

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final (groups, apps) = await (_timer.groups(), const InstalledAppsService().loadApps()).wait;
    var access = true;
    try {
      access = await const UsageStatsService().hasAccess();
    } catch (_) {
      // No usage channel (tests).
    }
    final now = DateTime.now();
    final withUsage = [for (final g in groups) (g, access ? await groupUsageToday(g, now) : Duration.zero)];
    if (!mounted) return;
    setState(() {
      _groups = withUsage;
      _apps = {for (final app in apps) app.packageName: app};
      _hasUsageAccess = access;
    });
  }

  Future<void> _edit([TimerGroup? group]) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TimerGroupEditor(group: group)));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final colors = Theme.of(context).colorScheme;
    return _ToolScaffold(
      toolId: 'mindful_timer',
      title: 'Mindful Timer',
      floatingActionButton: FloatingActionButton(
        tooltip: 'New timer',
        onPressed: _edit,
        shape: const CircleBorder(),
        backgroundColor: colors.surfaceContainerHighest,
        foregroundColor: colors.onSurface,
        elevation: 0,
        child: const Icon(Icons.add),
      ),
      children: [
        if (!_hasUsageAccess)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _Box(
              onTap: const UsageStatsService().requestAccess,
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Allow usage access', style: TextStyle(fontSize: 15)),
                        SizedBox(height: 2),
                        Text('Daily limits are measured from your app usage.', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: colors.onSurfaceVariant),
                ],
              ),
            ),
          ),
        if (groups != null && groups.isEmpty)
          Text(
            'No timers yet. Tap + to give a group of apps a daily limit.',
            style: TextStyle(fontSize: 15, color: colors.onSurfaceVariant),
          ),
        if (groups != null)
          for (final (group, used) in groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TimerCard(group: group, used: used, apps: _apps, onTap: () => _edit(group)),
            ),
      ],
    );
  }
}

/// The only colour in the original's Mind Space: budget left, in green.
const _budgetGreen = Color(0xFF6BAE73);

class _TimerCard extends StatelessWidget {
  const _TimerCard({required this.group, required this.used, required this.apps, required this.onTap});

  final TimerGroup group;
  final Duration used;
  final Map<String, AppInfo> apps;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final budget = Duration(minutes: group.dailyMinutes);
    final left = budget - used;
    final cooldown = group.cooldownMinutes == 0 ? 'no cooldown' : '${group.cooldownMinutes} min cooldown';
    return _Box(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(group.name, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 2),
          Text(
            '${group.dailyMinutes} min budget · $cooldown',
            style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final p in group.packages.take(8))
                if (apps[p] case final app?) AppIcon(icon: app.icon, size: 24),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: budget == Duration.zero ? 1 : (used.inSeconds / budget.inSeconds).clamp(0.0, 1.0),
              minHeight: 3,
              color: _budgetGreen,
              backgroundColor: colors.outlineVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('DAILY BUDGET', style: TextStyle(fontSize: 11, letterSpacing: 0.5, color: colors.onSurfaceVariant)),
              const Spacer(),
              Text(
                left <= Duration.zero ? 'Used up today' : '${left.inMinutes} min left',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: left <= Duration.zero ? colors.onSurfaceVariant : _budgetGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mindful Break: the apps currently put away, each with when it's back and
/// a way to end the break early, plus "Start a break" to put one away.
class MindfulBreakPage extends StatefulWidget {
  const MindfulBreakPage({super.key});

  @override
  State<MindfulBreakPage> createState() => _MindfulBreakPageState();
}

class _MindfulBreakPageState extends State<MindfulBreakPage> {
  final _break = const MindfulBreakService();
  List<AppInfo>? _apps;
  Map<String, DateTime> _breaks = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final (apps, breaks) = await (
      _apps == null ? const InstalledAppsService().loadApps() : Future.value(_apps!),
      _break.breaks(),
    ).wait;
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _breaks = breaks;
    });
  }

  Future<void> _takeBreak() async {
    final apps = _apps;
    if (apps == null) return;
    final app = await showAppPicker(context, [
      for (final a in apps)
        if (!_breaks.containsKey(a.packageName)) a,
    ], title: 'Take a break from');
    if (app == null || !mounted) return;
    final days = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Put ${app.name} away for', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final days in MindfulBreakService.lengthsInDays)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text(days == 7 ? '1 week' : '$days ${days == 1 ? 'day' : 'days'}'),
                onTap: () => Navigator.of(context).pop(days),
              ),
          ],
        ),
      ),
    );
    if (days == null) return;
    await _break.start(app.packageName, days);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final apps = _apps;
    final colors = Theme.of(context).colorScheme;
    final onBreak = [
      if (apps != null)
        for (final app in apps)
          if (_breaks.containsKey(app.packageName)) app,
    ];
    return _ToolScaffold(
      toolId: 'mindful_break',
      title: 'Mindful Break',
      children: [
        if (apps != null && onBreak.isEmpty) ...[
          const Text('Nothing is blocked right now.', style: TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          Text(
            'Pick one app and step away from it for a few days. It stays blocked until the time is up.',
            style: TextStyle(fontSize: 15, height: 1.6, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
        ],
        for (final app in onBreak)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Box(
              child: Row(
                children: [
                  AppIcon(icon: app.icon, size: 34),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(app.name, style: const TextStyle(fontSize: 15)),
                        Text(
                          breakEndLabel(context, _breaks[app.packageName]!),
                          style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _break.end(app.packageName);
                      await _refresh();
                    },
                    style: TextButton.styleFrom(foregroundColor: colors.onSurface),
                    child: const Text('End'),
                  ),
                ],
              ),
            ),
          ),
        if (onBreak.isNotEmpty) const SizedBox(height: 12),
        _OutlinedButton(label: 'Start a break', icon: Icons.add, onPressed: apps == null ? null : _takeBreak),
      ],
    );
  }
}

/// The original's tool page chrome: ‹ back, a letter-spaced title, and ⓘ to
/// reread the tool's explainer.
class _ToolScaffold extends StatelessWidget {
  const _ToolScaffold({required this.toolId, required this.title, required this.children, this.floatingActionButton});

  final String toolId;
  final String title;
  final List<Widget> children;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.chevron_left, size: 30), onPressed: Navigator.of(context).maybePop),
        titleSpacing: 0,
        title: Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, letterSpacing: 2)),
        actions: [
          IconButton(
            tooltip: 'About $title',
            icon: const Icon(Icons.info_outline),
            onPressed: () => mindSpaceTools.firstWhere((t) => t.id == toolId).showInfo(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: floatingActionButton,
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: children),
    );
  }
}

/// A titled block: a heading (and optional line under it) over its content.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
          if (subtitle case final subtitle?) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// The original's outlined box on the card fill, optionally tappable.
class _Box extends StatelessWidget {
  const _Box({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: colors.outline),
    );
    return Material(
      color: colors.surfaceContainer,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

/// The chosen apps as filled rows, then Manage Apps (Mindful Pause).
class _AppsBox extends StatelessWidget {
  const _AppsBox({required this.apps, required this.onManage});

  final List<AppInfo> apps;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget filled({required Widget child, VoidCallback? onTap}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(height: 52, child: child),
        ),
      ),
    );
    return _Box(
      child: Column(
        children: [
          for (final app in apps)
            filled(
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  AppIcon(icon: app.icon, size: 30),
                  const SizedBox(width: 12),
                  Expanded(child: Text(app.name, style: const TextStyle(fontSize: 15))),
                ],
              ),
            ),
          filled(
            onTap: onManage,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_outlined, size: 18, color: colors.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('Manage Apps', style: TextStyle(fontSize: 15, color: colors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width outlined button, as the original's "Add schedule" and
/// "Start a break".
class _OutlinedButton extends StatelessWidget {
  const _OutlinedButton({required this.label, required this.onPressed, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.onSurface,
        side: BorderSide(color: colors.outline),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon case final icon?) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
