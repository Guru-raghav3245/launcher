import 'package:flutter_test/flutter_test.dart';

import 'package:launcher/main.dart';
import 'package:launcher/panels/home_panel.dart';
import 'package:launcher/panels/my_space_panel.dart';
import 'package:launcher/panels/mind_space_panel.dart';

void main() {
  testWidgets('launches on the Home panel', (WidgetTester tester) async {
    await tester.pumpWidget(const YinYangLauncherApp());

    expect(find.byType(HomePanel), findsOneWidget);
    expect(find.byType(MySpacePanel), findsNothing);
    expect(find.byType(MindSpacePanel), findsNothing);
  });

  testWidgets('swiping right reveals My Space', (WidgetTester tester) async {
    await tester.pumpWidget(const YinYangLauncherApp());

    await tester.fling(find.byType(HomePanel), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.byType(MySpacePanel), findsOneWidget);
  });
}
