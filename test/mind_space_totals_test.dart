import 'package:flutter_test/flutter_test.dart';
import 'package:launcher/panels/mind_space_panel.dart';
import 'package:launcher/services/usage_stats_service.dart';

void main() {
  test('computeMindSpaceTotals pairs foreground/background and counts unlocks', () {
    final base = DateTime(2026, 1, 1, 9);
    final totals = computeMindSpaceTotals([
      UsageEvent(packageName: 'a', type: UsageEventType.unlocked, timestamp: base),
      UsageEvent(packageName: 'a', type: UsageEventType.foreground, timestamp: base),
      UsageEvent(
        packageName: 'a',
        type: UsageEventType.background,
        timestamp: base.add(const Duration(minutes: 5)),
      ),
      UsageEvent(
        packageName: 'b',
        type: UsageEventType.foreground,
        timestamp: base.add(const Duration(minutes: 10)),
      ),
      UsageEvent(
        packageName: 'b',
        type: UsageEventType.background,
        timestamp: base.add(const Duration(minutes: 12)),
      ),
    ]);

    expect(totals.screenTime, const Duration(minutes: 7));
    expect(totals.pickups, 1);
  });

  test('formatScreenTime', () {
    expect(formatScreenTime(const Duration(minutes: 5)), '5m');
    expect(formatScreenTime(const Duration(hours: 1, minutes: 30)), '1h 30m');
  });

  test('computeHourlyUsage splits an interval across an hour boundary', () {
    final now = DateTime(2026, 1, 1, 10, 30);
    final buckets = computeHourlyUsage([
      UsageEvent(
        packageName: 'a',
        type: UsageEventType.foreground,
        timestamp: DateTime(2026, 1, 1, 8, 50),
      ),
      UsageEvent(
        packageName: 'a',
        type: UsageEventType.background,
        timestamp: DateTime(2026, 1, 1, 9, 10),
      ),
    ], now);

    expect(buckets.length, 11); // hours 0..10 inclusive
    expect(buckets[8], const Duration(minutes: 10));
    expect(buckets[9], const Duration(minutes: 10));
    expect(buckets[10], Duration.zero);
  });

  test('computePerAppUsage counts opens/time per package and sorts by time', () {
    final base = DateTime(2026, 1, 1, 9);
    final perApp = computePerAppUsage([
      UsageEvent(packageName: 'a', type: UsageEventType.foreground, timestamp: base),
      UsageEvent(
        packageName: 'a',
        type: UsageEventType.background,
        timestamp: base.add(const Duration(minutes: 2)),
      ),
      UsageEvent(
        packageName: 'a',
        type: UsageEventType.foreground,
        timestamp: base.add(const Duration(minutes: 5)),
      ),
      UsageEvent(
        packageName: 'a',
        type: UsageEventType.background,
        timestamp: base.add(const Duration(minutes: 9)),
      ),
      UsageEvent(
        packageName: 'b',
        type: UsageEventType.foreground,
        timestamp: base.add(const Duration(minutes: 20)),
      ),
      UsageEvent(
        packageName: 'b',
        type: UsageEventType.background,
        timestamp: base.add(const Duration(minutes: 21)),
      ),
    ]);

    expect(perApp.length, 2);
    expect(perApp[0].packageName, 'a');
    expect(perApp[0].opens, 2);
    expect(perApp[0].duration, const Duration(minutes: 6));
    expect(perApp[0].averagePerOpen, const Duration(minutes: 3));
    expect(perApp[1].packageName, 'b');
    expect(perApp[1].opens, 1);
  });

  test('computeHabits finds the app most often opened right after unlock', () {
    final base = DateTime(2026, 1, 1, 9);
    final habits = computeHabits([
      // Unlock -> opens app "a" first (twice).
      UsageEvent(packageName: '', type: UsageEventType.unlocked, timestamp: base),
      UsageEvent(
        packageName: 'a',
        type: UsageEventType.foreground,
        timestamp: base.add(const Duration(seconds: 5)),
      ),
      UsageEvent(
        packageName: 'a',
        type: UsageEventType.background,
        timestamp: base.add(const Duration(minutes: 1)),
      ),
      UsageEvent(
        packageName: '',
        type: UsageEventType.unlocked,
        timestamp: base.add(const Duration(minutes: 10)),
      ),
      UsageEvent(
        packageName: 'a',
        type: UsageEventType.foreground,
        timestamp: base.add(const Duration(minutes: 10, seconds: 3)),
      ),
      // Unlock -> opens app "b" first.
      UsageEvent(
        packageName: '',
        type: UsageEventType.unlocked,
        timestamp: base.add(const Duration(minutes: 20)),
      ),
      UsageEvent(
        packageName: 'b',
        type: UsageEventType.foreground,
        timestamp: base.add(const Duration(minutes: 20, seconds: 2)),
      ),
    ]);

    expect(habits.topPackage, 'a');
    expect(habits.topCount, 2);
    expect(habits.totalUnlocks, 3);
  });
}
