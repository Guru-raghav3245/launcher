import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:launcher/main.dart';
import 'package:launcher/mind_space/tool_pages.dart';
import 'package:launcher/onboarding/onboarding_flow.dart';
import 'package:launcher/onboarding/steps/welcome_step.dart';
import 'package:launcher/panels/home_panel.dart';
import 'package:launcher/panels/my_space_panel.dart';
import 'package:launcher/panels/mind_space_panel.dart';
import 'package:launcher/services/focus_mode_service.dart';
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
    await tester.tap(find.text('Allowed apps'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clock'));
    await tester.pumpAndSettle();
    expect(await const FocusModeService().essentials(), {'com.clock'});

    await tester.tap(find.text('Clock'));
    await tester.pumpAndSettle();
    expect(await const FocusModeService().essentials(), isEmpty);
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
