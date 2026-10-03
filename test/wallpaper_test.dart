import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/painting.dart';
import 'package:launcher/models/wallpaper.dart';
import 'package:launcher/state/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ids are unique and the gradients are twelve deep and four pale', () {
    final all = [...classicLight, ...classicDark, ...gradients];
    expect(all.map((w) => w.id).toSet(), hasLength(all.length));
    expect(gradients.where((w) => w.isDark), hasLength(12));
    expect(gradients.where((w) => !w.isDark), hasLength(4));
    expect(classicLight.every((w) => !w.isDark), true);
    expect(classicDark.every((w) => w.isDark), true);
  });

  test('a wallpaper index saved before per-theme wallpapers carries over', () async {
    SharedPreferences.setMockInitialValues({'settings_wallpaper_index': 2});
    final settings = AppSettings();
    await settings.load();
    expect(settings.lightWallpaper.id, 'light-2');
    expect(settings.darkWallpaper.id, 'dark-0'); // black, as dark mode was before
  });

  test('a fresh install starts on plain white and black, like the original', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.load();
    expect(settings.lightWallpaper.edge, const Color(0xFFFFFFFF));
    expect(settings.darkWallpaper.edge, const Color(0xFF000000));
  });

  test('each theme keeps its own wallpaper', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.load();
    await settings.setWallpaper(gradients.first, forDark: false);
    await settings.setWallpaper(classicDark[2], forDark: true);
    expect(settings.wallpaper, gradients.first); // light theme by default
    await settings.setTheme(ThemeChoice.dark);
    expect(settings.wallpaper, classicDark[2]);
  });
}
