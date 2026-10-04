import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';

import '../mind_space/focus_session_view.dart';
import '../models/home_layout_mode.dart';
import '../search/app_picker_sheet.dart';
import '../search/app_result_row.dart';
import '../services/app_customizations_service.dart';
import '../services/dock_service.dart';
import '../services/installed_apps_service.dart';
import '../services/tour_service.dart';
import '../services/focus_mode_service.dart';
import '../settings/lock_gesture.dart';
import '../settings/settings_screen.dart';
import '../state/app_settings.dart';
import '../state/app_settings_scope.dart';
import '../state/launcher_theme.dart';
import '../widgets/launch_app.dart';
import '../widgets/tour.dart';

const _weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "20:30" in 24-hour, "08:30" in 12-hour: zero-padded either way and no
/// AM/PM on Home's big clock, as in the original (the format follows
/// Settings → Time & units).
String formatClockTime(DateTime time, {required bool use24}) {
  final hour = (use24 ? time.hour : (time.hour % 12 == 0 ? 12 : time.hour % 12)).toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatClockDate(DateTime date) {
  final weekday = _weekdayNames[date.weekday - 1];
  final month = _monthNames[date.month - 1];
  return '$weekday, ${date.day} $month';
}

const _glyphIcons = {
  DockGlyph.phone: Icons.call_outlined,
  DockGlyph.messages: Icons.chat_outlined,
  DockGlyph.browser: Icons.language,
  DockGlyph.camera: Icons.camera_alt_outlined,
};

/// A dock slot resolved for display: its app (null if empty or no longer
/// installed) and the glyph to draw instead of the app's icon, if any.
typedef _DockItem = ({AppInfo? app, IconData? glyph});

/// Home panel: wallpaper background, live clock, date, and
/// pinned apps in either Classic or Minimal layout.
class HomePanel extends StatefulWidget {
  const HomePanel({super.key, this.preview = false});

  /// Drawn inside a phone preview (onboarding, the Appearance editor):
  /// no tour chip.
  final bool preview;

  @override
  State<HomePanel> createState() => _HomePanelState();
}

class _HomePanelState extends State<HomePanel> {
  late final Timer _clockTimer;
  DateTime _now = DateTime.now();
  FocusStatus _focus = const FocusStatus(active: false);
  List<_DockItem> _dock = const [];
  var _offerTour = false;
  List<AppInfo> _apps = const [];

  @override
  void initState() {
    super.initState();
    DockService.changes.addListener(_refreshDock);
    AppCustomizationsService.changes.addListener(_refreshDock);
    InstalledAppsService.changes.addListener(_refreshDock);
    _refreshDock();
    TourService.changes.addListener(_refreshTour);
    _refreshTour();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
      // A timed session ends on its own; status() notices and clears it.
      final endsAt = _focus.endsAt;
      if (endsAt != null && _now.isAfter(endsAt)) _refreshFocus();
    });
    FocusModeService.changes.addListener(_refreshFocus);
    _refreshFocus();
  }

  Future<void> _refreshFocus() async {
    final status = await const FocusModeService().status();
    if (mounted) setState(() => _focus = status);
  }

  /// Resolves the dock's slots against the installed apps (renamed, and
  /// including hidden ones: the user put them there).
  Future<void> _refreshDock() async {
    final (slots, apps) = await (const DockService().slots(), loadCustomizedApps(includeHidden: true)).wait;
    final byPackage = {for (final app in apps) app.packageName: app};
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _dock = [
        for (final slot in slots)
          (app: byPackage[slot.packageName], glyph: slot.glyph == null ? null : _glyphIcons[slot.glyph]),
      ];
    });
  }

  void _openSlot(int index) {
    final app = _dock[index].app;
    app == null ? _changeSlot(index) : launchApp(context, app);
  }

  Future<void> _changeSlot(int index) async {
    final app = await showAppPicker(context, _apps, title: 'Dock app');
    if (app != null) await const DockService().setSlot(index, app.packageName);
  }

  Future<void> _refreshTour() async {
    final offer = await const TourService().offerChip();
    if (mounted) setState(() => _offerTour = offer);
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    FocusModeService.changes.removeListener(_refreshFocus);
    DockService.changes.removeListener(_refreshDock);
    TourService.changes.removeListener(_refreshTour);
    AppCustomizationsService.changes.removeListener(_refreshDock);
    InstalledAppsService.changes.removeListener(_refreshDock);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    // Ink follows the wallpaper, not the theme: a deep gradient gets white
    // text even in the light theme, as in the original.
    final wallpaper = settings.wallpaper;
    final isDark = wallpaper.isDark;
    final subtitle = formatClockDate(_now);

    final tourChip = _offerTour && !widget.preview ? TourChip(ink: Theme.of(context).colorScheme.onSurface) : null;

    return GestureDetector(
      onLongPress: () => showSettingsScreen(context),
      // Only listened for when set: a double-tap recognizer makes every
      // single tap on Home wait out the double-tap window first.
      onDoubleTap: settings.doubleTap == DoubleTapAction.none ? null : () => lockScreen(context, settings.doubleTap),
      child: Container(
        decoration: BoxDecoration(gradient: wallpaper.gradient),
        child: Theme(
          // So Home's contents (the Focus session screen included) read the
          // wallpaper's brightness, which can differ from the app theme.
          data: launcherTheme(isDark ? Brightness.dark : Brightness.light, fontFamily: settings.font.family),
          // Status bar icons too: light ones on a deep wallpaper.
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            child: ValueListenableBuilder<Tour?>(
              valueListenable: TourService.active,
              builder: (context, tour, content) => Stack(
                // Full width for every layout; loose, the Focus session's
                // column shrank to its text and sat left of centre.
                fit: StackFit.expand,
                children: [
                  content!,
                  if (tour != null) TourOverlay(tour: tour, isDark: isDark),
                ],
              ),
              child: SafeArea(
                child: _focus.active
                    ? FocusSessionView(status: _focus, now: _now)
                    : settings.layoutMode == HomeLayoutMode.classic
                    ? _ClassicLayout(
                        time: formatClockTime(_now, use24: MediaQuery.alwaysUse24HourFormatOf(context)),
                        subtitle: subtitle,
                        isDark: isDark,
                        settings: settings,
                        dock: _dock,
                        onOpen: _openSlot,
                        onChange: _changeSlot,
                        tourChip: tourChip,
                      )
                    : _MinimalLayout(
                        time: formatClockTime(_now, use24: MediaQuery.alwaysUse24HourFormatOf(context)),
                        subtitle: subtitle,
                        isDark: isDark,
                        settings: settings,
                        dock: _dock,
                        onOpen: _openSlot,
                        onChange: _changeSlot,
                        tourChip: tourChip,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Clock extends StatelessWidget {
  const _Clock({required this.time, required this.subtitle, required this.isDark, required this.style});

  final String time;
  final String subtitle;
  final bool isDark;
  final ClockStyle style;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.onSurface;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final date = Text(subtitle, style: TextStyle(fontSize: 15, color: secondary));
    // Original: the date in full ink above a big medium-weight time, both in
    // Roboto whatever the app font is.
    // Tapping the clock or date opens the clock app, as on most launchers.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: const InstalledAppsService().openClock,
      child: switch (style) {
        ClockStyle.standard => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              subtitle,
              style: TextStyle(fontFamily: 'Roboto', fontSize: 19, fontWeight: FontWeight.w600, color: primary),
            ),
            Text(
              time,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 87,
                height: 1.05,
                fontWeight: FontWeight.w500,
                color: primary,
              ),
            ),
          ],
        ),
        // Hours over minutes, big and light.
        ClockStyle.large => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final part in time.split(':'))
              Text(
                part,
                style: TextStyle(fontSize: 96, height: 1, fontWeight: FontWeight.w200, color: primary),
              ),
            const SizedBox(height: 12),
            date,
          ],
        ),
        // Time and date on one quiet line.
        ClockStyle.compact => Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: time,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: primary),
              ),
              TextSpan(
                text: '   $subtitle',
                style: TextStyle(fontSize: 15, color: secondary),
              ),
            ],
          ),
        ),
      },
    );
  }
}

