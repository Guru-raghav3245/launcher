import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launcher/models/my_space_tile.dart';
import 'package:launcher/models/tile_kind.dart';
import 'package:launcher/my_space/add_tile_sheet.dart';
import 'package:launcher/my_space/manage_tiles_page.dart';
import 'package:launcher/my_space/widget_preview.dart';
import 'package:launcher/services/installed_apps_service.dart';

// A 1×1 PNG, standing in for a rendered widget preview.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');
const _clockWidget = 'com.clock/.ClockWidget';

void main() {
  setUp(InstalledAppsService.invalidate);

  testWidgets('From Apps rows show a preview; tapping expands it, and only Add tile binds', (tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('installed_apps'),
      (call) async => [
        {'name': 'Clock', 'package_name': 'com.clock'},
      ],
    );
    final calls = <String>[];
    var previews = 0;
    messenger.setMockMethodCallHandler(const MethodChannel('student.launcher/appwidget'), (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'listProviders':
          return [
            {'provider': _clockWidget, 'packageName': 'com.clock', 'label': 'Digital clock'},
          ];
        case 'preview':
          previews++;
          return _png;
        case 'allocateId':
          return 7;
        case 'bind':
          return true;
      }
      return null;
    });

    MySpaceTile? added;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => added = await showAddTileSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('From Apps'));
    await tester.pumpAndSettle();

    expect(find.text('Digital clock'), findsOneWidget);
    expect(find.byType(WidgetPreview), findsOneWidget); // the row's thumbnail
    expect(find.byType(Image), findsWidgets);

    await tester.tap(find.text('Digital clock'));
    await tester.pumpAndSettle();
    expect(find.text('Add tile'), findsOneWidget); // expanded, not bound yet
    expect(calls, isNot(contains('bind')));
    expect(tester.getSize(find.byType(WidgetPreview)).height, 180);

    await tester.tap(find.text('Add tile'));
    await tester.pumpAndSettle();
    expect(calls, containsAllInOrder(['allocateId', 'bind']));
    expect(added?.kind, TileKind.fromApp);
    expect(added?.data['provider'], _clockWidget);
    expect(previews, 1); // rendered once, reused when expanded

    // Manage tiles shows the same (cached) preview on the tile's row.
    await tester.pumpWidget(MaterialApp(home: ManageTilesPage(tiles: [added!], onChanged: (_) {})));
    await tester.pumpAndSettle();
    expect(find.byType(WidgetPreview), findsOneWidget);
    expect(previews, 1);
  });
}
