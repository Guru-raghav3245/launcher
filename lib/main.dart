import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'onboarding/onboarding_flow.dart';
import 'services/focus_schedule_service.dart';
import 'services/lock_wallpaper_service.dart';
import 'services/onboarding_service.dart';
import 'shell/launcher_shell.dart';
import 'state/app_settings.dart';
import 'state/app_settings_scope.dart';
import 'state/launcher_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The bundled fonts' licences, for the system licence page.
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in [('DM Sans', 'dmsans'), ('Noto Serif', 'notoserif'), ('Open Sans', 'opensans')]) {
      yield LicenseEntryWithLineBreaks([family], await rootBundle.loadString('assets/fonts/OFL-$file.txt'));
    }
  });
  // Not awaited: reminders shouldn't hold up the first frame.
  FocusScheduleService.init();
  runApp(const StudentLauncherApp());
}

class StudentLauncherApp extends StatefulWidget {
  const StudentLauncherApp({super.key});

  @override
  State<StudentLauncherApp> createState() => _StudentLauncherAppState();
}

class _StudentLauncherAppState extends State<StudentLauncherApp> {
  final _settings = AppSettings();
  late final Future<void> _settingsReady = _settings.load();

  // Whether lock wallpaper sync was on at the last settings change, so
  // turning it off still runs once (to clear it).
  var _lockSync = false;

  @override
  void initState() {
    super.initState();
    _settingsReady.then((_) {
      _settings.addListener(_onSettingsChanged);
      _onSettingsChanged();
    });
  }

  /// The lock wallpaper follows the wallpaper Home shows, which changes with
  /// a pick, a theme flip (each theme has its own), or the switch itself.
  void _onSettingsChanged() {
    if (!_settings.lockWallpaperSync && !_lockSync) return;
    _lockSync = _settings.lockWallpaperSync;
    LockWallpaperService.schedule(_settings);
  }

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: _settings,
      child: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) {
          return MaterialApp(
            title: 'Student Launcher',
            debugShowCheckedModeBanner: false,
            themeMode: _settings.isDark ? ThemeMode.dark : ThemeMode.light,
            theme: launcherTheme(Brightness.light, fontFamily: _settings.font.family),
            darkTheme: launcherTheme(Brightness.dark, fontFamily: _settings.font.family),
            // A chosen 12/24-hour format overrides the phone's for every
            // time shown (TimeOfDay.format and Home's clock read this), and
            // the text size scales on top of the phone's font size.
            builder: (context, child) {
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  alwaysUse24HourFormat: switch (_settings.timeFormat) {
                    TimeFormat.system => media.alwaysUse24HourFormat,
                    TimeFormat.h12 => false,
                    TimeFormat.h24 => true,
                  },
                  textScaler: _settings.textSize == TextSize.normal
                      ? media.textScaler
                      : TextScaler.linear(media.textScaler.scale(1) * _settings.textSize.factor),
                ),
                child: child!,
              );
            },
            home: FutureBuilder<void>(
              future: _settingsReady,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox.shrink();
                }
                return const _RootScreen();
              },
            ),
          );
        },
      ),
    );
  }
}

/// Decides between the first-run onboarding flow and the real launcher
/// shell based on the persisted onboarding-complete flag.
class _RootScreen extends StatefulWidget {
  const _RootScreen();

  @override
  State<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<_RootScreen> {
  final _service = const OnboardingService();
  late final Future<bool> _onboardingComplete = _service.isComplete();
  bool? _showLauncher;

  @override
  Widget build(BuildContext context) {
    if (_showLauncher == true) return const LauncherShell();

    return FutureBuilder<bool>(
      future: _onboardingComplete,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        if (snapshot.data!) return const LauncherShell();
        return OnboardingFlow(onFinished: () => setState(() => _showLauncher = true));
      },
    );
  }
}
