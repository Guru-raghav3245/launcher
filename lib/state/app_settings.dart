import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/home_layout_mode.dart';
import '../models/wallpaper.dart';

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

/// 12- or 24-hour times across the launcher; [system] follows the phone.
enum TimeFormat { system, h12, h24 }

/// The Weather tile's temperature unit (stored data stays in °C).
enum TempUnit { celsius, fahrenheit }

/// The launcher's typeface (Phase 10 task 5). [family] is null for
/// Roboto, Android's own font; the others are bundled (see pubspec.yaml).
enum LauncherFont {
  roboto('Roboto', null),
  dmSans('DM Sans', 'DM Sans'),
  notoSerif('Noto Serif', 'Noto Serif'),
  openSans('Open Sans', 'Open Sans');

  const LauncherFont(this.label, this.family);
  final String label;
  final String? family;
}

/// Text size, on top of the phone's own font scale.
enum TextSize {
  small(0.9),
  normal(1.0),
  large(1.15);

  const TextSize(this.factor);
  final double factor;
}

/// How app icons are coloured everywhere they appear (Phase 10 task 6).
/// [matrix] is a 4x5 colour matrix for `ColorFilter.matrix`, or null to
/// leave icons as they are.
enum IconTint {
  grayscale('Grayscale'),
  muted('Muted'),
  classic('Classic'),
  coolTone('Cool Tone'),
  invert('Invert');

  const IconTint(this.label);
  final String label;

  // Rec. 709 luminance weights.
  static const _r = 0.2126, _g = 0.7152, _b = 0.0722;

  List<double>? get matrix => switch (this) {
    grayscale => const [_r, _g, _b, 0, 0, _r, _g, _b, 0, 0, _r, _g, _b, 0, 0, 0, 0, 0, 1, 0],
    // Halfway between the icon's colours and grey.
    muted => const [
      0.5 + _r / 2, _g / 2, _b / 2, 0, 0, //
      _r / 2, 0.5 + _g / 2, _b / 2, 0, 0, //
      _r / 2, _g / 2, 0.5 + _b / 2, 0, 0, //
      0, 0, 0, 1, 0,
    ],
    classic => null,
    // Grey with a blue cast.
    coolTone => const [
      _r * 0.85, _g * 0.85, _b * 0.85, 0, 0, //
      _r * 0.95, _g * 0.95, _b * 0.95, 0, 0, //
      _r * 1.1, _g * 1.1, _b * 1.1, 0, 12, //
      0, 0, 0, 1, 0,
    ],
    // Grey, light for dark.
    invert => const [-_r, -_g, -_b, 0, 255, -_r, -_g, -_b, 0, 255, -_r, -_g, -_b, 0, 255, 0, 0, 0, 1, 0],
  };
}

/// How Home draws its clock (Phase 10 task 2).
enum ClockStyle { standard, large, compact }

