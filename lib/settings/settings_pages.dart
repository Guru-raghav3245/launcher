import 'package:flutter/material.dart';

import '../onboarding/onboarding_flow.dart';
import '../search/app_multi_picker_sheet.dart';
import '../services/app_customizations_service.dart';
import '../services/launcher_role_service.dart';
import '../state/app_settings.dart';
import '../state/app_settings_scope.dart';
import 'appearance_editor.dart';
import 'drawer_look_page.dart';
import 'lock_gesture.dart';

// The original's Settings pages (Phase 11): full-screen, a ‹ and a
// letter-spaced title, outlined cards, caps section headers, ✎ rows that open
// a chooser sheet, and small outlined switches.

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

void openLauncherSettings(BuildContext context) => _push(context, const LauncherSettingsPage());
void openHomeSettings(BuildContext context) => _push(context, const HomeSettingsPage());
void openSpotlightSettings(BuildContext context) => _push(context, const SpotlightSettingsPage());
void openDrawerSettings(BuildContext context) => _push(context, const DrawerSettingsPage());
void openAppVisibility(BuildContext context) => _push(context, const AppVisibilityPage());
void openGeneralSettings(BuildContext context) => _push(context, const GeneralSettingsPage());

Color _soft(ColorScheme colors) => Color.lerp(colors.onSurface, colors.surface, 0.25)!;

/// A full-screen settings page: ‹, title, then [children] in a list.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: Icon(Icons.chevron_left, size: 32, color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 2),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(15, 8, 15, 32), children: children),
            ),
          ],
        ),
      ),
    );
  }
}

/// A plain section title ("Gestures", "Units & Format").
class _Title extends StatelessWidget {
  const _Title(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
    child: Text(label, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500)),
  );
}

/// A caps section header ("LOOK", "BEHAVIOUR").
class _Caps extends StatelessWidget {
  const _Caps(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 12, 0, 10),
    child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
  );
}

/// The outlined box every row sits in; several [children] get hairlines
/// between them.
class SettingsBox extends StatelessWidget {
  const SettingsBox({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.outline),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0) Divider(height: 1, indent: 12, endIndent: 12, color: colors.outlineVariant),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// One row: optional icon, title over an optional subtitle, and a trailing
/// widget (a ✎, a value, a switch, a ›).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.dense = false,
  });

  /// Switch rows and chooser options: smaller type, as in the original.
  final bool dense;

  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final big = icon != null; // the Launcher Settings index has larger titles
    final (titleSize, subtitleSize) = big ? (19.0, 14.0) : (dense ? (15.0, 13.0) : (17.0, 16.0));
    final faint = Color.lerp(colors.onSurface, colors.surface, 0.4);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(big ? 17 : 13, big ? 15 : 12, 13, big ? 15 : 12),
        child: Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 24, color: _soft(colors)), const SizedBox(width: 18)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: big ? FontWeight.w500 : FontWeight.w600,
                      letterSpacing: dense ? 0.3 : (big ? 0.8 : 1),
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: big ? 1 : 3),
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: subtitleSize, color: big ? faint : _soft(colors)),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    );
  }
}

/// The ✎ on rows that open a chooser.
class _Edit extends StatelessWidget {
  const _Edit();

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.edit_outlined, size: 24, color: _soft(Theme.of(context).colorScheme));
}

/// The original's small switch: off is an outlined track with a ringed
/// thumb, on a light track with a grey one.
class SmallSwitch extends StatelessWidget {
  const SmallSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? Color.lerp(colors.onSurface, colors.surface, 0.1) : null,
            border: Border.all(color: value ? Colors.transparent : colors.outline, width: 1.2),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? colors.onSurfaceVariant : colors.surfaceContainer,
              border: value ? null : Border.all(color: colors.outline, width: 1.2),
            ),
          ),
        ),
      ),
    );
  }
}

/// A switch row: tapping anywhere flips it.
class SwitchRow extends StatelessWidget {
  const SwitchRow({super.key, required this.title, this.subtitle, required this.value, required this.onChanged});

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SettingsRow(
    title: title,
    subtitle: subtitle,
    dense: true,
    onTap: () => onChanged(!value),
    trailing: SmallSwitch(value: value, onChanged: onChanged),
  );
}

