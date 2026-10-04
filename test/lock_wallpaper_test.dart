import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launcher/models/wallpaper.dart';
import 'package:launcher/services/lock_wallpaper_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the lock wallpaper is painted like Home: edge colour at the corners, band through the middle', () async {
    final ocean = gradients.first;
    final png = await LockWallpaperService.render(ocean, const ui.Size(72, 164));
    final image = (await (await ui.instantiateImageCodec(png)).getNextFrame()).image;
    expect((image.width, image.height), (72, 164));
    final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    Color at(int x, int y) {
      final i = (y * image.width + x) * 4;
      return Color.fromARGB(255, rgba.getUint8(i), rgba.getUint8(i + 1), rgba.getUint8(i + 2));
    }

    int distance(Color a, Color b) =>
        ((a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs()) * 255 ~/ 1;
    expect(distance(at(0, 0), ocean.edge), lessThan(12));
    expect(distance(at(71, 163), ocean.edge), lessThan(12));
    expect(distance(at(36, 90), ocean.band!), lessThan(24));
  });

  test('sync sets the lock wallpaper once, skips repeats, and clears it when turned off', () async {
    SharedPreferences.setMockInitialValues({});
    final calls = <MethodCall>[];
    const channel = MethodChannel('student.launcher/app');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    // Nothing was ever set: turning it off has nothing to clear.
    await LockWallpaperService.sync(null);
    expect(calls, isEmpty);

    await LockWallpaperService.sync(gradients.first);
    expect(calls.single.method, 'setLockWallpaper');
    final png = (calls.single.arguments as Map)['png'] as Uint8List;
    expect(png.sublist(1, 4), 'PNG'.codeUnits);

    await LockWallpaperService.sync(gradients.first);
    expect(calls, hasLength(1));

    await LockWallpaperService.sync(classicDark.first);
    expect(calls.map((c) => c.method), ['setLockWallpaper', 'setLockWallpaper']);

    await LockWallpaperService.sync(null);
    expect(calls.last.method, 'clearLockWallpaper');
    await LockWallpaperService.sync(null);
    expect(calls, hasLength(3));
  });
}
