import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:launcher/main.dart';
import 'package:launcher/onboarding/onboarding_flow.dart';
import 'package:launcher/onboarding/steps/welcome_step.dart';
import 'package:launcher/panels/home_panel.dart';
import 'package:launcher/panels/my_space_panel.dart';
import 'package:launcher/panels/mind_space_panel.dart';
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
}
