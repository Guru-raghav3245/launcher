import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../panels/mind_space_panel.dart';
import '../services/usage_stats_service.dart';

/// Shows the Mindful Pause breathing screen before [app] opens. Resolves to
/// true once the [seconds]-long pause completes (open the app), or false if
/// the user skips it ("I'll skip this time", back button).
Future<bool> showMindfulPause(BuildContext context, AppInfo app, int seconds) async {
  final open = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _MindfulPauseDialog(app: app, seconds: seconds),
  );
  return open ?? false;
}

class _MindfulPauseDialog extends StatefulWidget {
  const _MindfulPauseDialog({required this.app, required this.seconds});

  final AppInfo app;
  final int seconds;

  @override
  State<_MindfulPauseDialog> createState() => _MindfulPauseDialogState();
}

class _MindfulPauseDialogState extends State<_MindfulPauseDialog> with TickerProviderStateMixin {
  late final _progress = AnimationController(vsync: this, duration: Duration(seconds: widget.seconds));

  // One slow inhale/exhale cycle, looping for the whole pause.
  late final _breath = AnimationController(vsync: this, duration: const Duration(seconds: 4))
    ..repeat(reverse: true);

  PerAppUsage? _usage;

  @override
  void initState() {
    super.initState();
    _progress
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) Navigator.of(context).pop(true);
      })
      ..forward();
    _loadUsage();
  }

  /// Today's time and opens for this app; stays hidden without usage access.
  Future<void> _loadUsage() async {
    const service = UsageStatsService();
    try {
      if (!await service.hasAccess()) return;
      final now = DateTime.now();
      final events = await service.queryEvents(start: DateTime(now.year, now.month, now.day), end: now);
      final usage = computePerAppUsage(events).where((u) => u.packageName == widget.app.packageName);
      if (mounted) {
        setState(
          () => _usage = usage.isEmpty
              ? PerAppUsage(packageName: widget.app.packageName, opens: 0, duration: Duration.zero)
              : usage.first,
        );
      }
    } catch (_) {
      // No usage channel (tests) — just leave the stats out.
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : Colors.black;
    final secondary = isDark ? Colors.white60 : Colors.black54;
    final usage = _usage;
    // Back simply pops with null, which showMindfulPause treats as a skip.
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Mindful Pause', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Take a deep breath and relax.', style: TextStyle(fontSize: 16, color: secondary)),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: AnimatedBuilder(
                animation: _breath,
                builder: (context, _) => _BreathingCircles(t: _breath.value, ink: ink),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: _progress,
              builder: (context, _) => LinearProgressIndicator(
                value: _progress.value,
                color: ink,
                backgroundColor: ink.withValues(alpha: 0.12),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (usage != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _Stat(label: "Today's usage", value: formatScreenTime(usage.duration))),
                  _Stat(
                    label: 'Opens today',
                    value: '${usage.opens} ${usage.opens == 1 ? 'time' : 'times'}',
                    alignEnd: true,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: FilledButton.styleFrom(
                  backgroundColor: ink,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("I'll skip this time", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${widget.app.name} will open automatically after the pause.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Concentric circles that swell and settle with each breath ([t] 0→1→0),
/// around a meditating-figure icon. Grayscale only, per DESIGN_LANGUAGE.md.
class _BreathingCircles extends StatelessWidget {
  const _BreathingCircles({required this.t, required this.ink});

  final double t;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeInOut.transform(t);
    return Stack(
      alignment: Alignment.center,
      children: [
        for (final (size, alpha) in [(200.0, 0.05), (160.0, 0.08), (120.0, 0.12)])
          Container(
            width: size * (0.8 + 0.2 * eased),
            height: size * (0.8 + 0.2 * eased),
            decoration: BoxDecoration(shape: BoxShape.circle, color: ink.withValues(alpha: alpha)),
          ),
        Icon(Icons.self_improvement, size: 64, color: ink.withValues(alpha: 0.8)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.alignEnd = false});

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
