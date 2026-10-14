import '../../state/settled_resume.dart';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../../search/app_result_row.dart';
import '../../services/app_customizations_service.dart';
import '../../services/data_usage_service.dart';
import '../../services/usage_stats_service.dart';
import '../../widgets/skeleton.dart';
import '../on_screen.dart';
import '../tile_card.dart';

/// What the tile shows: today's and this month's data, and today's top apps.
typedef DataUsageSummary = ({DataUsage today, DataUsage month, List<(AppDataUse, AppInfo?)> topApps});

/// Data Usage tile: mobile data and Wi-Fi used today and this month, plus
/// the three apps using the most today. Re-reads on resume and while My Space
/// is showing; asks for usage access if it's missing.
class DataUsageTile extends StatefulWidget {
  const DataUsageTile({super.key});

  @override
  State<DataUsageTile> createState() => _DataUsageTileState();
}

class _DataUsageTileState extends State<DataUsageTile> with PollsWhileOnScreen {
  final _usage = const UsageStatsService();
  late final _lifecycle = SettledResumeListener(poll);
  bool? _hasAccess;
  DataUsageSummary? _summary;

  // Totals move slowly; a minute is plenty.
  @override
  Duration get pollInterval => const Duration(minutes: 1);

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Future<void> poll() async {
    try {
      if (!await _usage.hasAccess()) {
        if (mounted) setState(() => _hasAccess = false);
        return;
      }
      final now = DateTime.now();
      const service = DataUsageService();
      final (today, month, apps) = await (
        service.usage(start: DateTime(now.year, now.month, now.day), end: now, topApps: 3),
        service.usage(start: DateTime(now.year, now.month), end: now),
        loadCustomizedApps(includeHidden: true),
      ).wait;
      final byPackage = {for (final app in apps) app.packageName: app};
      if (!mounted) return;
      setState(() {
        _hasAccess = true;
        _summary = (today: today, month: month, topApps: [for (final a in today.apps) (a, byPackage[a.packageName])]);
      });
    } catch (_) {
      if (mounted) setState(() => _hasAccess = false); // No usage channel (tests).
    }
  }

  @override
  Widget build(BuildContext context) {
    return TileCard(
      label: 'DATA USAGE',
      icon: Icons.swap_vert,
      child: switch (_hasAccess) {
        null => const SkeletonLines(lines: 3),
        false => Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(onPressed: _usage.requestAccess, child: const Text('Allow usage access')),
        ),
        true => DataUsageBody(summary: _summary!),
      },
    );
  }
}

/// The totals and top-apps rows, shared with the Add New Tile preview.
class DataUsageBody extends StatelessWidget {
  const DataUsageBody({super.key, required this.summary});

  final DataUsageSummary summary;

  @override
  Widget build(BuildContext context) {
    final secondary = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    Widget column(String title, DataUsage usage) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: secondary),
          const SizedBox(height: 4),
          Text(formatBytes(usage.mobile + usage.wifi), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('${formatBytes(usage.mobile)} mobile', style: secondary),
          Text('${formatBytes(usage.wifi)} Wi-Fi', style: secondary),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [column('Today', summary.today), column('This month', summary.month)]),
        for (final (usage, app) in summary.topApps)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                AppIcon(icon: app?.icon, size: 28),
                const SizedBox(width: 10),
                Expanded(child: Text(app?.name ?? usage.packageName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text(formatBytes(usage.mobile + usage.wifi), style: secondary),
              ],
            ),
          ),
      ],
    );
  }
}
