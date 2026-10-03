import 'package:flutter_test/flutter_test.dart';
import 'package:launcher/services/mindful_timer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = MindfulTimerService();
  const browsing = TimerGroup(
    id: 'b',
    name: 'Browsing',
    packages: {'com.chrome'},
    dailyMinutes: 30,
    cooldownMinutes: 15,
  );
  final noon = DateTime(2026, 10, 3, 12);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('groups save, update, and delete', () async {
    expect(await service.groups(), isEmpty);
    await service.saveGroup(browsing);
    expect((await service.groupFor('com.chrome'))?.name, 'Browsing');
    expect(await service.groupFor('com.camera'), isNull);

    await service.saveGroup(
      const TimerGroup(id: 'b', name: 'Web', packages: {'com.chrome'}, dailyMinutes: 10),
    );
    expect((await service.groups()).single.name, 'Web');

    await service.deleteGroup('b');
    expect(await service.groups(), isEmpty);
  });

  test('blocks once the daily budget is used up', () async {
    expect(await service.blockFor(browsing, const Duration(minutes: 29), noon), isNull);
    expect(await service.blockFor(browsing, const Duration(minutes: 30), noon), isA<BudgetSpent>());
  });

  test('sessions count up and start a cooldown after they end', () async {
    await service.startSession(browsing, 'com.chrome', 'Chrome', 5, noon);
    expect(await service.sessionsToday(browsing, noon), 1);

    // Session ends at 12:05, so the 15-minute cooldown runs until 12:20.
    final block = await service.blockFor(browsing, Duration.zero, noon.add(const Duration(minutes: 10)));
    expect(block, isA<CoolingDown>().having((b) => b.until, 'until', DateTime(2026, 10, 3, 12, 20)));
    expect(await service.blockFor(browsing, Duration.zero, DateTime(2026, 10, 3, 12, 21)), isNull);

    // A new day starts a fresh log.
    expect(await service.sessionsToday(browsing, DateTime(2026, 10, 4, 9)), 0);
  });
}
