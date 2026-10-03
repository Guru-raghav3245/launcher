import 'package:flutter_test/flutter_test.dart';
import 'package:launcher/mind_space/reflect_view.dart';
import 'package:launcher/panels/mind_space_panel.dart';
import 'package:launcher/services/productive_apps_service.dart';
import 'package:launcher/services/usage_stats_service.dart';

/// A [minutes]-long session of [pkg] starting at [start].
List<UsageEvent> session(String pkg, DateTime start, int minutes) => [
  UsageEvent(packageName: pkg, type: UsageEventType.foreground, timestamp: start),
  UsageEvent(packageName: pkg, type: UsageEventType.background, timestamp: start.add(Duration(minutes: minutes))),
];

DayTotals day(int minutes) => DayTotals(
  day: DateTime(2026),
  totals: MindSpaceTotals(screenTime: Duration(minutes: minutes), pickups: 0),
);

void main() {
  final now = DateTime(2026, 10, 3, 15);

  test('daily totals split events by day and skip days before data begins', () {
    final daily = computeDailyTotals([
      ...session('a', DateTime(2026, 10, 1, 9), 30),
      ...session('b', DateTime(2026, 10, 3, 10), 20),
    ], now);
    expect(daily.map((d) => d.day.day), [1, 2, 3]);
    expect(daily.map((d) => d.totals.screenTime.inMinutes), [30, 0, 20]);
  });

  test('trend compares recent days with the ones before, leaving out today', () {
    expect(trendSummary([day(60), day(5)]), 'Not enough history yet to see a trend.');
    expect(trendSummary([day(60), day(62), day(0)]), 'Holding steady at about 1h 2m a day.');
    expect(trendSummary([day(120), day(60), day(999)]), 'Down 50% from the days before, about 1h 0m a day.');
    // More than a week: the last 7 full days against up to 7 before them.
    expect(
      trendSummary([for (var i = 0; i < 7; i++) day(60), for (var i = 0; i < 7; i++) day(90), day(0)]),
      'Up 50% from the days before, about 1h 30m a day.',
    );
  });

  test('productive apps are left out, but unlocks still count', () {
    final events = [
      UsageEvent(packageName: 'android', type: UsageEventType.unlocked, timestamp: now),
      ...session('work', now, 30),
      ...session('feed', now, 10),
    ];
    final totals = computeMindSpaceTotals(withoutProductive(events, {'work'}));
    expect(totals.screenTime, const Duration(minutes: 10));
    expect(totals.pickups, 1);
  });
}
