import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launcher/services/dock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = DockService();
  const role = MethodChannel('yinyang.launcher/role');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      role,
      (call) async => ['com.dialer', 'com.sms', 'com.browser', null],
    );
  });

  test('first read seeds the default apps with their glyphs, once', () async {
    final slots = await service.slots();
    expect(slots.map((s) => s.packageName), ['com.dialer', 'com.sms', 'com.browser', null]);
    expect(slots.map((s) => s.glyph), [DockGlyph.phone, DockGlyph.messages, DockGlyph.browser, null]);

    // Stored now: a different default later doesn't re-seed.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      role,
      (call) async => ['com.other', null, null, null],
    );
    expect((await service.slots()).first.packageName, 'com.dialer');
  });

  test('changing a slot drops its glyph and notifies', () async {
    var notified = 0;
    void listener() => notified++;
    DockService.changes.addListener(listener);
    addTearDown(() => DockService.changes.removeListener(listener));

    await service.setSlot(0, 'com.camera');
    final first = (await service.slots()).first;
    expect(first.packageName, 'com.camera');
    expect(first.glyph, isNull);
    expect(notified, 1);
  });
}