/// The original's chooser: a titled sheet of outlined cards, the chosen one
/// ticked. Resolves with the picked value, or null if dismissed.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required T selected,
  required List<(T, String, String?)> options,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(),
    useSafeArea: true,
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      // Tall, with the options at the top, as in the original.
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(15, 16, 15, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
              ),
              const SizedBox(height: 22),
              for (final (value, label, subtitle) in options)
                SettingsBox(
                  children: [
                    SettingsRow(
                      title: label,
                      subtitle: subtitle,
                      onTap: () => Navigator.of(context).pop(value),
                      trailing: Icon(
                        value == selected ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 22,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Launcher Settings: the index of every settings page.
class LauncherSettingsPage extends StatelessWidget {
  const LauncherSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget card(IconData icon, String title, String subtitle, void Function(BuildContext) open) => SettingsBox(
      children: [SettingsRow(icon: icon, title: title, subtitle: subtitle, onTap: () => open(context))],
    );
    const gap = SizedBox(height: 26);
    return SettingsPage(
      title: 'Settings',
      children: [
        card(Icons.home_outlined, 'Home Settings', 'Customize gestures', openHomeSettings),
        card(Icons.palette_outlined, 'Appearance', 'Customize themes, fonts and more', showAppearanceEditor),
        gap,
        card(Icons.search, 'Spotlight', 'Search behavior', openSpotlightSettings),
        card(Icons.apps, 'App Drawer', 'Layout, keyboard, and search behavior', openDrawerSettings),
        card(Icons.visibility_off_outlined, 'App Visibility', 'Hidden apps', openAppVisibility),
        gap,
        card(Icons.settings_outlined, 'General', 'Time, units & onboarding', openGeneralSettings),
        gap,
        card(
          Icons.home_work_outlined,
          'Change Launcher',
          'Change your default launcher',
          (_) => const LauncherRoleService().openHomeSettings(),
        ),
      ],
    );
  }
}

const _swipeDownChoices = [
  (SwipeDownAction.spotlight, 'Spotlight Search', 'Quickly search apps from your home screen'),
  (SwipeDownAction.notifications, 'Notification Tray', 'Pull down to view notifications and toggles'),
  (SwipeDownAction.none, 'None', 'Disable this swipe gesture'),
];

const _doubleTapChoices = [
  (
    DoubleTapAction.lockAccessibility,
    'Lock Screen (Accessibility)',
    'Recommended — works with fingerprint or face unlock.',
  ),
  (DoubleTapAction.lockDeviceAdmin, 'Lock Screen (Device Admin)', 'Legacy method — may disable fingerprint unlock.'),
  (DoubleTapAction.none, 'None', 'Disable this gesture'),
];

String _labelOf<T>(List<(T, String, String?)> choices, T value) => choices.firstWhere((c) => c.$1 == value).$2;

/// Home Settings: what swiping down and double-tapping on Home do. Picking
/// a lock method sets up its permission straight away.
class HomeSettingsPage extends StatelessWidget {
  const HomeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    return SettingsPage(
      title: 'Home Settings',
      children: [
        const _Title('Gestures'),
        SettingsBox(
          children: [
            SettingsRow(
              title: 'Swipe Down',
              subtitle: _labelOf(_swipeDownChoices, settings.swipeDown),
              trailing: const _Edit(),
              onTap: () async {
                final choice = await showChoiceSheet(
                  context,
                  title: 'Choose Swipe Action',
                  selected: settings.swipeDown,
                  options: _swipeDownChoices,
                );
                if (choice != null) settings.setSwipeDown(choice);
              },
            ),
          ],
        ),
        SettingsBox(
          children: [
            SettingsRow(
              title: 'Double Tap',
              subtitle: _labelOf(_doubleTapChoices, settings.doubleTap),
              trailing: const _Edit(),
              onTap: () async {
                final choice = await showChoiceSheet(
                  context,
                  title: 'Choose Double Tap Action',
                  selected: settings.doubleTap,
                  options: _doubleTapChoices,
                );
                if (choice == null || !context.mounted) return;
                settings.setDoubleTap(choice);
                setUpLock(context, choice);
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Spotlight: its one behaviour switch (shared with the drawer).
class SpotlightSettingsPage extends StatelessWidget {
  const SpotlightSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    return SettingsPage(
      title: 'Spotlight',
      children: [
        SettingsBox(
          children: [
            SwitchRow(
              title: 'Auto open',
              subtitle: 'Open the app immediately when search narrows to a single result',
              value: settings.drawerOption(DrawerOption.autoOpenSingleResult),
              onChanged: (on) => settings.setDrawerOption(DrawerOption.autoOpenSingleResult, on),
            ),
          ],
        ),
      ],
    );
  }
}

/// App Drawer: its look, then the behaviour switches.
class DrawerSettingsPage extends StatelessWidget {
  const DrawerSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final look = settings.drawerLook;
    Widget option(DrawerOption option, String title, String subtitle) => SwitchRow(
      title: title,
      subtitle: subtitle,
      value: settings.drawerOption(option),
      onChanged: (on) => settings.setDrawerOption(option, on),
    );
    return SettingsPage(
      title: 'App Drawer',
      children: [
        const _Caps('LOOK'),
        SettingsBox(
          children: [
            SettingsRow(
              title: 'Drawer look',
              subtitle: [look.grid ? 'Grid · ${look.columns} columns' : 'List', if (look.headers) 'A–Z'].join(' · '),
              trailing: Icon(Icons.chevron_right, color: _soft(Theme.of(context).colorScheme)),
              onTap: () => _push(context, const DrawerLookPage()),
            ),
          ],
        ),
        const _Caps('BEHAVIOUR'),
        SettingsBox(
          children: [
            option(
              DrawerOption.keyboardOnOpen,
              'Open ready to type',
              'Search focused and the keyboard up as the drawer opens',
            ),
            option(DrawerOption.autoOpenSingleResult, 'Open single match', 'Opens the app when one result is left'),
            option(DrawerOption.hideUnusedApps, 'Hide unused apps', 'Not opened in 30 days · still searchable'),
            option(DrawerOption.recentAppsOnTop, 'Recent apps', 'The apps you opened last, at the top of the list'),
          ],
        ),
      ],
    );
  }
}

/// Hidden apps: the ones kept out of the App Drawer and Spotlight, ticked at
/// the top; untick one to bring it back (or tick more to hide them).
Future<void> showHiddenApps(BuildContext context) async {
  const customizations = AppCustomizationsService();
  await showAppMultiPicker(
    context,
    title: 'Hidden apps',
    subtitle: "Ticked apps don't show in the App Drawer or search.",
    load: () async => (await customizations.load()).hidden,
    onChanged: customizations.setHidden,
  );
}

class AppVisibilityPage extends StatelessWidget {
  const AppVisibilityPage({super.key});

  @override
  Widget build(BuildContext context) => SettingsPage(
    title: 'App Visibility',
    children: [
      SettingsBox(
        children: [
          SettingsRow(
            title: 'Hidden Apps',
            subtitle: 'View and unhide hidden apps',
            trailing: const _Edit(),
            onTap: () => showHiddenApps(context),
          ),
        ],
      ),
    ],
  );
}

const _timeFormatChoices = [
  (TimeFormat.system, 'Phone setting', null),
  (TimeFormat.h12, '12-hour', null),
  (TimeFormat.h24, '24-hour', null),
];

const _tempUnitChoices = [(TempUnit.celsius, 'Celsius (°C)', null), (TempUnit.fahrenheit, 'Fahrenheit (°F)', null)];

/// General: time format and temperature unit, and re-running onboarding.
class GeneralSettingsPage extends StatelessWidget {
  const GeneralSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    Widget value(String text) => Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600));
    return SettingsPage(
      title: 'App Preferences',
      children: [
        const _Title('Units & Format'),
        SettingsBox(
          children: [
            SettingsRow(
              title: 'Time Format',
              dense: true,
              trailing: value(_labelOf(_timeFormatChoices, settings.timeFormat)),
              onTap: () async {
                final choice = await showChoiceSheet<TimeFormat>(
                  context,
                  title: 'Choose Time Format',
                  selected: settings.timeFormat,
                  options: _timeFormatChoices,
                );
                if (choice != null) settings.setTimeFormat(choice);
              },
            ),
          ],
        ),
        SettingsBox(
          children: [
            SettingsRow(
              title: 'Temperature Unit',
              dense: true,
              trailing: value(_labelOf(_tempUnitChoices, settings.tempUnit)),
              onTap: () async {
                final choice = await showChoiceSheet<TempUnit>(
                  context,
                  title: 'Choose Temperature Unit',
                  selected: settings.tempUnit,
                  options: _tempUnitChoices,
                );
                if (choice != null) settings.setTempUnit(choice);
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _Title('Onboarding'),
        SettingsBox(
          children: [
            SettingsRow(
              title: 'Re-run onboarding',
              subtitle: 'The welcome and setup screens again',
              trailing: Icon(Icons.chevron_right, color: _soft(Theme.of(context).colorScheme)),
              onTap: () => rerunOnboarding(context),
            ),
          ],
        ),
      ],
    );
  }
}

/// Closes Settings, then shows onboarding over the shell; it pops itself
/// when finished (the completion flag stays set). From General and the
/// Settings sheet.
void rerunOnboarding(BuildContext context) {
  final navigator = Navigator.of(context);
  navigator.popUntil((route) => route.isFirst);
  navigator.push(
    MaterialPageRoute<void>(builder: (context) => OnboardingFlow(onFinished: () => Navigator.of(context).pop())),
  );
}
