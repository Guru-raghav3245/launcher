import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:launcher/main.dart';
import 'package:launcher/models/drawer_look.dart';
import 'package:launcher/models/home_layout_mode.dart';
import 'package:launcher/state/app_settings.dart';
import 'package:launcher/state/app_settings_scope.dart';
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
import 'package:launcher/services/installed_apps_service.dart';
import 'package:launcher/services/my_space_service.dart';
import 'package:launcher/services/tour_service.dart';
import 'package:launcher/settings/drawer_look_page.dart';
import 'package:launcher/settings/settings_screen.dart';

void main() {
  setUp(InstalledAppsService.invalidate);

  testWidgets('shows onboarding on first run', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingFlow), findsOneWidget);
    expect(find.byType(WelcomeStep), findsOneWidget);
    expect(find.byType(HomePanel), findsNothing);
  });

  testWidgets('launches on the Home panel once onboarding is complete', (WidgetTester tester) async {
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

  testWidgets('the Appearance editor previews live, Cancel reverts and Save keeps', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    final settings = AppSettingsScope.of(tester.element(find.byType(HomePanel)));
    Future<void> openHomeStyle() async {
      if (find.byType(SettingsScreen).evaluate().isEmpty) {
        await tester.longPress(find.byType(HomePanel).first);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Appearance')); // Settings stays open under the editor
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
    }

    await openHomeStyle();
    expect(find.text('Home › Style'), findsOneWidget);
    await tester.tap(find.text('Minimal'));
    await tester.pumpAndSettle();
    expect(settings.layoutMode, HomeLayoutMode.minimal); // the preview is the real thing
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(settings.layoutMode, HomeLayoutMode.classic);

    await openHomeStyle();
    await tester.tap(find.text('Minimal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(settings.layoutMode, HomeLayoutMode.minimal);
    expect((await SharedPreferences.getInstance()).getString('settings_layout_mode'), 'minimal');
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

  testWidgets('Toggles pick the theme and start or stop Focus Mode', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(HomePanel));
    await tester.pumpAndSettle();

    expect(find.text('Theme · Light'), findsOneWidget);
    await tester.tap(find.text('Theme · Light'));
    await tester.pumpAndSettle();
    expect(find.text('Choose Theme'), findsOneWidget);
    await tester.tap(find.text('Auto'));
    await tester.pumpAndSettle();
    expect(find.text('Theme · Auto'), findsOneWidget);
    expect(find.text('Follows your phone'), findsOneWidget);

    // Off, Focus Mode opens its start sheet; on, a tap stops it.
    await tester.tap(find.text('Focus Mode').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect((await const FocusModeService().status()).active, true);
    await tester.tap(find.text('On · tap to stop'));
    await tester.pumpAndSettle();
    expect((await const FocusModeService().status()).active, false);
  });

  testWidgets('Home honours the clock style, position, search bar, and status bar settings', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'settings_time_format': 'h24', // expects zero-padded 24-hour times
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
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    // (At 23:23 both lines read "23".)
    expect(find.text(hour), hour == minute ? findsNWidgets(2) : findsOneWidget);
    // Bottom: the clock sits below the middle of Home.
    final clockY = tester.getCenter(find.text(minute).last).dy;
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

  testWidgets('a deep gradient gives Home light text, even in the light theme', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'settings_time_format': 'h24', // expects zero-padded 24-hour times
      'onboarding_complete': true,
      'settings_wallpaper_light': 'gradient-ocean',
    });

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    expect(tester.widget<Text>(find.text(time)).style!.color, const Color(0xFFEBEBEB)); // the dark palette's ink
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.light);
    // The search pill is a translucent wash over the gradient, not a solid slab.
    final pill = tester.widget<Container>(
      find.ancestor(of: find.text('Spotlight search'), matching: find.byType(Container)).first,
    );
    expect((pill.decoration! as BoxDecoration).color!.a, closeTo(0.1, 0.01));
  });

  testWidgets('a 12-hour time format shows Home as zero-padded 12-hour time and applies app-wide', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true, 'settings_time_format': 'h12'});

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    final now = DateTime.now();
    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    expect(find.text('${hour12.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}'), findsOneWidget);
    expect(MediaQuery.alwaysUse24HourFormatOf(tester.element(find.byType(HomePanel))), false);
  });

  testWidgets('temperatures convert to Fahrenheit when chosen', (WidgetTester tester) async {
    final settings = AppSettings();
    expect(settings.formatTemp(20), '20°');
    SharedPreferences.setMockInitialValues({});
    await settings.setTempUnit(TempUnit.fahrenheit);
    expect(settings.formatTemp(20), '68°');
    expect(settings.formatTemp(-40), '-40°');
  });

  testWidgets('the chosen font and text size apply app-wide', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'settings_font': 'notoSerif',
      'settings_text_size': 'large',
    });

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    final home = tester.element(find.byType(HomePanel));
    expect(Theme.of(home).textTheme.bodyMedium!.fontFamily, 'Noto Serif');
    expect(MediaQuery.textScalerOf(home).scale(10), closeTo(11.5, 0.01));
  });

  testWidgets('Launcher Settings re-runs onboarding', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(HomePanel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Launcher Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('General'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Re-run onboarding'));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeStep), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
  });

  testWidgets('Launcher Settings pages: a chooser sets a gesture, a switch sets a drawer option', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    final settings = AppSettingsScope.of(tester.element(find.byType(HomePanel)));
    await tester.longPress(find.byType(HomePanel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Launcher Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Spotlight Search'), findsOneWidget); // Swipe Down's current action
    await tester.tap(find.text('Swipe Down'));
    await tester.pumpAndSettle();
    expect(find.text('Choose Swipe Action'), findsOneWidget);
    await tester.tap(find.text('Notification Tray'));
    await tester.pumpAndSettle();
    expect(settings.swipeDown, SwipeDownAction.notifications);
    expect(find.text('Notification Tray'), findsOneWidget); // the row's value now

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    await tester.tap(find.text('App Drawer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recent apps'));
    await tester.pumpAndSettle();
    expect(settings.drawerOption(DrawerOption.recentAppsOnTop), true);
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
    SharedPreferences.setMockInitialValues({
      'settings_time_format': 'h24', // expects zero-padded 24-hour times
      'onboarding_complete': true,
    });
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
    await tester.enterText(find.byType(TextField), 'allowed'); // a search-only entry
    await tester.pump();
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
    await tester.enterText(find.byType(TextField), 'hidden'); // a search-only entry
    await tester.pump();
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

  testWidgets('an app on a Mindful Break is hidden from the drawer and blocked elsewhere', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'mindful_break_apps': '{"com.chrome":${DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch}}',
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
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('45m'), findsNWidgets(2)); // the day's total and Feed's row
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
    expect(find.text('◷'), findsNWidgets(2)); // the Recent header and its index entry
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
    expect(find.text('Chrome'), findsOneWidget); // a recent app card
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
        for (final (name, pkg) in [
          ('Feed', 'com.feed'),
          ('Chat', 'com.chat'),
          ('Maps', 'com.maps'),
          ('Work', 'com.work'),
        ])
          {'name': name, 'package_name': pkg},
      ],
    );
    messenger.setMockMethodCallHandler(const MethodChannel('yinyang.launcher/usage'), (call) async {
      if (call.method == 'hasAccess') return true;
      var at = start;
      return [
        for (final (pkg, minutes) in [
          ('com.feed', 30),
          ('com.work', 20),
          ('com.chat', 10),
          ('com.maps', 5),
          ('com.x', 1),
        ])
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
            {
              'id': 1,
              'title': 'Standup',
              'begin': later.millisecondsSinceEpoch,
              'end': later.millisecondsSinceEpoch,
              'allDay': false,
            },
            {
              'id': 2,
              'title': 'Trip',
              'begin': tomorrow.millisecondsSinceEpoch,
              'end': tomorrow.millisecondsSinceEpoch,
              'allDay': true,
            },
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
      find.text('Edit Tile'),
      200,
      scrollable: find.descendant(of: find.byType(MySpacePanel), matching: find.byType(Scrollable)).first,
    );
    await tester.tap(find.text('Edit Tile'));
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

  testWidgets('the drawer lays apps out as a grid without headers when chosen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'settings_drawer_look': '{"grid":true,"columns":3,"headers":false}',
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('installed_apps'),
      (call) async => [
        for (final name in ['Camera', 'Chrome', 'Clock', 'Drive']) {'name': name, 'package_name': 'com.$name'},
      ],
    );

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(0, -400), 1000); // swipe up → App Drawer
    await tester.pumpAndSettle();

    double y(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(y('Chrome'), y('Camera')); // three to a row
    expect(y('Clock'), y('Camera'));
    expect(y('Drive'), greaterThan(y('Camera'))); // the fourth wraps
    // No section header (the index strip on the side still lists C).
    expect(find.byWidgetPredicate((w) => w is Text && w.data == 'C' && w.style?.fontSize == 13), findsNothing);
  });

  testWidgets('the Drawer look editor saves changes and resets them', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('installed_apps'),
      (call) async => [
        {'name': 'Camera', 'package_name': 'com.camera'},
      ],
    );

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(HomePanel), warnIfMissed: false);
    final settings = AppSettingsScope.of(tester.element(find.byType(HomePanel)));
    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: const MaterialApp(home: DrawerLookPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Grid'));
    await tester.pumpAndSettle();
    expect(settings.drawerLook.grid, true);
    expect(find.text('Columns'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(settings.drawerLook, const DrawerLook());
  });

  testWidgets('a guided tour shows its hint and finishes when the real gesture is made', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('installed_apps'),
      (call) async => <Object>[],
    );

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take a look around'));
    await tester.pumpAndSettle();
    expect(find.text('Pick one. You can open this again anytime.'), findsOneWidget);
    await tester.tap(find.text('Find my apps'));
    await tester.pumpAndSettle();
    expect(find.text('Swipe up to see all your apps'), findsOneWidget);

    // The hint lets the real swipe through; arriving in the drawer ends it.
    await tester.fling(find.byType(HomePanel), const Offset(0, -400), 1000);
    await tester.pumpAndSettle();
    expect(find.byType(AppDrawerPanel), findsOneWidget);
    expect(find.text('Swipe up to see all your apps'), findsNothing);
    expect(await const TourService().done(), {Tour.findApps});
  });

  testWidgets('Skip tour retires the Home chip', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take a look around'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip tour'));
    await tester.pumpAndSettle();
    expect(find.text('Take a look around'), findsNothing);
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

    // ⓘ brings the explainer back; its button returns to the page.
    await tester.tap(find.byTooltip('About Mindful Pause'));
    await tester.pumpAndSettle();
    expect(find.text('What it does'), findsOneWidget);
    await tester.scrollUntilVisible(find.text("Let's go"), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text("Let's go"));
    await tester.pumpAndSettle();
    expect(find.text('What it does'), findsNothing);

    // Later visits go straight to the page.
    await tester.tap(find.byIcon(Icons.chevron_left));
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

  testWidgets('DM Sans and the original palette are the defaults', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true, 'settings_theme': 'dark'});

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    final theme = Theme.of(tester.element(find.byType(HomePanel)));
    expect(theme.textTheme.bodyMedium!.fontFamily, 'DM Sans');
    expect(theme.scaffoldBackgroundColor, Colors.black);
    expect(theme.colorScheme.onSurface, const Color(0xFFEBEBEB));
    expect(theme.colorScheme.onSurfaceVariant, const Color(0xFF757575));
  });

  testWidgets('the Home key brings any panel back to Home', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(MindSpacePanel)).dx, 0);

    // What MainActivity.onNewIntent sends for a HOME intent.
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'yinyang.launcher/app',
      const StandardMethodCodec().encodeMethodCall(const MethodCall('home')),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(HomePanel)).dx, 0);
  });

  testWidgets('Spotlight shows four cards, recent first, and Enter opens the first', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    final started = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('installed_apps'), (call) async {
      if (call.method == 'startApp') {
        started.add(call.arguments);
        return true;
      }
      return [
        {'name': 'Calculator', 'package_name': 'com.calc'},
        {'name': 'Calendar', 'package_name': 'com.calendar'},
        {'name': 'Camera', 'package_name': 'com.camera'},
        {'name': 'Chrome', 'package_name': 'com.chrome'},
        {'name': 'Clock', 'package_name': 'com.clock'},
        {'name': 'launcher', 'package_name': 'com.example.launcher'}, // this app: never listed
      ];
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('yinyang.launcher/usage'), (
      call,
    ) async {
      if (call.method == 'hasAccess') return true;
      if (call.method == 'lastUsed') return {'com.chrome': DateTime.now().millisecondsSinceEpoch};
      return <Object>[];
    });

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(0, 400), 1000); // swipe down → Spotlight
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'c');
    await tester.pumpAndSettle();
    // Recently used Chrome first, then alphabetical, four at most.
    expect(find.text('Chrome'), findsOneWidget);
    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Clock'), findsNothing);
    expect(find.text('launcher'), findsNothing);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(started.single, {'package_name': 'com.chrome'});
  });

  testWidgets("the drawer's close button goes back Home", (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('installed_apps'),
      (call) async => [
        {'name': 'Chrome', 'package_name': 'com.chrome'},
      ],
    );

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(0, -400), 1000); // swipe up → App Drawer
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(AppDrawerPanel)).dy, 0);

    await tester.tap(find.descendant(of: find.byType(AppDrawerPanel), matching: find.byIcon(Icons.close)));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(HomePanel)).dy, 0);
  });

  testWidgets('pulling down past the top of the drawer list goes back Home', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('installed_apps'),
      // Enough apps that the list scrolls (and so takes the drag itself).
      (call) async => [
        for (var i = 0; i < 40; i++) {'name': 'App ${String.fromCharCode(65 + i % 26)}$i', 'package_name': 'com.app$i'},
      ],
    );

    await tester.pumpWidget(const YinYangLauncherApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(HomePanel), const Offset(0, -400), 1000); // swipe up → App Drawer
    await tester.pumpAndSettle();
    final list = find.descendant(of: find.byType(AppDrawerPanel), matching: find.byType(ListView));

    // Scrolled down, a pull down scrolls the list back first.
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.drag(list, const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(AppDrawerPanel)).dy, 0);

    // At the top, the next pull goes Home.
    await tester.drag(list, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(HomePanel)).dy, 0);
  });
}
