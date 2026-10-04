import 'package:flutter_test/flutter_test.dart';
import 'package:installed_apps/app_info.dart';
import 'package:launcher/services/app_customizations_service.dart';
import 'package:launcher/services/installed_apps_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppInfo app(String name, String packageName) => AppInfo.create({'name': name, 'package_name': packageName});

void main() {
  const service = AppCustomizationsService();
  final apps = [app('Camera', 'com.camera'), app('Chrome', 'com.chrome'), app('Clock', 'com.clock')];

  setUp(() {
    InstalledAppsService.invalidate();
    SharedPreferences.setMockInitialValues({});
  });

  test('pins keep their order, and unpinning removes', () async {
    await service.setPinned('com.clock', true);
    await service.setPinned('com.camera', true);
    expect((await service.load()).pinned, ['com.clock', 'com.camera']);
    await service.setPinned('com.clock', false);
    expect((await service.load()).pinned, ['com.camera']);
  });

  test('renames and hidden apps apply to a list, re-sorted by the new names', () async {
    await service.rename('com.chrome', '  Web  ');
    await service.setHidden('com.camera', true);
    final c = await service.load();
    expect(c.apply(apps).map((a) => a.name), ['Clock', 'Web']);
    expect(c.apply(apps, includeHidden: true).map((a) => a.name), ['Camera', 'Clock', 'Web']);

    await service.rename('com.chrome', '');
    await service.setHidden('com.camera', false);
    expect((await service.load()).apply(apps).map((a) => a.name), ['Camera', 'Chrome', 'Clock']);
  });

  test('every write notifies listeners', () async {
    var notified = 0;
    void listener() => notified++;
    AppCustomizationsService.changes.addListener(listener);
    addTearDown(() => AppCustomizationsService.changes.removeListener(listener));
    await service.setPinned('com.clock', true);
    await service.setHidden('com.clock', true);
    await service.rename('com.clock', 'Time');
    expect(notified, 3);
  });
}
