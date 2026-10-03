import 'package:shared_preferences/shared_preferences.dart';

import 'usage_stats_service.dart';

/// Persists the "productive" apps whose time Mind Space leaves out of its
/// stats (work tools, maps, a reading app...), so the numbers reflect the
/// use you actually want to cut down.
class ProductiveAppsService {
  const ProductiveAppsService();

  static const _key = 'mind_space_productive_apps';

  Future<Set<String>> apps() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  Future<void> setProductive(String packageName, bool productive) async {
    final current = await apps();
    productive ? current.add(packageName) : current.remove(packageName);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, current.toList());
  }
}

/// [events] minus the foreground/background events of [productive] apps;
/// unlocks are kept, so pickups still count.
List<UsageEvent> withoutProductive(List<UsageEvent> events, Set<String> productive) => [
  for (final e in events)
    if (e.type == UsageEventType.unlocked || !productive.contains(e.packageName)) e,
];
