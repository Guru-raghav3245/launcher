import 'package:shared_preferences/shared_preferences.dart';

/// Persists Mindful Pause: the apps that get a breathing pause before they
/// open, and how long that pause lasts. Consulted by `launchApp` (see
/// `lib/widgets/launch_app.dart`) after Focus Mode's check.
class MindfulPauseService {
  const MindfulPauseService();

  static const _appsKey = 'mindful_pause_apps';
  static const _secondsKey = 'mindful_pause_seconds';

  static const minSeconds = 10;
  static const maxSeconds = 60;

  Future<Set<String>> pausedApps() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_appsKey) ?? const []).toSet();
  }

  Future<void> setPaused(String packageName, bool paused) async {
    final current = await pausedApps();
    if (paused) {
      current.add(packageName);
    } else {
      current.remove(packageName);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_appsKey, current.toList());
  }

  Future<bool> isPaused(String packageName) async => (await pausedApps()).contains(packageName);

  Future<int> seconds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_secondsKey) ?? minSeconds).clamp(minSeconds, maxSeconds);
  }

  Future<void> setSeconds(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_secondsKey, value.clamp(minSeconds, maxSeconds));
  }
}
