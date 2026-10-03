import 'package:flutter/material.dart';

import '../panels/mind_space_panel.dart';
import '../services/usage_stats_service.dart';

/// One calendar day's totals, for the Reflect trend.
class DayTotals {
  const DayTotals({required this.day, required this.totals});

  final DateTime day;
  final MindSpaceTotals totals;
}

/// Per-day totals for the [days] days ending with [now]'s day, oldest first.
/// Leading days with no events at all are dropped, since Android only keeps
/// a few days to a couple of weeks of events and "no data" isn't "no use".
// ponytail: a session spanning midnight is lost (its foreground and
// background events land in different days); fine for a daily trend.
List<DayTotals> computeDailyTotals(List<UsageEvent> events, DateTime now, {int days = 14}) {
  final result = <DayTotals>[];
  for (var i = days - 1; i >= 0; i--) {
    final start = DateTime(now.year, now.month, now.day - i);
    final end = DateTime(start.year, start.month, start.day + 1);
    final dayEvents = [
      for (final e in events)
        if (!e.timestamp.isBefore(start) && e.timestamp.isBefore(end)) e,
    ];
    if (result.isEmpty && dayEvents.isEmpty) continue;
    result.add(DayTotals(day: start, totals: computeMindSpaceTotals(dayEvents)));
  }
  return result;
}

/// One line comparing the last (up to) 7 full days with the 7 before them.
/// [daily] is oldest first and ends with today, which is left out as partial.
String trendSummary(List<DayTotals> daily) {
  final full = daily.length > 1 ? daily.sublist(0, daily.length - 1) : const <DayTotals>[];
  if (full.length < 2) return 'Not enough history yet to see a trend.';
  Duration average(Iterable<DayTotals> days) =>
      days.fold<Duration>(Duration.zero, (sum, d) => sum + d.totals.screenTime) ~/ days.length;
  final recent = full.length > 7 ? full.sublist(full.length - 7) : full.sublist(full.length ~/ 2);
  final earlier = full.sublist(0, full.length - recent.length);
  final now = average(recent);
  final before = average(earlier.length > 7 ? earlier.sublist(earlier.length - 7) : earlier);
  final perDay = formatScreenTime(now);
  if (before == Duration.zero) return 'About $perDay a day lately.';
  final change = ((now.inSeconds - before.inSeconds) / before.inSeconds * 100).round();
  if (change.abs() < 10) return 'Holding steady at about $perDay a day.';
  return change < 0
      ? 'Down ${-change}% from the days before, about $perDay a day.'
      : 'Up $change% from the days before, about $perDay a day.';
}

/// Mind Space's Reflect view: yesterday's totals, a daily screen-time bar
/// chart for up to 14 days, and a one-line trend summary.
class ReflectView extends StatelessWidget {
  const ReflectView({super.key, required this.daily, required this.isDark});

  final List<DayTotals> daily;
  final bool isDark;

  static const _barHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.onSurface;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final barColor = Theme.of(context).colorScheme.onSurface;
    final yesterday = daily.length > 1 ? daily[daily.length - 2].totals : null;
    final longest = daily.fold<int>(
      1,
      (max, d) => d.totals.screenTime.inSeconds > max ? d.totals.screenTime.inSeconds : max,
    );
    final weekdays = MaterialLocalizations.of(context).narrowWeekdays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Screen time yesterday',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: secondary),
        ),
        const SizedBox(height: 8),
        Text(
          yesterday == null ? '—' : formatScreenTime(yesterday.screenTime),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 48, fontWeight: FontWeight.w500, color: primary),
        ),
        const SizedBox(height: 24),
        Text(
          yesterday == null ? 'No data for yesterday' : '${yesterday.pickups} pickups',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: secondary),
        ),
        const SizedBox(height: 40),
        Text(
          'Last ${daily.length} ${daily.length == 1 ? 'day' : 'days'}',
          style: TextStyle(fontSize: 13, color: secondary),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _barHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, d) in daily.indexed)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: FractionallySizedBox(
                      alignment: Alignment.bottomCenter,
                      heightFactor: (d.totals.screenTime.inSeconds / longest).clamp(0.02, 1.0),
                      // Today is still in progress, so it's drawn faded.
                      child: Container(color: i == daily.length - 1 ? barColor.withValues(alpha: 0.35) : barColor),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final d in daily)
              Expanded(
                child: Text(
                  weekdays[d.day.weekday % 7],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text(trendSummary(daily), style: TextStyle(fontSize: 16, color: primary)),
      ],
    );
  }
}
