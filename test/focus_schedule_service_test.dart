import 'package:flutter_test/flutter_test.dart';
import 'package:launcher/services/focus_mode_service.dart';
import 'package:launcher/services/focus_schedule_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = FocusScheduleService();
  const deepWork = FocusSchedule(
    id: 'd',
    name: 'Deep work',
    days: {DateTime.monday, DateTime.wednesday},
    hour: 9,
    minute: 0,
    durationMinutes: 60,
    strict: true,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('next weekday time is the coming occurrence, never now or earlier', () {
    // Saturday 3 Oct 2026, 12:00.
    final saturdayNoon = tz.TZDateTime.utc(2026, 10, 3, 12);
    expect(nextWeekdayTime(saturdayNoon, DateTime.monday, 9, 0), tz.TZDateTime.utc(2026, 10, 5, 9));
    expect(nextWeekdayTime(saturdayNoon, DateTime.saturday, 13, 0), tz.TZDateTime.utc(2026, 10, 3, 13));
    expect(nextWeekdayTime(saturdayNoon, DateTime.saturday, 12, 0), tz.TZDateTime.utc(2026, 10, 10, 12));
  });

  test('schedules save, toggle, and delete', () async {
    await service.save(deepWork);
    await service.save(deepWork.copyWith(enabled: false));
    final saved = (await service.schedules()).single;
    expect(saved.enabled, false);
    expect(saved.days, {DateTime.monday, DateTime.wednesday});

    await service.delete('d');
    expect(await service.schedules(), isEmpty);
  });

  test('tapping a reminder starts its session, unless one is already running', () async {
    await service.save(deepWork);
    await FocusScheduleService.startFromReminder('d');
    final status = await const FocusModeService().status();
    expect(status.active, true);
    expect(status.strict, true);
    expect(status.endsAt!.difference(status.startedAt!).inMinutes, 60);

    await const FocusModeService().stop();
    await const FocusModeService().start();
    await FocusScheduleService.startFromReminder('d');
    expect((await const FocusModeService().status()).endsAt, isNull); // the running session was left alone
  });
}
