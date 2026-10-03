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

/// App Drawer / Spotlight behaviour switches (Phase 8 task 5), all off by
/// default.
enum DrawerOption {
  /// Focus the drawer's search (keyboard up) whenever the drawer opens.
  keyboardOnOpen,

  /// When typing leaves exactly one result, open it (drawer and Spotlight).
  autoOpenSingleResult,

  /// A Recent section at the top of the drawer, from usage stats.
  recentAppsOnTop,

  /// Leave apps unused for 30 days out of the drawer list (search finds them).
  hideUnusedApps,
}

/// Shared, persisted app settings — theme, home layout mode, wallpaper,
/// and the drawer options. Written by the onboarding pickers now and by Settings
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

  final Set<DrawerOption> _drawerOptions = {};
  bool drawerOption(DrawerOption option) => _drawerOptions.contains(option);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _drawerOptions
      ..clear()
      ..addAll(DrawerOption.values.where((o) => prefs.getBool('settings_drawer_${o.name}') ?? false));
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

  Future<void> setDrawerOption(DrawerOption option, bool on) async {
    if (drawerOption(option) == on) return;
    on ? _drawerOptions.add(option) : _drawerOptions.remove(option);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_drawer_${option.name}', on);
  }
}
