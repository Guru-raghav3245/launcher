import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launcher/my_space/on_screen.dart';
import 'package:launcher/my_space/tiles/system_tile.dart';
import 'package:launcher/services/system_stats_service.dart';

void main() {
  test('gigabytes read like the phone labels them, and the summary uses them', () {
    expect(formatGigabytes(2840000000), '2.8 GB');
    expect(formatGigabytes(2850000000), '2.9 GB'); // rounds half up
    expect(formatGigabytes(41400000000), '41 GB');
    const stats = SystemStats(ramTotal: 2000, ramAvailable: 760, storageTotal: 64000000000, storageFree: 41000000000);
    expect(stats.ramFraction, closeTo(0.62, 0.001));
    expect(systemStatsSummary(stats), 'RAM 62% · 41 GB free');
    expect(systemStatsSummary(null), 'Live memory and storage');
  });

  testWidgets('the tile shows memory and storage, and polls only while My Space is on screen', (tester) async {
    var reads = 0;
    var available = 1080000000;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('student.launcher/app'), (
      call,
    ) async {
      if (call.method != 'systemStats') return null;
      reads++;
      return {
        'ramTotal': 2840000000,
        'ramAvailable': available,
        'lowMemory': false,
        'storageTotal': 64000000000,
        'storageFree': 41000000000,
      };
    });
    addTearDown(() => mySpaceOnScreen.value = false);

    mySpaceOnScreen.value = false;
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SystemTile())));
    await tester.pump();
    expect(reads, 1); // one reading when built, even off screen
    expect(find.text('RAM & STORAGE'), findsOneWidget); // in its card, like every tile
    expect(find.text('62%'), findsOneWidget); // 1.76 of 2.84 GB in use
    expect(find.text('1.8 GB of 2.8 GB'), findsOneWidget);
    expect(find.text('41 GB free of 64 GB'), findsOneWidget);
    expect(SystemStatsService.last?.storageFree, 41000000000);

    await tester.pump(const Duration(seconds: 6));
    expect(reads, 1); // off screen: no polling

    available = 284000000;
    mySpaceOnScreen.value = true;
    await tester.pump();
    expect(reads, 2); // back on screen: refreshed straight away
    await tester.pump();
    expect(find.text('90%'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(reads, 4); // then every 2 s

    mySpaceOnScreen.value = false;
    await tester.pump(const Duration(seconds: 6));
    expect(reads, 4);
  });
}
