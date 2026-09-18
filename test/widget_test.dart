import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:launcher/main.dart';
import 'package:launcher/onboarding/onboarding_flow.dart';
import 'package:launcher/onboarding/steps/welcome_step.dart';
import 'package:launcher/panels/home_panel.dart';
import 'package:launcher/panels/my_space_panel.dart';
import 'package:launcher/panels/mind_space_panel.dart';

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
}
