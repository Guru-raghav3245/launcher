import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The guided tours offered by "Take a look around" (Phase 10 task 8),
/// after the original launcher's: each points at one gesture, and doing
/// that gesture for real completes it.
enum Tour {
  findApps('Find my apps', 'Swipe up', Icons.arrow_upward, 'Swipe up to search or see all your apps'),
  usePhoneLess('Use my phone less', 'Swipe left', Icons.arrow_back, 'Swipe left to see where your time goes'),
  organizeDay('Organize my day', 'Swipe right', Icons.arrow_forward, 'Swipe right for notes, to-dos and more'),
  customizeHome(
    'Customize my home',
    'Press and hold',
    Icons.fiber_manual_record,
    'Press and hold anywhere for Settings',
  );

  const Tour(this.title, this.gesture, this.icon, this.prompt);
  final String title;
  final String gesture;
  final IconData icon;
  final String prompt;
}

/// Which tour is running ([active]), and which are done or were skipped.
/// The shell completes a tour when its destination appears.
class TourService {
  const TourService();

  static const _doneKey = 'tours_done';
  static const _skippedKey = 'tours_skipped';

  /// The tour whose hint Home is showing, if any.
  static final active = ValueNotifier<Tour?>(null);

  /// Bumped when tours finish or are skipped, so Home can drop its chip.
  static final changes = ValueNotifier<int>(0);

  Future<Set<Tour>> done() async {
    final prefs = await SharedPreferences.getInstance();
    return {for (final name in prefs.getStringList(_doneKey) ?? const <String>[]) Tour.values.byName(name)};
  }

  /// Home offers the chip until every tour is done or the user skipped.
  Future<bool> offerChip() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_skippedKey) ?? false) && (await done()).length < Tour.values.length;
  }

  Future<void> skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_skippedKey, true);
    changes.value++;
  }

  static void start(Tour tour) => active.value = tour;

  static void cancel() => active.value = null;

  /// Called by the shell when [tour]'s destination appears: if that tour is
  /// running, it's done.
  static Future<void> complete(Tour tour) async {
    if (active.value != tour) return;
    active.value = null;
    final prefs = await SharedPreferences.getInstance();
    final done = await const TourService().done();
    await prefs.setStringList(_doneKey, [
      for (final t in {...done, tour}) t.name,
    ]);
    changes.value++;
  }
}
