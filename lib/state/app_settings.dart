import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/home_layout_mode.dart';

/// Preset wallpaper swatches offered during onboarding and (Phase 5)
/// Settings. Flat pastel colors, close to the app's default look.
const wallpaperPresets = <Color>[
  Color(0xFFF3F1F6),
  Color(0xFFDCDEE3),
  Color(0xFFAEB8CB),
  Color(0xFFC9BFE3),
  Color(0xFFE7E2D8),
];

/// Shared, persisted app settings — theme, home layout mode, and
/// wallpaper. Written by the onboarding pickers now and by Settings
/// (Phase 5) later; read anywhere via [AppSettingsScope.of].
class AppSettings extends ChangeNotifier {
  static const _isDarkKey = 'settings_is_dark';
  static const _layoutModeKey = 'settings_layout_mode';
  static const _wallpaperIndexKey = 'settings_wallpaper_index';

  bool _isDark = false;
  bool get isDark => _isDark;

  HomeLayoutMode _layoutMode = HomeLayoutMode.classic;
  HomeLayoutMode get layoutMode => _layoutMode;

  int _wallpaperIndex = 0;
  int get wallpaperIndex => _wallpaperIndex;
  Color get wallpaperColor => wallpaperPresets[_wallpaperIndex];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_isDarkKey) ?? false;
    _layoutMode = HomeLayoutMode.values.byName(
      prefs.getString(_layoutModeKey) ?? HomeLayoutMode.classic.name,
    );
    _wallpaperIndex = (prefs.getInt(_wallpaperIndexKey) ?? 0).clamp(
      0,
      wallpaperPresets.length - 1,
    );
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isDarkKey, value);
  }

  Future<void> setLayoutMode(HomeLayoutMode value) async {
    if (_layoutMode == value) return;
    _layoutMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_layoutModeKey, value.name);
  }

  Future<void> setWallpaperIndex(int value) async {
    if (_wallpaperIndex == value) return;
    _wallpaperIndex = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_wallpaperIndexKey, value);
  }
}
