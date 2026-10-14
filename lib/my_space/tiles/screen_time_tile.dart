import '../../state/settled_resume.dart';
import '../../widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../../panels/mind_space_panel.dart';
import '../../search/app_result_row.dart';
import '../../services/app_customizations_service.dart';
import '../../services/productive_apps_service.dart';
import '../../services/usage_stats_service.dart';
import '../tile_card.dart';

/// What the tile shows: today's totals and the three most-used apps, with
/// productive apps left out, same as Mind Space's Awareness tab.
typedef ScreenTimeSummary = ({MindSpaceTotals totals, List<(PerAppUsage, AppInfo?)> topApps});

/// Screen Time tile: today's screen time, pickups, and top three apps with
/// opens and time, from the same computations as Mind Space. Re-reads on
/// resume; asks for usage access if it's missing.
class ScreenTimeTile extends StatefulWidget {
  const ScreenTimeTile({super.key});

  @override
  State<ScreenTimeTile> createState() => _ScreenTimeTileState();
}

class _ScreenTimeTileState extends State<ScreenTimeTile> {
  final _usage = const UsageStatsService();
  late final _lifecycle = SettledResumeListener(_load);
  bool? _hasAccess;
  ScreenTimeSummary? _summary;

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _load();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (!await _usage.hasAccess()) {
        if (mounted) setState(() => _hasAccess = false);
        return;
      }
      final now = DateTime.now();
      final (events, productive, apps) = await (
        _usage.queryEvents(start: DateTime(now.year, now.month, now.day), end: now),
        const ProductiveAppsService().apps(),
        loadCustomizedApps(includeHidden: true),
      ).wait;
      final today = withoutProductive(events, productive);
      final byPackage = {for (final app in apps) app.packageName: app};
      if (!mounted) return;
      setState(() {
        _hasAccess = true;
        _summary = (
          totals: computeMindSpaceTotals(today),
          // Only apps you can open, like Mind Space's per-app rows.
          topApps: [
            for (final u in computePerAppUsage(today).where((u) => byPackage.containsKey(u.packageName)).take(3))
              (u, byPackage[u.packageName]),
          ],
        );
      });
    } catch (_) {
      if (mounted) setState(() => _hasAccess = false); // No usage channel (tests).
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return TileCard(
      label: 'SCREEN TIME',
      icon: Icons.hourglass_empty,
      child: switch (_hasAccess) {
        null => const SkeletonLines(lines: 2),
        false => Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: _usage.requestAccess,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('Allow usage access'),
          ),
        ),
        true => ScreenTimeBody(summary: summary!),
      },
    );
  }
}

/// The totals and top-apps rows, shared with the Add New Tile preview.
class ScreenTimeBody extends StatelessWidget {
  const ScreenTimeBody({super.key, required this.summary});

  final ScreenTimeSummary summary;

  @override
  Widget build(BuildContext context) {
    final secondary = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              formatScreenTime(summary.totals.screenTime),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Text('${summary.totals.pickups} pickups', style: secondary),
          ],
        ),
        for (final (usage, app) in summary.topApps)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                AppIcon(icon: app?.icon, size: 28),
                const SizedBox(width: 10),
                Expanded(child: Text(app?.name ?? usage.packageName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text(
                  '${usage.opens} ${usage.opens == 1 ? 'open' : 'opens'} · ${formatScreenTime(usage.duration)}',
                  style: secondary,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
