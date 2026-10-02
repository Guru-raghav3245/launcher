import 'package:flutter_test/flutter_test.dart';
import 'package:launcher/services/mindful_pause_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const service = MindfulPauseService();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('no apps are paused by default, and the pause lasts 10 seconds', () async {
    expect(await service.pausedApps(), isEmpty);
    expect(await service.isPaused('com.chrome'), false);
    expect(await service.seconds(), 10);
  });

  test('pausing and unpausing an app persists', () async {
    await service.setPaused('com.chrome', true);
    await service.setPaused('com.youtube', true);
    expect(await service.isPaused('com.chrome'), true);
    expect(await service.pausedApps(), {'com.chrome', 'com.youtube'});

    await service.setPaused('com.chrome', false);
    expect(await service.isPaused('com.chrome'), false);
  });

  test('duration is clamped to 10-60 seconds', () async {
    await service.setSeconds(30);
    expect(await service.seconds(), 30);
    await service.setSeconds(5);
    expect(await service.seconds(), 10);
    await service.setSeconds(90);
    expect(await service.seconds(), 60);
  });
}
