import 'package:flutter_test/flutter_test.dart';
import 'package:launcher/services/focus_mode_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const service = FocusModeService();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('inactive by default, and blocks nothing', () async {
    final status = await service.status();
    expect(status.active, false);
    expect(await service.isBlocked('any.package'), false);
  });

  test('start with no duration is active indefinitely and blocks launches', () async {
    await service.start();
    final status = await service.status();
    expect(status.active, true);
    expect(status.endsAt, null);
    expect(await service.isBlocked('any.package'), true);
  });

  test('stop clears an active session', () async {
    await service.start();
    await service.stop();
    expect((await service.status()).active, false);
  });

  test('a timed session auto-expires once past its end time', () async {
    await service.start(duration: const Duration(milliseconds: -1));
    final status = await service.status();
    expect(status.active, false);
  });

  test('a timed session in the future stays active with remaining time', () async {
    await service.start(duration: const Duration(minutes: 10));
    final status = await service.status();
    expect(status.active, true);
    expect(status.remaining!.inMinutes, 9); // just under 10, clock ticked a bit
  });
}
