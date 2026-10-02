import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launcher/services/focus_mode_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  test('essential apps stay launchable during a session; others are blocked', () async {
    await service.setEssential('com.clock', true);
    await service.start();
    expect(await service.isBlocked('com.clock'), false);
    expect(await service.isBlocked('com.camera'), true);

    await service.setEssential('com.clock', false);
    expect(await service.isBlocked('com.clock'), true);
  });

  test('essentials persist and start empty', () async {
    expect(await service.essentials(), isEmpty);
    await service.setEssential('com.clock', true);
    await service.setEssential('com.phone', true);
    expect(await service.essentials(), {'com.clock', 'com.phone'});
  });

  test('essentials are seeded once with the default dialer and SMS apps', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('yinyang.launcher/role'),
      (call) async => call.method == 'defaultCommsPackages' ? ['com.dialer', 'com.sms'] : null,
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('yinyang.launcher/role'),
        null,
      ),
    );

    expect(await service.essentials(), {'com.dialer', 'com.sms'});

    // Removing a default sticks: the list isn't re-seeded.
    await service.setEssential('com.sms', false);
    await service.setEssential('com.dialer', false);
    expect(await service.essentials(), isEmpty);
  });

  test('a session records when it started, and stop clears it', () async {
    final before = DateTime.now();
    await service.start(duration: const Duration(minutes: 30));
    final status = await service.status();
    expect(status.startedAt!.isBefore(before.subtract(const Duration(seconds: 1))), false);
    expect(status.endsAt!.difference(status.startedAt!).inMinutes, 30);

    await service.stop();
    await service.start();
    expect((await service.status()).startedAt, isNotNull);
  });
}
