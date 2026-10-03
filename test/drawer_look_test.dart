import 'package:flutter_test/flutter_test.dart';
import 'package:launcher/models/drawer_look.dart';
import 'package:launcher/search/drawer_apps_view.dart';

void main() {
  test('round-trips through JSON, and the default is the classic list', () {
    const look = DrawerLook(grid: true, columns: 5, iconSize: DrawerItemSize.large, headers: false);
    expect(DrawerLook.fromJson(look.toJson()), look);
    expect(DrawerLook.fromJson(const {}), const DrawerLook());
    expect(DrawerLook.fromJson(const {'columns': 9}).columns, DrawerLook.maxColumns);
  });

  test('row heights: list rows follow the setting, grid rows fit icon and label', () {
    expect(DrawerAppsView.rowHeight(const DrawerLook()), 64);
    expect(DrawerAppsView.rowHeight(const DrawerLook(rowHeight: DrawerRowHeight.compact)), 52);
    final oneLine = DrawerAppsView.rowHeight(const DrawerLook(grid: true));
    final twoLines = DrawerAppsView.rowHeight(const DrawerLook(grid: true, twoLineLabels: true));
    expect(twoLines, greaterThan(oneLine));
    expect(DrawerAppsView.rowHeight(const DrawerLook(grid: true, labelSize: DrawerItemSize.none)), 24 + 40);
  });
}
