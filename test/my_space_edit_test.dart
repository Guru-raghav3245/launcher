import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:launcher/main.dart';
import 'package:launcher/models/tile_kind.dart';
import 'package:launcher/panels/home_panel.dart';
import 'package:launcher/panels/my_space_panel.dart';
import 'package:launcher/services/data_usage_service.dart';
import 'package:launcher/services/installed_apps_service.dart';
import 'package:launcher/services/my_space_service.dart';

String _tiles(String body) => '[$body]';

Future<void> _openMySpace(WidgetTester tester, Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues({'onboarding_complete': true, ...prefs});
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(const MethodChannel('student.launcher/role'), (call) async => null);
  messenger.setMockMethodCallHandler(const MethodChannel('installed_apps'), (call) async {
    if (call.method == 'getAppInfo') {
      final package = (call.arguments as Map)['package_name'] as String;
      return {'name': package.split('.').last, 'package_name': package};
    }
    return [];
  });
  await tester.pumpWidget(const StudentLauncherApp());
  await tester.pumpAndSettle();
  await tester.fling(find.byType(HomePanel), const Offset(400, 0), 1000); // swipe right → My Space
  await tester.pumpAndSettle();
}

Future<void> _longPress(WidgetTester tester, Finder finder) async {
  await tester.longPress(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(InstalledAppsService.invalidate);

  testWidgets('press and hold edits tiles; a folder can be renamed, and Done leaves edit mode', (tester) async {
    await _openMySpace(tester, {
      'my_space_tiles': _tiles('{"id":"f","kind":"appFolder","data":{"packages":["com.camera"]}}'),
    });
    expect(find.text('APP FOLDER'), findsOneWidget);
    expect(find.text('Done'), findsNothing);

    await _longPress(tester, find.text('APP FOLDER'));
    expect(find.text('Done'), findsOneWidget);
    expect(find.byTooltip('Add tile'), findsNothing); // the header's + gives way to Done

    await tester.tap(find.byTooltip('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Daily apps');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('DAILY APPS'), findsOneWidget);
    expect((await const MySpaceService().loadTiles()).single.name, 'Daily apps');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsNothing);
    expect(find.byTooltip('Add tile'), findsOneWidget);
  });

  testWidgets('a blank name restores the folder title', (tester) async {
    await _openMySpace(tester, {
      'my_space_tiles': _tiles('{"id":"f","kind":"appFolder","name":"Mine","data":{"packages":[]}}'),
    });
    expect(find.text('MINE'), findsOneWidget);
    await _longPress(tester, find.text('MINE'));
    await tester.tap(find.byTooltip('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('APP FOLDER'), findsOneWidget);
    expect((await const MySpaceService().loadTiles()).single.name, isNull);
  });

  testWidgets('edit mode removes a tile after confirming, and drags the order', (tester) async {
    await _openMySpace(tester, {
      'my_space_tiles': _tiles(
        '{"id":"n","kind":"notes","data":{"text":"Shopping list"}},'
        '{"id":"q","kind":"quote","data":{}}',
      ),
    });
    await _longPress(tester, find.text('NOTES'));

    // Drag Quote above Notes.
    await tester.timedDrag(find.byIcon(Icons.drag_handle).last, const Offset(0, -300), const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect((await const MySpaceService().loadTiles()).map((t) => t.id), ['q', 'n']);

    await tester.tap(find.byTooltip('Remove').last); // Notes is now last
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect((await const MySpaceService().loadTiles()).map((t) => t.id), ['q']);
  });

  testWidgets('an app folder in edit mode removes one app and keeps the rest', (tester) async {
    await _openMySpace(tester, {
      'my_space_tiles': _tiles('{"id":"f","kind":"appFolder","data":{"packages":["com.camera","com.clock"]}}'),
    });
    expect(find.text('camera'), findsOneWidget);
    await _longPress(tester, find.text('APP FOLDER'));
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(find.text('camera'), findsNothing);
    expect(find.text('clock'), findsOneWidget);
    expect((await const MySpaceService().loadTiles()).single.data['packages'], ['com.clock']);
  });

  testWidgets('the header + adds a tile', (tester) async {
    await _openMySpace(tester, {
      'my_space_tiles': _tiles('{"id":"n","kind":"notes","data":{"text":"x"}}'),
    });
    expect(find.text('Edit Tile'), findsNothing);
    expect(find.text('Add Tile'), findsNothing);
    await tester.tap(find.byTooltip('Add tile'));
    await tester.pumpAndSettle();
    expect(find.text('Add New Tile'), findsOneWidget);
    expect(find.byType(MySpacePanel), findsOneWidget);
  });

  testWidgets('a long Todo list scrolls inside its tile', (tester) async {
    final items = [for (var i = 0; i < 30; i++) '{"text":"Item $i","done":false}'].join(',');
    await _openMySpace(tester, {
      'my_space_tiles': _tiles('{"id":"t","kind":"todo","data":{"items":[$items]}}'),
    });
    expect(find.text('Item 29'), findsNothing); // beyond the tile's cap, not laid out yet
    final list = find.descendant(of: find.byType(MySpacePanel), matching: find.byType(ListView)); // the tile's list is the inner one
    await tester.drag(list.last, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('Item 29'), findsOneWidget);
  });

  testWidgets('Todo & Tasks swaps between a checklist and dated tasks', (tester) async {
    final today = DateTime.now();
    String iso(int days) => DateTime(today.year, today.month, today.day).add(Duration(days: days)).toIso8601String();
    await _openMySpace(tester, {
      'my_space_tiles': _tiles(
        '{"id":"t","kind":"todoTasks","data":{"items":[{"text":"Water plants","done":false}],'
        '"tasks":[{"text":"Later","done":false,"due":"${iso(5)}"},{"text":"Late","done":false,"due":"${iso(-2)}"},'
        '{"text":"Anytime","done":false},{"text":"Soon","done":false,"due":"${iso(1)}"}]}}',
      ),
    });
    expect(find.text('TO-DO'), findsOneWidget);
    expect(find.text('Water plants'), findsOneWidget);

    await tester.fling(find.text('Water plants'), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('TASKS'), findsOneWidget);
    // Soonest first, undated last; the late one is flagged.
    final order = ['Late', 'Soon', 'Later', 'Anytime'];
    final tops = [for (final t in order) tester.getTopLeft(find.text(t)).dy];
    expect(tops, [...tops]..sort());
    expect(find.textContaining('Overdue'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);

    // Ticking a task keeps its text and sinks it below the open ones.
    await tester.tap(find.text('Late'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Late')).dy, greaterThan(tester.getTopLeft(find.text('Later')).dy));
    final saved = (await const MySpaceService().loadTiles()).single;
    expect(saved.kind, TileKind.todoTasks);
    expect((saved.data['items'] as List).length, 1); // the checklist is untouched
  });

  test('formatBytes uses decimal units', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(999), '999 B');
    expect(formatBytes(1500), '1.5 KB');
    expect(formatBytes(180000000), '180 MB');
    expect(formatBytes(1400000000), '1.4 GB');
    expect(formatBytes(25000000000), '25 GB');
  });
}
