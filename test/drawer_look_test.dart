import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:installed_apps/app_info.dart';
import 'package:launcher/models/drawer_look.dart';
import 'package:launcher/search/app_result_row.dart';
import 'package:launcher/search/drawer_apps_view.dart';

void main() {
  test('round-trips through JSON, and the default is the classic list', () {
    const look = DrawerLook(grid: true, columns: 5, iconSize: DrawerItemSize.large, headers: false);
    expect(DrawerLook.fromJson(look.toJson()), look);
    expect(DrawerLook.fromJson(const {}), const DrawerLook());
    expect(DrawerLook.fromJson(const {'columns': 9}).columns, DrawerLook.maxColumns);
  });

  test('row heights: list rows follow the setting, grid rows fit icon and label', () {
    expect(DrawerAppsView.rowHeight(const DrawerLook()), 49);
    expect(DrawerAppsView.rowHeight(const DrawerLook(rowHeight: DrawerRowHeight.compact)), 42);
    final oneLine = DrawerAppsView.rowHeight(const DrawerLook(grid: true));
    final twoLines = DrawerAppsView.rowHeight(const DrawerLook(grid: true, twoLineLabels: true));
    expect(twoLines, greaterThan(oneLine));
    expect(DrawerAppsView.rowHeight(const DrawerLook(grid: true, labelSize: DrawerItemSize.none)), 24 + 34);
  });

  testWidgets('in a grid, a two-line name doesn\'t push its icon out of line', (tester) async {
    AppInfo app(String name) => AppInfo.create({'name': name, 'package_name': 'p.$name'});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DrawerAppsView(
            sections: [
              (key: '', apps: [app('Clock'), app('Google Play Store and more'), app('Camera')]),
            ],
            look: const DrawerLook(grid: true, columns: 3, twoLineLabels: true, headers: false),
            onLaunch: (_) {},
            showIndex: false,
          ),
        ),
      ),
    );
    final tops = {for (final icon in tester.widgetList(find.byType(AppIcon))) tester.getTopLeft(find.byWidget(icon)).dy};
    expect(tops, hasLength(1)); // all three icons on one line
  });
}