class _ClassicLayout extends StatelessWidget {
  const _ClassicLayout({
    required this.time,
    required this.subtitle,
    required this.isDark,
    required this.settings,
    required this.dock,
    required this.onOpen,
    required this.onChange,
    this.tourChip,
  });

  final String time;
  final String subtitle;
  final bool isDark;
  final AppSettings settings;
  final List<_DockItem> dock;
  final ValueChanged<int> onOpen;
  final ValueChanged<int> onChange;

  /// "Take a look around", until the tours are done or skipped.
  final Widget? tourChip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final clock = _Clock(time: time, subtitle: subtitle, isDark: isDark, style: settings.clockStyle);
    final iconColor = colors.onSurface;
    // Outlined on the card fill, like the original's pill and dock tiles. On
    // a coloured or gradient wallpaper the card fill would be a solid slab,
    // so the tiles take a translucent wash of the ink instead.
    final plain = settings.wallpaper.band == null && settings.wallpaper.edge == colors.surface;
    BoxDecoration outlined(double radius, double width) => BoxDecoration(
      color: plain ? colors.surfaceContainer : colors.onSurface.withValues(alpha: 0.1),
      border: Border.all(color: plain ? colors.outline : colors.onSurface.withValues(alpha: 0.35), width: width),
      borderRadius: BorderRadius.circular(radius),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
      child: Column(
        children: [
          ...switch (settings.clockPositionFor(HomeLayoutMode.classic)) {
            ClockPosition.top => [clock, const Spacer()],
            ClockPosition.center => [const Spacer(), clock, const Spacer()],
            ClockPosition.bottom => [const Spacer(), clock, const SizedBox(height: 32)],
          },
          if (tourChip case final chip?) ...[chip, const SizedBox(height: 12)],
          if (settings.showSearchBar)
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: outlined(23, 1),
              child: Row(
                children: [
                  Icon(Icons.search, color: iconColor, size: 24),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Text(
                      'Spotlight search',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        color: plain ? colors.onSurfaceVariant : colors.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (settings.showSearchBar) const SizedBox(height: 42),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Tap opens the app (or picks one for an empty slot); long-press
                // swaps it. Default slots keep their line glyph; others show
                // the app's icon.
                for (final (i, item) in dock.indexed)
                  GestureDetector(
                    onTap: () => onOpen(i),
                    onLongPress: () => onChange(i),
                    child: Container(
                      width: 70,
                      height: 70,
                      alignment: Alignment.center,
                      decoration: outlined(12, 1.5),
                      child: switch (item) {
                        (glyph: final glyph?, app: _?) => Icon(glyph, color: iconColor, size: 26),
                        (app: final app?, glyph: _) => AppIcon(icon: app.icon, size: 36),
                        _ => Icon(Icons.add, color: colors.onSurfaceVariant, size: 26),
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MinimalLayout extends StatelessWidget {
  const _MinimalLayout({
    required this.time,
    required this.subtitle,
    required this.isDark,
    required this.settings,
    required this.dock,
    required this.onOpen,
    required this.onChange,
    this.tourChip,
  });

  final String time;
  final String subtitle;
  final bool isDark;
  final AppSettings settings;
  final List<_DockItem> dock;
  final ValueChanged<int> onOpen;
  final ValueChanged<int> onChange;

  /// "Take a look around", until the tours are done or skipped.
  final Widget? tourChip;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final clock = _Clock(time: time, subtitle: subtitle, isDark: isDark, style: settings.clockStyle);
    final apps = [
      for (final (i, item) in dock.indexed)
        GestureDetector(
          onTap: () => onOpen(i),
          onLongPress: () => onChange(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
            child: Text(
              item.app?.name ?? 'Add app',
              style: TextStyle(fontSize: 20, color: item.app == null ? textColor.withValues(alpha: 0.4) : textColor),
            ),
          ),
        ),
      if (tourChip case final chip?) Padding(padding: const EdgeInsets.only(top: 16), child: chip),
    ];
    return Column(
      children: switch (settings.clockPositionFor(HomeLayoutMode.minimal)) {
        ClockPosition.top => [const SizedBox(height: 48), clock, const Spacer(flex: 2), ...apps, const Spacer(flex: 3)],
        ClockPosition.center => [const Spacer(flex: 2), clock, const Spacer(flex: 2), ...apps, const Spacer(flex: 3)],
        ClockPosition.bottom => [
          const Spacer(flex: 2),
          ...apps,
          const Spacer(flex: 2),
          clock,
          const SizedBox(height: 48),
        ],
      },
    );
  }
}
