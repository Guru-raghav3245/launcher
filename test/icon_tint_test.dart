import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launcher/search/app_result_row.dart';
import 'package:launcher/state/app_settings.dart';
import 'package:launcher/state/app_settings_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A 1x1 PNG, enough for Image.memory.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

void main() {
  Future<void> pumpIcon(WidgetTester tester, AppSettings settings) => tester.pumpWidget(
    AppSettingsScope(
      settings: settings,
      child: MaterialApp(home: AppIcon(icon: _png)),
    ),
  );

  testWidgets('app icons are grayscale by default, untouched in Classic', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();

    await pumpIcon(tester, settings);
    final filter = tester.widget<ColorFiltered>(find.byType(ColorFiltered)).colorFilter;
    expect(filter, ColorFilter.matrix(IconTint.grayscale.matrix!));

    await settings.setIconTint(IconTint.classic);
    await tester.pump();
    expect(find.byType(ColorFiltered), findsNothing);
  });

  test('every tint but Classic has a full 4x5 matrix', () {
    for (final tint in IconTint.values) {
      expect(tint.matrix?.length, tint == IconTint.classic ? isNull : 20);
    }
  });
}
