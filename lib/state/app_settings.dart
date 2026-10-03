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

/// What swiping down on Home does (Phase 8 task 7).
enum SwipeDownAction { spotlight, notifications, none }

/// What double-tapping Home does. The lock methods match the original:
/// accessibility (recommended, keeps fingerprint unlock) or device admin.
enum DoubleTapAction { none, lockAccessibility, lockDeviceAdmin }

/// The theme the user picked; [auto] follows the phone's dark mode.
enum ThemeChoice { light, dark, auto }

/// Shared, persisted app settings — theme, home layout mode, wallpaper,
/// and the drawer options. Written by the onboarding pickers now and by Settings
/// (Phase 5) later; read anywhere via [AppSettingsScope.of].
class AppSettings extends ChangeNotifier with WidgetsBindingObserver {
  static const _themeKey = 'settings_theme';

  /// The *effective* darkness, kept in step for native code that draws in
  /// the launcher's colours (Mindful Timer's "Time's up" overlay).
  static const _isDarkKey = 'settings_is_dark';
  static const _layoutModeKey = 'settings_layout_mode';
  static const _wallpaperIndexKey = 'settings_wallpaper_index';

  ThemeChoice _theme = ThemeChoice.light;
  ThemeChoice get theme => _theme;

  /// What every screen reads: the chosen theme, or the phone's for Auto.
  bool get isDark =>
      _theme == ThemeChoice.dark ||
      (_theme == ThemeChoice.auto &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

  HomeLayoutMode _layoutMode = HomeLayoutMode.classic;
  HomeLayoutMode get layoutMode => _layoutMode;

  int _wallpaperIndex = 0;
  int get wallpaperIndex => _wallpaperIndex;
  Color get wallpaperColor => wallpaperPresets[_wallpaperIndex];

  static const _swipeDownKey = 'settings_swipe_down';
  static const _doubleTapKey = 'settings_double_tap';

  SwipeDownAction _swipeDown = SwipeDownAction.spotlight;
  SwipeDownAction get swipeDown => _swipeDown;

  DoubleTapAction _doubleTap = DoubleTapAction.none;
  DoubleTapAction get doubleTap => _doubleTap;

  final Set<DrawerOption> _drawerOptions = {};
  bool drawerOption(DrawerOption option) => _drawerOptions.contains(option);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _drawerOptions
      ..clear()
      ..addAll(DrawerOption.values.where((o) => prefs.getBool('settings_drawer_${o.name}') ?? false));
    _swipeDown = SwipeDownAction.values.byName(prefs.getString(_swipeDownKey) ?? SwipeDownAction.spotlight.name);
    _doubleTap = DoubleTapAction.values.byName(prefs.getString(_doubleTapKey) ?? DoubleTapAction.none.name);
    // Before Auto existed only the dark flag was stored.
    _theme = ThemeChoice.values.byName(
      prefs.getString(_themeKey) ?? ((prefs.getBool(_isDarkKey) ?? false) ? 'dark' : 'light'),
    );
    WidgetsBinding.instance
      ..removeObserver(this)
      ..addObserver(this);
    _layoutMode = HomeLayoutMode.values.byName(
      prefs.getString(_layoutModeKey) ?? HomeLayoutMode.classic.name,
    );
    _wallpaperIndex = (prefs.getInt(_wallpaperIndexKey) ?? 0).clamp(
      0,
      wallpaperPresets.length - 1,
    );
    notifyListeners();
  }

  /// Light or Dark (the onboarding toggles); Settings offers Auto too.
  Future<void> setDark(bool value) => setTheme(value ? ThemeChoice.dark : ThemeChoice.light);

  Future<void> setTheme(ThemeChoice value) async {
    if (_theme == value) return;
    _theme = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, value.name);
    await _syncDarkFlag();
  }

  // Auto follows the phone as it switches between light and dark.
  @override
  void didChangePlatformBrightness() {
    if (_theme != ThemeChoice.auto) return;
    notifyListeners();
    _syncDarkFlag();
  }

  Future<void> _syncDarkFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isDarkKey, isDark);
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

  Future<void> setSwipeDown(SwipeDownAction value) async {
    if (_swipeDown == value) return;
    _swipeDown = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_swipeDownKey, value.name);
  }

  Future<void> setDoubleTap(DoubleTapAction value) async {
    if (_doubleTap == value) return;
    _doubleTap = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_doubleTapKey, value.name);
  }
}
