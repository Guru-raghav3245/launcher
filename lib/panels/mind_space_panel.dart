import 'package:flutter/material.dart';

import '../services/usage_stats_service.dart';

/// Mind Space panel: screen-time insights. Phase 4 task 1 (usage-stats
/// permission + data source) is wired up below just enough to prove it
/// round-trips real data; the real scaffold (screen time, pickups) lands
/// in task 2.
class MindSpacePanel extends StatefulWidget {
  const MindSpacePanel({super.key});

  @override
  State<MindSpacePanel> createState() => _MindSpacePanelState();
}

class _MindSpacePanelState extends State<MindSpacePanel> with WidgetsBindingObserver {
  final _service = const UsageStatsService();
  bool? _hasAccess;
  int? _eventCountToday;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    final startOfDay = DateTime(now.year, now.month, now.day);
    final events = await _service.queryEvents(start: startOfDay, end: now);
    if (mounted) {
      setState(() {
        _hasAccess = true;
        _eventCountToday = events.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAccess = _hasAccess;
    return Center(
      child: hasAccess == null
          ? const CircularProgressIndicator()
          : hasAccess
          ? Text('Usage events today: ${_eventCountToday ?? 0}')
          : FilledButton(
              onPressed: _service.requestAccess,
              child: const Text('Grant usage access'),
            ),
    );
  }
}