/// Where Home's clock sits.
enum ClockPosition { top, center, bottom }

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
  /// Before per-theme wallpapers: an index into the light Classic flats.
  static const _legacyWallpaperIndexKey = 'settings_wallpaper_index';

  ThemeChoice _theme = ThemeChoice.light;
  ThemeChoice get theme => _theme;

  /// What every screen reads: the chosen theme, or the phone's for Auto.
  bool get isDark =>
      _theme == ThemeChoice.dark ||
      (_theme == ThemeChoice.auto &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

  HomeLayoutMode _layoutMode = HomeLayoutMode.classic;
  HomeLayoutMode get layoutMode => _layoutMode;

  // One wallpaper per theme, like the original's Light / Dark tabs.
  Wallpaper _lightWallpaper = classicLight.first;
  Wallpaper _darkWallpaper = classicDark.first;
  Wallpaper get lightWallpaper => _lightWallpaper;
  Wallpaper get darkWallpaper => _darkWallpaper;

  /// The one Home shows now.
  Wallpaper get wallpaper => isDark ? _darkWallpaper : _lightWallpaper;

  static const _swipeDownKey = 'settings_swipe_down';
  static const _doubleTapKey = 'settings_double_tap';

  SwipeDownAction _swipeDown = SwipeDownAction.spotlight;
  SwipeDownAction get swipeDown => _swipeDown;

  DoubleTapAction _doubleTap = DoubleTapAction.none;
  DoubleTapAction get doubleTap => _doubleTap;

  ClockStyle _clockStyle = ClockStyle.standard;
  ClockStyle get clockStyle => _clockStyle;

  ClockPosition? _clockPosition;

  /// Null until the user picks one: each layout then keeps its own default
  /// (Classic at the top, Minimal centred). See [clockPositionFor].
  ClockPosition? get clockPosition => _clockPosition;

  ClockPosition clockPositionFor(HomeLayoutMode layout) =>
      _clockPosition ?? (layout == HomeLayoutMode.classic ? ClockPosition.top : ClockPosition.center);

  bool _showSearchBar = true;

  /// Classic layout's Spotlight search pill.
  bool get showSearchBar => _showSearchBar;

  IconTint _iconTint = IconTint.grayscale;
  IconTint get iconTint => _iconTint;

  LauncherFont _font = LauncherFont.roboto;
  LauncherFont get font => _font;

  TextSize _textSize = TextSize.normal;
  TextSize get textSize => _textSize;

  TimeFormat _timeFormat = TimeFormat.system;
  TimeFormat get timeFormat => _timeFormat;

  TempUnit _tempUnit = TempUnit.celsius;
  TempUnit get tempUnit => _tempUnit;

  /// [celsius] as a rounded temperature in the chosen unit, e.g. "73°".
  String formatTemp(double celsius) =>
      '${(_tempUnit == TempUnit.fahrenheit ? celsius * 9 / 5 + 32 : celsius).round()}°';

  bool _showStatusBar = true;
  bool get showStatusBar => _showStatusBar;

  final Set<DrawerOption> _drawerOptions = {};
  bool drawerOption(DrawerOption option) => _drawerOptions.contains(option);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _drawerOptions
      ..clear()
      ..addAll(DrawerOption.values.where((o) => prefs.getBool('settings_drawer_${o.name}') ?? false));
    _clockStyle = ClockStyle.values.byName(prefs.getString('settings_clock_style') ?? ClockStyle.standard.name);
    final position = prefs.getString('settings_clock_position');
    _clockPosition = position == null ? null : ClockPosition.values.byName(position);
    _iconTint = IconTint.values.byName(prefs.getString('settings_icon_tint') ?? IconTint.grayscale.name);
    _font = LauncherFont.values.byName(prefs.getString('settings_font') ?? LauncherFont.roboto.name);
    _textSize = TextSize.values.byName(prefs.getString('settings_text_size') ?? TextSize.normal.name);
    _timeFormat = TimeFormat.values.byName(prefs.getString('settings_time_format') ?? TimeFormat.system.name);
    _tempUnit = TempUnit.values.byName(prefs.getString('settings_temp_unit') ?? TempUnit.celsius.name);
    _showSearchBar = prefs.getBool('settings_show_search_bar') ?? true;
    _showStatusBar = prefs.getBool('settings_show_status_bar') ?? true;
    if (!_showStatusBar) _applyStatusBar(); // shown is the window's default
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
    final legacy = (prefs.getInt(_legacyWallpaperIndexKey) ?? 0).clamp(0, classicLight.length - 1);
    _lightWallpaper = wallpaperById(prefs.getString('settings_wallpaper_light') ?? '') ?? classicLight[legacy];
    _darkWallpaper = wallpaperById(prefs.getString('settings_wallpaper_dark') ?? '') ?? classicDark.first;
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

  /// Sets the wallpaper for the light or dark theme ([forDark]).
  Future<void> setWallpaper(Wallpaper value, {required bool forDark}) => forDark
      ? _save(_darkWallpaper != value, () => _darkWallpaper = value, (p) => p.setString('settings_wallpaper_dark', value.id))
      : _save(_lightWallpaper != value, () => _lightWallpaper = value, (p) => p.setString('settings_wallpaper_light', value.id));

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

  Future<void> setClockStyle(ClockStyle value) =>
      _save(_clockStyle != value, () => _clockStyle = value, (p) => p.setString('settings_clock_style', value.name));

  Future<void> setClockPosition(ClockPosition value) => _save(
    _clockPosition != value,
    () => _clockPosition = value,
    (p) => p.setString('settings_clock_position', value.name),
  );

  Future<void> setIconTint(IconTint value) =>
      _save(_iconTint != value, () => _iconTint = value, (p) => p.setString('settings_icon_tint', value.name));

  Future<void> setFont(LauncherFont value) =>
      _save(_font != value, () => _font = value, (p) => p.setString('settings_font', value.name));

  Future<void> setTextSize(TextSize value) =>
      _save(_textSize != value, () => _textSize = value, (p) => p.setString('settings_text_size', value.name));

  Future<void> setTimeFormat(TimeFormat value) =>
      _save(_timeFormat != value, () => _timeFormat = value, (p) => p.setString('settings_time_format', value.name));

  Future<void> setTempUnit(TempUnit value) =>
      _save(_tempUnit != value, () => _tempUnit = value, (p) => p.setString('settings_temp_unit', value.name));

  Future<void> setShowSearchBar(bool value) =>
      _save(_showSearchBar != value, () => _showSearchBar = value, (p) => p.setBool('settings_show_search_bar', value));

  Future<void> setShowStatusBar(bool value) async {
    await _save(
      _showStatusBar != value,
      () => _showStatusBar = value,
      (p) => p.setBool('settings_show_status_bar', value),
    );
    _applyStatusBar();
  }

  /// Hiding the status bar keeps the navigation bar, and only affects the
  /// launcher's own window (see MainActivity.setStatusBarVisible).
  Future<void> _applyStatusBar() async {
    try {
      await const MethodChannel('yinyang.launcher/app').invokeMethod('setStatusBarVisible', {'visible': _showStatusBar});
    } on MissingPluginException {
      // Tests and non-Android hosts.
    }
  }

  Future<void> _save(bool changed, void Function() apply, Future<bool> Function(SharedPreferences) write) async {
    if (!changed) return;
    apply();
    notifyListeners();
    await write(await SharedPreferences.getInstance());
  }
}
