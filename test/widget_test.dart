import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:launcher/main.dart';
import 'package:launcher/models/home_layout_mode.dart';
import 'package:launcher/state/app_settings.dart';
import 'package:launcher/models/tile_kind.dart';
import 'package:launcher/mind_space/tool_pages.dart';
import 'package:launcher/onboarding/onboarding_flow.dart';
import 'package:launcher/onboarding/steps/welcome_step.dart';
import 'package:launcher/panels/app_drawer_panel.dart';
import 'package:launcher/panels/home_panel.dart';
import 'package:launcher/panels/my_space_panel.dart';
import 'package:launcher/panels/spotlight_search_panel.dart';
import 'package:launcher/panels/mind_space_panel.dart';
import 'package:launcher/services/app_customizations_service.dart';
import 'package:launcher/services/dock_service.dart';
import 'package:launcher/services/focus_mode_service.dart';
import 'package:launcher/services/my_space_service.dart';
import 'package:launcher/settings/settings_screen.dart';

void main() {
  testWidgets('shows onboarding on first run', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingFlow), findsOneWidget);
    expect(find.byType(WelcomeStep), findsOneWidget);
    expect(find.byType(HomePanel), findsNothing);
  });

  testWidgets('launches on the Home panel once onboarding is complete', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();

    expect(find.byType(HomePanel), findsOneWidget);
    expect(find.byType(MySpacePanel), findsNothing);
    expect(find.byType(MindSpacePanel), findsNothing);
  });

  testWidgets('swiping right reveals My Space', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();

    await tester.fling(find.byType(HomePanel), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.byType(MySpacePanel), findsOneWidget);
  });

  testWidgets('long-pressing Home opens Settings', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(HomePanel));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Launcher Settings'), findsOneWidget);
  });

  testWidgets('Settings search filters entries by title', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(HomePanel));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'launch');
    await tester.pump();
    expect(find.text('Launcher Settings'), findsOneWidget);
    expect(find.text('Appearance'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('Launcher Settings'), findsNothing);
    expect(find.textContaining('No settings match'), findsOneWidget);
  });

  testWidgets('Appearance toggle switches the app theme', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(HomePanel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('Auto theme follows the phone as it changes', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true, 'settings_theme': 'auto'});
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    ThemeMode mode() => tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;
    expect(mode(), ThemeMode.light);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(mode(), ThemeMode.dark);
    expect((await SharedPreferences.getInstance()).getBool('settings_is_dark'), true); // for the native overlay
  });

  testWidgets('a dark flag saved before Auto existed loads as Dark', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true, 'settings_is_dark': true});
    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.dark);
  });

  testWidgets('Toggles cycle the theme and switch Focus Mode', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(HomePanel));
    await tester.pumpAndSettle();

    expect(find.text('Theme · Light'), findsOneWidget);
    await tester.tap(find.text('Theme · Light'));
    await tester.pumpAndSettle();
    expect(find.text('Theme · Dark'), findsOneWidget);
    await tester.tap(find.text('Theme · Dark'));
    await tester.pumpAndSettle();
    expect(find.text('Follows your phone'), findsOneWidget);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Focus Mode'));
    await tester.pumpAndSettle();
    expect((await const FocusModeService().status()).active, true);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Focus Mode'));
    await tester.pumpAndSettle();
    expect((await const FocusModeService().status()).active, false);
  });

  testWidgets('Home honours the clock style, position, search bar, and status bar settings', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'settings_clock_style': 'large',
      'settings_clock_position': 'bottom',
      'settings_show_search_bar': false,
      'settings_show_status_bar': false,
    });
    final appCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('yinyang.launcher/app'), (
      call,
    ) async {
      appCalls.add(call);
      return null;
    });

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();

    // Large: hours and minutes as separate lines.
    final now = DateTime.now();
    expect(find.text(now.hour.toString().padLeft(2, '0')), findsOneWidget);
    // Bottom: the clock sits below the middle of Home.
    final clockY = tester.getCenter(find.text(now.minute.toString().padLeft(2, '0'))).dy;
    expect(clockY, greaterThan(tester.getSize(find.byType(HomePanel)).height / 2));
    expect(find.text('Spotlight search'), findsNothing);
    expect(appCalls.where((c) => c.method == 'setStatusBarVisible').last.arguments, {'visible': false});
  });

  testWidgets('without a chosen position, each layout keeps its own clock placement', (WidgetTester tester) async {
    final settings = AppSettings();
    expect(settings.clockPositionFor(HomeLayoutMode.classic), ClockPosition.top);
    expect(settings.clockPositionFor(HomeLayoutMode.minimal), ClockPosition.center);
    SharedPreferences.setMockInitialValues({});
    await settings.setClockPosition(ClockPosition.bottom);
    expect(settings.clockPositionFor(HomeLayoutMode.minimal), ClockPosition.bottom);
  });

  testWidgets('a deep gradient gives Home white text, even in the light theme', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true, 'settings_wallpaper_light': 'gradient-ocean'});

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    expect(tester.widget<Text>(find.text(time)).style!.color, Colors.white);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.light);
  });

  testWidgets('Launcher Settings switches layout and re-runs onboarding', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(HomePanel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Launcher Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Spotlight search'), findsOneWidget); // Classic layout
    await tester.tap(find.text('Minimal'));
    await tester.pumpAndSettle();
    expect(find.text('Spotlight search'), findsNothing);

    await tester.ensureVisible(find.text('Re-run onboarding')); // below the wallpaper gallery
    await tester.pumpAndSettle();
    await tester.tap(find.text('Re-run onboarding'));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeStep), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
  });

  testWidgets('System Settings shows permission and launcher status', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    final messenger = tester.binding.defaultBinaryMessenger;
    final opened = <String>[];
    messenger.setMockMethodCallHandler(const MethodChannel('yinyang.launcher/role'), (call) async {
      opened.add(call.method);
      return call.method == 'isDefaultLauncher' ? true : null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('yinyang.launcher/usage'),
      (call) async => call.method == 'hasAccess' ? false : null,
    );
    // LocationPermission.whileInUse.index
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (call) async => call.method == 'checkPermission' ? 2 : null,
    );

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(HomePanel));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('System Settings')); // below the Toggles group
    await tester.pumpAndSettle();
    await tester.tap(find.text('System Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Yin Yang Launcher'), findsOneWidget);
    expect(find.text('Not allowed · Mind Space needs this'), findsOneWidget);
    expect(find.text('Allowed · used by the Weather tile'), findsOneWidget);

    await tester.tap(find.text('Default launcher'));
    await tester.pump();
    expect(opened, contains('openHomeSettings'));
  });

  testWidgets('Settings Pause starts Focus Mode and Stop ends it', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(HomePanel));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'pau');
    await tester.pump();
    expect(find.text('Appearance'), findsNothing);
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();

    expect(find.text('Focus Mode is on'), findsOneWidget);
    expect((await const FocusModeService().status()).active, isTrue);

    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect((await const FocusModeService().status()).active, isFalse);
  });

  testWidgets('tapping the Home clock opens the clock app', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('yinyang.launcher/app'), (
      call,
    ) async {
      calls.add(call.method);
      return true;
    });

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(RegExp(r'^\d\d:\d\d$')));
    await tester.pump();
    expect(calls, ['openClock']);
  });

  testWidgets('swipe down can open the notification tray instead of Spotlight', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true, 'settings_swipe_down': 'notifications'});
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('installed_apps'),
      (call) async => <Object>[],
    );
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('yinyang.launcher/gestures'), (
      call,
    ) async {
      calls.add(call.method);
      return true;
    });

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    expect(find.byType(SpotlightSearchPanel), findsNothing);
    await tester.fling(find.byType(HomePanel), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(calls, ['expandNotifications']);
    expect(find.byType(HomePanel), findsOneWidget); // still on Home

    // Swipe up still reaches the App Drawer.
    await tester.fling(find.byType(HomePanel), const Offset(0, -400), 1000);
    await tester.pumpAndSettle();
    expect(find.byType(AppDrawerPanel), findsOneWidget);
  });

  testWidgets('double tap locks, or explains and opens Accessibility settings first', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true, 'settings_double_tap': 'lockAccessibility'});
    final calls = <String>[];
    var ready = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('yinyang.launcher/gestures'), (
      call,
    ) async {
      calls.add(call.method);
      return switch (call.method) {
        'accessibilityLockReady' || 'lockWithAccessibility' => ready,
        _ => null,
      };
    });

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    Future<void> doubleTap() async {
      await tester.tap(find.byType(HomePanel));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(HomePanel));
      await tester.pumpAndSettle();
    }

    // Not switched on yet: the explainer, then Android's settings.
    await doubleTap();
    expect(find.text('Accessibility service'), findsOneWidget);
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(calls.last, 'openAccessibilitySettings');

    // Switched on: it just locks.
    ready = true;
    calls.clear();
    await doubleTap();
    expect(calls, ['lockWithAccessibility']);
  });

  testWidgets('Restart Launcher calls the native restart', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('yinyang.launcher/app'),
      (call) async => calls.add(call.method),
    );

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(HomePanel));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'restart');
    await tester.pump();
    await tester.tap(find.text('Restart Launcher'));
    await tester.pump();
    expect(calls, ['restart']);
  });

  testWidgets('Allowed apps picker saves checked apps', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('installed_apps'),
      (call) async => [
        {'name': 'Camera', 'package_name': 'com.camera'},
        {'name': 'Clock', 'package_name': 'com.clock'},
      ],
    );

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(HomePanel));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Allowed apps')); // below the Toggles group
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allowed apps'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clock'));
    await tester.pumpAndSettle();
    expect(await const FocusModeService().essentials(), {'com.clock'});

    await tester.tap(find.text('Clock'));
    await tester.pumpAndSettle();
    expect(await const FocusModeService().essentials(), isEmpty);
  });

  testWidgets('Hidden apps in Settings lists hidden apps, and unticking one unhides it', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'apps_hidden': ['com.camera'],
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('installed_apps'),
      (call) async => [
        {'name': 'Camera', 'package_name': 'com.camera'},
        {'name': 'Clock', 'package_name': 'com.clock'},
      ],
    );

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(HomePanel));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hidden apps')); // below the Toggles group
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hidden apps'));
    await tester.pumpAndSettle();
    final checkbox = find.byType(Checkbox);
    expect(tester.widget<Checkbox>(checkbox.first).value, true); // Camera, ticked at the top

    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    expect((await const AppCustomizationsService().load()).hidden, isEmpty);
  });

  testWidgets('Focus Mode refuses non-essential launches with a message', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'focus_mode_active': true,
      'focus_mode_essentials': ['com.clock'],
    });
    final started = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('installed_apps'), (call) async {
      if (call.method == 'startApp') {
        started.add(call.arguments);
        return true;
      }
      return [
        {'name': 'Camera', 'package_name': 'com.camera'},
        {'name': 'Clock', 'package_name': 'com.clock'},
      ];
    });

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(0, -400), 1000); // swipe up → App Drawer
    await tester.pumpAndSettle();

    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    expect(find.text("Focus Mode is on · Camera isn't an allowed app"), findsOneWidget);
    expect(started, isEmpty);

    await tester.tap(find.text('Clock'));
    await tester.pumpAndSettle();
    expect(started, hasLength(1));
  });

  testWidgets('Mindful Pause delays a paused app, and skipping cancels it', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'mindful_pause_apps': ['com.chrome'],
    });
    final started = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('installed_apps'), (call) async {
      if (call.method == 'startApp') {
        started.add(call.arguments);
        return true;
      }
      return [
        {'name': 'Chrome', 'package_name': 'com.chrome'},
      ];
    });

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(0, -400), 1000); // swipe up → App Drawer
    await tester.pumpAndSettle();

    // Skipping closes the pause without launching.
    await tester.tap(find.text('Chrome'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Mindful Pause'), findsOneWidget);
    await tester.tap(find.text("I'll skip this time"));
    // The exit animation starts on the frame after the tap, so give it two.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Mindful Pause'), findsNothing);
    expect(started, isEmpty);

    // Waiting out the 10-second pause launches the app.
    await tester.tap(find.text('Chrome'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Mindful Pause'), findsNothing);
    expect(started, hasLength(1));
  });

  testWidgets('Mindful Timer asks for a session length, and refuses once the budget is spent', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'mindful_timer_groups':
          '[{"id":"b","name":"Browsing","packages":["com.chrome"],"dailyMinutes":30,"cooldownMinutes":0}]',
    });
    final started = <Object?>[];
    final sessions = <Object?>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('installed_apps'), (call) async {
      if (call.method == 'startApp') {
        started.add(call.arguments);
        return true;
      }
      return [
        {'name': 'Chrome', 'package_name': 'com.chrome'},
      ];
    });
    messenger.setMockMethodCallHandler(const MethodChannel('yinyang.launcher/timer'), (call) async {
      sessions.add(call.arguments);
      return null;
    });
    var usedMinutes = 0;
    messenger.setMockMethodCallHandler(const MethodChannel('yinyang.launcher/usage'), (call) async {
      if (call.method == 'hasAccess') return true;
      return [
        {'packageName': 'com.chrome', 'type': 'foreground', 'timestamp': 0},
        {'packageName': 'com.chrome', 'type': 'background', 'timestamp': usedMinutes * 60000},
      ];
    });

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(0, -400), 1000); // swipe up → App Drawer
    await tester.pumpAndSettle();

    // Close cancels the launch.
    await tester.tap(find.text('Chrome'));
    await tester.pumpAndSettle();
    expect(find.text('Choose session length'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(started, isEmpty);

    // Start Session launches with the default 3 minutes.
    await tester.tap(find.text('Chrome'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Session'));
    await tester.pumpAndSettle();
    expect(started, hasLength(1));
    expect(sessions, [
      {'packageName': 'com.chrome', 'appName': 'Chrome', 'minutes': 3},
    ]);

    // With the 30 minutes used up, it's refused with a message.
    usedMinutes = 30;
    await tester.tap(find.text('Chrome'));
    await tester.pumpAndSettle();
    expect(find.text('Choose session length'), findsNothing);
    expect(find.text("Browsing · today's 30 min are used up"), findsOneWidget);
    expect(started, hasLength(1));
  });

  testWidgets('an app on a Mindful Break is hidden from the drawer and blocked elsewhere', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'mindful_break_apps':
          '{"com.chrome":${DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch}}',
      'my_space_tiles': '[{"id":"1","kind":"appFolder","data":{"packages":["com.chrome"]}}]',
    });
    final started = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('installed_apps'), (call) async {
      if (call.method == 'startApp') {
        started.add(call.arguments);
        return true;
      }
      return [
        {'name': 'Camera', 'package_name': 'com.camera'},
        {'name': 'Chrome', 'package_name': 'com.chrome'},
      ];
    });

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();

    // My Space's App Folder still shows it, but opening it shows the block screen.
    await tester.fling(find.byType(HomePanel), const Offset(400, 0), 1000); // swipe right → My Space
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chrome'));
    await tester.pumpAndSettle();
    expect(find.text('Chrome is on a break'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(started, isEmpty);

    // The App Drawer leaves it out.
    await tester.fling(find.byType(MySpacePanel), const Offset(-400, 0), 1000); // back to Home
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(0, -400), 1000); // swipe up → App Drawer
    await tester.pumpAndSettle();
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Chrome'), findsNothing);
  });

  testWidgets('Mind Space leaves productive apps out, and Reflect shows yesterday', (WidgetTester tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int at(DateTime t) => t.millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'mind_space_productive_apps': ['com.work'],
    });
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('installed_apps'),
      (call) async => [
        {'name': 'Feed', 'package_name': 'com.feed'},
        {'name': 'Work', 'package_name': 'com.work'},
      ],
    );
    messenger.setMockMethodCallHandler(const MethodChannel('yinyang.launcher/usage'), (call) async {
      if (call.method == 'hasAccess') return true;
      final yesterday = today.subtract(const Duration(days: 1));
      return [
        for (final (pkg, start, minutes) in [
          ('com.feed', yesterday.add(const Duration(hours: 9)), 45),
          ('com.feed', today, 5),
          ('com.work', today.add(const Duration(minutes: 10)), 30),
        ]) ...[
          {'packageName': pkg, 'type': 'foreground', 'timestamp': at(start)},
          {'packageName': pkg, 'type': 'background', 'timestamp': at(start.add(Duration(minutes: minutes)))},
        ],
      ].where((e) => (e['timestamp'] as int) >= (call.arguments as Map)['start']).toList();
    });

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(-400, 0), 1000); // swipe left → Mind Space
    await tester.pumpAndSettle();

    // Now: only Feed's 5 minutes count; Work is productive.
    expect(find.text('5m'), findsWidgets);
    expect(find.text('Work'), findsNothing);

    await tester.tap(find.text('Reflect'));
    await tester.pumpAndSettle();
    expect(find.text('Screen time yesterday'), findsOneWidget);
    expect(find.text('45m'), findsOneWidget);
  });

  testWidgets('hidden and renamed apps show up that way in the drawer and Spotlight', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'apps_hidden': ['com.camera'],
      'apps_renames': '{"com.chrome":"Web"}',
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('installed_apps'),
      (call) async => [
        {'name': 'Camera', 'package_name': 'com.camera'},
        {'name': 'Chrome', 'package_name': 'com.chrome'},
        {'name': 'Clock', 'package_name': 'com.clock'},
      ],
    );

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(0, -400), 1000); // swipe up → App Drawer
    await tester.pumpAndSettle();
    expect(find.text('Web'), findsOneWidget);
    expect(find.text('Chrome'), findsNothing);
    expect(find.text('Camera'), findsNothing);
    expect(find.text('Clock'), findsOneWidget);

    await tester.fling(find.text('Clock'), const Offset(0, 400), 1000); // back to Home
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(0, 400), 1000); // swipe down → Spotlight
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'c');
    await tester.pumpAndSettle();
    expect(find.text('Clock'), findsOneWidget);
    expect(find.text('Camera'), findsNothing);
  });

  testWidgets('the drawer long-press menu pins, renames, and hides an app', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('installed_apps'),
      (call) async => [
        {'name': 'Camera', 'package_name': 'com.camera'},
        {'name': 'Chrome', 'package_name': 'com.chrome'},
      ],
    );

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(0, -400), 1000); // swipe up → App Drawer
    await tester.pumpAndSettle();

    // Pin: Chrome also shows under a ★ section at the top.
    await tester.longPress(find.text('Chrome'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin to top'));
    await tester.pumpAndSettle();
    expect(find.text('★'), findsWidgets); // the section header (and its index entry)
    expect(find.text('Chrome'), findsNWidgets(2));

    // Rename.
    await tester.longPress(find.text('Chrome').first);
    await tester.pumpAndSettle();
    expect(find.text('Unpin'), findsOneWidget);
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Web');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Web'), findsNWidgets(2));
    expect(find.text('Chrome'), findsNothing);

    // Hide, then Undo.
    await tester.longPress(find.text('Camera'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide'));
    await tester.pumpAndSettle();
    expect(find.text('Camera'), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Camera'), findsOneWidget);
  });

  testWidgets('the Home dock opens its apps, fills empty slots, and swaps on long-press', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'home_dock':
          '[{"package":"com.phone","glyph":"phone"},{"package":null,"glyph":null},'
          '{"package":null,"glyph":null},{"package":null,"glyph":null}]',
    });
    final started = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('installed_apps'), (call) async {
      if (call.method == 'startApp') {
        started.add(call.arguments);
        return true;
      }
      return [
        {'name': 'Camera', 'package_name': 'com.camera'},
        {'name': 'Phone', 'package_name': 'com.phone'},
      ];
    });

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();

    // The default Phone slot draws its glyph and opens the app.
    await tester.tap(find.byIcon(Icons.call_outlined));
    await tester.pumpAndSettle();
    expect(started, hasLength(1));

    // An empty slot asks for an app.
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    expect(find.text('Dock app'), findsOneWidget);
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add), findsNWidgets(2));

    // Long-pressing swaps it; the Phone glyph gives way to the app's icon.
    await tester.longPress(find.byIcon(Icons.call_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.call_outlined), findsNothing);
    expect((await const DockService().slots()).first.packageName, 'com.camera');
  });

  testWidgets('drawer options: keyboard, recent apps, unused apps hidden, single result opens', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'settings_drawer_keyboardOnOpen': true,
      'settings_drawer_recentAppsOnTop': true,
      'settings_drawer_hideUnusedApps': true,
      'settings_drawer_autoOpenSingleResult': true,
    });
    final started = <Object?>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('installed_apps'), (call) async {
      if (call.method == 'startApp') {
        started.add(call.arguments);
        return true;
      }
      return [
        {'name': 'Camera', 'package_name': 'com.camera'}, // installed long ago, never used
        {'name': 'Chrome', 'package_name': 'com.chrome'},
        {'name': 'Clock', 'package_name': 'com.clock', 'installed_timestamp': DateTime.now().millisecondsSinceEpoch},
      ];
    });
    messenger.setMockMethodCallHandler(const MethodChannel('yinyang.launcher/usage'), (call) async {
      if (call.method == 'hasAccess') return true;
      if (call.method == 'lastUsed') return {'com.chrome': DateTime.now().millisecondsSinceEpoch};
      return <Object>[];
    });

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(0, -400), 1000); // swipe up → App Drawer
    await tester.pumpAndSettle();

    expect(tester.testTextInput.isVisible, true); // keyboard on open
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Chrome'), findsNWidgets(2)); // under Recent and under C
    expect(find.text('Camera'), findsNothing); // unused for 30 days
    expect(find.text('Clock'), findsOneWidget); // new, so kept

    // Search still finds the unused app, and as the only result it opens.
    await tester.enterText(find.byType(TextField).last, 'cam');
    await tester.pumpAndSettle();
    expect(started, hasLength(1));
  });

  testWidgets('Spotlight raises the keyboard and shows recent apps', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('installed_apps'),
      (call) async => [
        {'name': 'Camera', 'package_name': 'com.camera'},
        {'name': 'Chrome', 'package_name': 'com.chrome'},
      ],
    );
    messenger.setMockMethodCallHandler(const MethodChannel('yinyang.launcher/usage'), (call) async {
      if (call.method == 'hasAccess') return true;
      if (call.method == 'lastUsed') return {'com.chrome': DateTime.now().millisecondsSinceEpoch};
      return <Object>[];
    });

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, false);
    await tester.fling(find.byType(HomePanel), const Offset(0, 400), 1000); // swipe down → Spotlight
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, true);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Chrome'), findsOneWidget);
    expect(find.text('Camera'), findsNothing);
  });

  testWidgets('a built-in tile is previewed before it is added', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(400, 0), 1000); // swipe right → My Space
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Your First Tile'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.text('Add tile'), findsOneWidget); // the preview, not the tile yet
    expect(find.textContaining('Pick up the dry cleaning'), findsOneWidget);
    await tester.tap(find.text('Add tile'));
    await tester.pumpAndSettle();

    final tiles = await const MySpaceService().loadTiles();
    expect(tiles.single.kind, TileKind.notes);
  });

  testWidgets('the Quote tile shows a quote and refreshes to another', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'my_space_tiles': '[{"id":"q","kind":"quote","data":{}}]',
    });

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(400, 0), 1000); // swipe right → My Space
    await tester.pumpAndSettle();
    // Compare the quote itself: neighbouring quotes can share an author.
    String quote() => tester.widget<Text>(find.textContaining('“')).data!;
    final first = quote();

    await tester.tap(find.byTooltip('Another quote'));
    await tester.pumpAndSettle();
    expect(quote(), isNot(first));
    expect((await const MySpaceService().loadTiles()).single.data['shift'], 1);
  });

  testWidgets('the Hydration tile counts glasses and takes back a mis-tap', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'my_space_tiles': '[{"id":"h","kind":"hydration","data":{"goal":6}}]',
    });

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(400, 0), 1000); // swipe right → My Space
    await tester.pumpAndSettle();
    expect(find.text('0 of 6 glasses today'), findsOneWidget);

    // Within the drop row (the tile's header icon is a drop too).
    Finder drop(IconData icon) => find.descendant(of: find.byType(Wrap), matching: find.byIcon(icon));
    await tester.tap(drop(Icons.water_drop_outlined).at(3)); // the fourth drop fills four
    await tester.pumpAndSettle();
    expect(find.text('4 of 6 glasses today'), findsOneWidget);

    await tester.tap(drop(Icons.water_drop).at(3)); // tapping the last filled one takes it back
    await tester.pumpAndSettle();
    expect(find.text('3 of 6 glasses today'), findsOneWidget);
  });

  testWidgets('the Screen Time tile shows today, top three apps, and skips productive ones', (
    WidgetTester tester,
  ) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'mind_space_productive_apps': ['com.work'],
      'my_space_tiles': '[{"id":"s","kind":"screenTime","data":{}}]',
    });
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('installed_apps'),
      (call) async => [
        for (final (name, pkg) in [('Feed', 'com.feed'), ('Chat', 'com.chat'), ('Maps', 'com.maps'), ('Work', 'com.work')])
          {'name': name, 'package_name': pkg},
      ],
    );
    messenger.setMockMethodCallHandler(const MethodChannel('yinyang.launcher/usage'), (call) async {
      if (call.method == 'hasAccess') return true;
      var at = start;
      return [
        for (final (pkg, minutes) in [('com.feed', 30), ('com.work', 20), ('com.chat', 10), ('com.maps', 5), ('com.x', 1)])
          for (final type in ['foreground', 'background'])
            {
              'packageName': pkg,
              'type': type,
              'timestamp': (at = at.add(Duration(minutes: type == 'background' ? minutes : 1))).millisecondsSinceEpoch,
            },
      ];
    });

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(400, 0), 1000); // swipe right → My Space
    await tester.pumpAndSettle();

    expect(find.text('46m'), findsOneWidget); // 30 + 10 + 5 + 1; Work's 20 left out
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Maps'), findsOneWidget);
    expect(find.text('Work'), findsNothing);
    expect(find.text('1 open · 30m'), findsOneWidget);
  });

  testWidgets('the Calendar tile asks for access, then lists events by day', (WidgetTester tester) async {
    final now = DateTime.now();
    final later = DateTime(now.year, now.month, now.day, 23, 30);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'my_space_tiles': '[{"id":"c","kind":"calendar","data":{}}]',
    });
    var granted = false;
    final opened = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('yinyang.launcher/calendar'), (
      call,
    ) async {
      switch (call.method) {
        case 'hasAccess':
          return granted;
        case 'requestAccess':
          return granted = true;
        case 'openEvent':
          opened.add((call.arguments as Map)['id']);
          return null;
        default:
          return [
            {'id': 1, 'title': 'Standup', 'begin': later.millisecondsSinceEpoch, 'end': later.millisecondsSinceEpoch, 'allDay': false},
            {'id': 2, 'title': 'Trip', 'begin': tomorrow.millisecondsSinceEpoch, 'end': tomorrow.millisecondsSinceEpoch, 'allDay': true},
          ];
      }
    });

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(400, 0), 1000); // swipe right → My Space
    await tester.pumpAndSettle();

    await tester.tap(find.text('Allow calendar access'));
    await tester.pumpAndSettle();
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('Standup'), findsOneWidget);
    expect(find.text('TOMORROW'), findsOneWidget);
    expect(find.text('All day'), findsOneWidget);

    await tester.tap(find.text('Trip'));
    expect(opened, [2]);
  });

  testWidgets('the Music tile explains access first, then shows and controls what is playing', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'my_space_tiles': '[{"id":"m","kind":"music","data":{}}]',
    });
    var access = false;
    var playing = true;
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('yinyang.launcher/music'), (
      call,
    ) async {
      calls.add(call.method == 'control' ? 'control:${(call.arguments as Map)['action']}' : call.method);
      switch (call.method) {
        case 'hasAccess':
          return access;
        case 'nowPlaying':
          return {'title': 'Clair de lune', 'artist': 'Debussy', 'packageName': 'com.music', 'playing': playing};
        case 'control':
          playing = (call.arguments as Map)['action'] == 'play';
          return true;
      }
      return null;
    });

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(400, 0), 1000); // swipe right → My Space
    await tester.pumpAndSettle();

    await tester.tap(find.text('Allow notification access'));
    await tester.pumpAndSettle();
    expect(find.text('Notification access'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(calls, contains('openAccessSettings'));

    // Access granted on Android's screen; the tile picks it up on its next read.
    access = true;
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Clair de lune'), findsOneWidget);
    expect(find.text('Debussy'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(calls, contains('control:pause'));
    expect(find.byTooltip('Play'), findsOneWidget);
  });

  testWidgets('Manage tiles reorders and removes tiles', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'my_space_tiles':
          '[{"id":"n","kind":"notes","data":{"text":"Shopping list"}},'
          '{"id":"t","kind":"todo","data":{"items":[{"text":"Run","done":true},{"text":"Read","done":false}]}}]',
    });

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(400, 0), 1000); // swipe right → My Space
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Manage tiles'),
      200,
      scrollable: find.descendant(of: find.byType(MySpacePanel), matching: find.byType(Scrollable)).first,
    );
    await tester.tap(find.text('Manage tiles'));
    await tester.pumpAndSettle();
    expect(find.text('Shopping list'), findsOneWidget);
    expect(find.text('1 of 2 done'), findsOneWidget);

    // Drag Todo above Notes.
    final handle = find.byIcon(Icons.drag_handle).last;
    await tester.timedDrag(handle, const Offset(0, -150), const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect((await const MySpaceService().loadTiles()).map((t) => t.id), ['t', 'n']);

    // Remove Notes, after confirming.
    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect((await const MySpaceService().loadTiles()).map((t) => t.id), ['t']);
  });

  testWidgets('Action tab opens a tool through its one-time explainer', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('yinyang.launcher/usage'),
      (call) async => call.method == 'hasAccess' ? false : null,
    );

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(-400, 0), 1000); // swipe left → Mind Space
    await tester.pumpAndSettle();
    await tester.tap(find.text('Action'));
    await tester.pumpAndSettle();

    // First visit: the explainer, then the tool's page.
    await tester.tap(find.text('Mindful Pause'));
    await tester.pumpAndSettle();
    expect(find.text('What it does'), findsOneWidget);
    // The explainer's ListView builds lazily; scroll until the button exists.
    await tester.scrollUntilVisible(find.text("Let's go"), 200, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text("Let's go"));
    await tester.pumpAndSettle();
    expect(find.byType(MindfulPausePage), findsOneWidget);

    // Later visits go straight to the page.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mindful Pause'));
    await tester.pumpAndSettle();
    expect(find.text('What it does'), findsNothing);
    expect(find.byType(MindfulPausePage), findsOneWidget);
  });

  testWidgets('a strict Focus session has no way to exit early', (WidgetTester tester) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'focus_mode_active': true,
      'focus_mode_strict': true,
      'focus_mode_started_at': now.millisecondsSinceEpoch,
      'focus_mode_ends_at': now.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      'focus_mode_essentials': <String>[],
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('installed_apps'),
      (call) async => <Object>[],
    );

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('APPS'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Strict session · ends at'), findsOneWidget);
    expect(find.text('Exit focus mode'), findsNothing);

    // Mind Space's quick actions don't offer Stop either.
    Navigator.of(tester.element(find.textContaining('Strict session'))).pop();
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(-400, 0), 1000); // swipe left → Mind Space
    await tester.pumpAndSettle();
    await tester.tap(find.text('Action'));
    await tester.pumpAndSettle();
    expect(find.text('Stop'), findsNothing);
  });

  testWidgets('Focus session replaces Home; press-and-hold exits to a summary', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'focus_mode_active': true,
      'focus_mode_started_at': DateTime.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
      'focus_mode_essentials': ['com.phone'],
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('installed_apps'),
      (call) async => [
        {'name': 'Phone', 'package_name': 'com.phone'},
        {'name': 'Camera', 'package_name': 'com.camera'},
      ],
    );

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    expect(find.text('FOCUS SESSION'), findsOneWidget);
    expect(find.text('ELAPSED'), findsOneWidget);
    expect(find.text('Spotlight search'), findsNothing); // the normal Home layout is hidden

    await tester.tap(find.text('APPS'));
    await tester.pumpAndSettle();
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Camera'), findsNothing); // only allowed apps are listed

    // A plain tap doesn't exit; holding does.
    await tester.tap(find.text('Exit focus mode'));
    await tester.pumpAndSettle();
    expect(find.text('Exit focus mode'), findsOneWidget);
    await tester.longPress(find.text('Exit focus mode'));
    await tester.pumpAndSettle();
    expect(find.text('YOU FOCUSED FOR'), findsOneWidget);
    expect(find.text('5m'), findsOneWidget);

    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    expect(find.text('FOCUS SESSION'), findsNothing);
    expect(find.text('Spotlight search'), findsOneWidget);
  });
}
