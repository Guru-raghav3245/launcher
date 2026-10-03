import 'package:flutter/material.dart';

import '../panels/mind_space_panel.dart';
import '../search/app_multi_picker_sheet.dart';
import '../services/focus_mode_service.dart';
import '../services/mindful_pause_service.dart';
import '../services/mindful_timer_service.dart';
import '../services/usage_stats_service.dart';
import 'timer_group_editor.dart';

/// Mindful Pause settings: how long the breathing screen lasts, and which
/// apps get it.
class MindfulPausePage extends StatefulWidget {
  const MindfulPausePage({super.key});

  @override
  State<MindfulPausePage> createState() => _MindfulPausePageState();
}

class _MindfulPausePageState extends State<MindfulPausePage> {
  final _pause = const MindfulPauseService();
  int? _seconds;
  int _appCount = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final (seconds, apps) = await (_pause.seconds(), _pause.pausedApps()).wait;
    if (!mounted) return;
    setState(() {
      _seconds = seconds;
      _appCount = apps.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _seconds;
    final ink = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
    return _ToolScaffold(
      title: 'Mindful Pause',
      children: seconds == null
          ? const []
          : [
              Text('Pause length · $seconds seconds', style: const TextStyle(fontSize: 18)),
              Slider(
                value: seconds.toDouble(),
                min: MindfulPauseService.minSeconds.toDouble(),
                max: MindfulPauseService.maxSeconds.toDouble(),
                divisions: (MindfulPauseService.maxSeconds - MindfulPauseService.minSeconds) ~/ 5,
                label: '${seconds}s',
                activeColor: ink,
                inactiveColor: ink.withValues(alpha: 0.12),
                onChanged: (value) => setState(() => _seconds = value.round()),
                onChangeEnd: (value) => _pause.setSeconds(value.round()),
              ),
              const SizedBox(height: 16),
              _AppsRow(
                title: 'Paused apps',
                count: _appCount,
                onTap: () async {
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
            ],
    );
  }
}

/// Focus Mode: start a session (Pause / Timer / Focus Mode tiles) and pick
/// the apps that stay usable during one.
class FocusModePage extends StatefulWidget {
  const FocusModePage({super.key});

  @override
  State<FocusModePage> createState() => _FocusModePageState();
}

class _FocusModePageState extends State<FocusModePage> {
  final _focusMode = const FocusModeService();
  int _allowedCount = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final allowed = await _focusMode.essentials();
    if (mounted) setState(() => _allowedCount = allowed.length);
  }

  @override
  Widget build(BuildContext context) {
    return _ToolScaffold(
      title: 'Focus Mode',
      children: [
        const FocusQuickActions(),
        const SizedBox(height: 24),
        _AppsRow(
          title: 'Allowed apps',
          count: _allowedCount,
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
        ),
      ],
    );
  }
}

/// Mindful Timer: the app groups with a daily limit, plus a nudge to grant
/// usage access, which the limits are measured with.
class MindfulTimerPage extends StatefulWidget {
  const MindfulTimerPage({super.key});

  @override
  State<MindfulTimerPage> createState() => _MindfulTimerPageState();
}

class _MindfulTimerPageState extends State<MindfulTimerPage> {
  final _timer = const MindfulTimerService();
  late final _lifecycle = AppLifecycleListener(onResume: _refresh);
  List<TimerGroup>? _groups;
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
    final groups = await _timer.groups();
    var access = true;
    try {
      access = await const UsageStatsService().hasAccess();
    } catch (_) {
      // No usage channel (tests).
    }
    if (!mounted) return;
    setState(() {
      _groups = groups;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stroke = isDark ? Colors.white24 : Colors.black26;
    return _ToolScaffold(
      title: 'Mindful Timer',
      children: [
        if (!_hasUsageAccess)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.query_stats),
              title: const Text('Allow usage access'),
              subtitle: const Text('Daily limits are measured from your app usage.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: const UsageStatsService().requestAccess,
            ),
          ),
        if (groups != null)
          for (final group in groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: stroke), borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  leading: const Icon(Icons.timer_outlined),
                  title: Text(group.name, style: const TextStyle(fontSize: 18)),
                  subtitle: Text(
                    '${group.packages.length} ${group.packages.length == 1 ? 'app' : 'apps'} · '
                    '${formatScreenTime(Duration(minutes: group.dailyMinutes))} a day'
                    '${group.cooldownMinutes == 0 ? '' : ' · ${group.cooldownMinutes} min cooldown'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _edit(group),
                ),
              ),
            ),
        OutlinedButton.icon(
          onPressed: _edit,
          icon: const Icon(Icons.add),
          label: const Text('New timer'),
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? Colors.white : Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

class _ToolScaffold extends StatelessWidget {
  const _ToolScaffold({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 24), children: children),
    );
  }
}

/// Outlined row opening an app picker, with how many apps are chosen.
class _AppsRow extends StatelessWidget {
  const _AppsRow({required this.title, required this.count, required this.onTap});

  final String title;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? Colors.white24 : Colors.black26),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: const Icon(Icons.apps),
        title: Text(title, style: const TextStyle(fontSize: 18)),
        subtitle: Text(count == 0 ? 'None yet' : '$count ${count == 1 ? 'app' : 'apps'}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
