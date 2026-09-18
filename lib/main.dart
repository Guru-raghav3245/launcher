import 'package:flutter/material.dart';

import 'onboarding/onboarding_flow.dart';
import 'services/onboarding_service.dart';
import 'shell/launcher_shell.dart';
import 'state/app_settings.dart';
import 'state/app_settings_scope.dart';

void main() {
  runApp(const YinYangLauncherApp());
}

class YinYangLauncherApp extends StatefulWidget {
  const YinYangLauncherApp({super.key});

  @override
  State<YinYangLauncherApp> createState() => _YinYangLauncherAppState();
}

class _YinYangLauncherAppState extends State<YinYangLauncherApp> {
  final _settings = AppSettings();
  late final Future<void> _settingsReady = _settings.load();

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: _settings,
      child: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) {
          return MaterialApp(
            title: 'Yin Yang Launcher',
            debugShowCheckedModeBanner: false,
            themeMode: _settings.isDark ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.black)),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.black,
                brightness: Brightness.dark,
              ),
            ),
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
