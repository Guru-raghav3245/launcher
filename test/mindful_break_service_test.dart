import 'package:flutter_test/flutter_test.dart';
import 'package:launcher/services/mindful_break_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const service = MindfulBreakService();
  final noon = DateTime(2026, 10, 3, 12);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('a break lasts the chosen days, then the app is back', () async {
    expect(await service.breaks(now: noon), isEmpty);
    await service.start('com.chrome', 3, now: noon);
    expect(await service.endsAt('com.chrome', now: noon), DateTime(2026, 10, 6, 12));
    expect(await service.endsAt('com.chrome', now: DateTime(2026, 10, 6, 11)), isNotNull);
    expect(await service.endsAt('com.chrome', now: DateTime(2026, 10, 6, 12)), isNull);
  });

  test('ending a break early brings the app back and notifies listeners', () async {
    var notified = 0;
    void listener() => notified++;
    MindfulBreakService.changes.addListener(listener);
    addTearDown(() => MindfulBreakService.changes.removeListener(listener));

    await service.start('com.chrome', 1);
    await service.start('com.youtube', 7);
    await service.end('com.chrome');
    expect((await service.breaks()).keys, ['com.youtube']);
    expect(notified, 3);
  });
}
