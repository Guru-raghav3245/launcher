import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the first-run onboarding flow (Phase 2) has been
/// completed, so it only shows before a launcher is set as default.
class OnboardingService {
  const OnboardingService();

  static const _key = 'onboarding_complete';

  Future<bool> isComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
