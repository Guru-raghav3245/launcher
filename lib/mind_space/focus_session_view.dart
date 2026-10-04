import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';

import '../panels/mind_space_panel.dart';
import '../services/focus_mode_service.dart';
import '../services/installed_apps_service.dart';
import '../widgets/launch_app.dart';

const _monthNames = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
const _weekdayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

/// What Home shows instead of the clock while a Focus Mode session runs:
/// the date, a calm illustration, the elapsed time, a start → end bar for
/// timed sessions, and an Apps button for the allowed apps (where the
/// press-and-hold exit lives).
class FocusSessionView extends StatelessWidget {
  const FocusSessionView({super.key, required this.status, required this.now});

  final FocusStatus status;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : Colors.black;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final startedAt = status.startedAt;
    final endsAt = status.endsAt;
    final elapsed = startedAt == null ? null : now.difference(startedAt);
    const label = TextStyle(fontSize: 14, letterSpacing: 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        children: [
          Text(_dateLine(context, now), style: label.copyWith(color: secondary)),
          const Spacer(),
          SizedBox(height: 200, child: _Circles(ink: ink)),
          const SizedBox(height: 24),
          Text('FOCUS SESSION', style: label.copyWith(color: secondary)),
          const Spacer(),
          if (elapsed != null) ...[
            Text('ELAPSED', style: label.copyWith(color: ink)),
            const SizedBox(height: 8),
            Text(_clock(elapsed), style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w600)),
          ],
          if (startedAt != null && endsAt != null) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (now.difference(startedAt).inSeconds / endsAt.difference(startedAt).inSeconds).clamp(0, 1),
              color: ink,
              backgroundColor: ink.withValues(alpha: 0.1),
              minHeight: 2,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(TimeOfDay.fromDateTime(startedAt).format(context), style: TextStyle(color: secondary)),
                const Spacer(),
                Text(
                  formatScreenTime(endsAt.difference(startedAt)),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(TimeOfDay.fromDateTime(endsAt).format(context), style: TextStyle(color: secondary)),
              ],
            ),
          ],
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => _showAllowedApps(context, elapsed, strictUntil: status.strict ? endsAt : null),
            icon: const Icon(Icons.apps, size: 18),
            label: const Text('APPS', style: TextStyle(letterSpacing: 2)),
            style: OutlinedButton.styleFrom(foregroundColor: ink, shape: const StadiumBorder()),
          ),
        ],
      ),
    );
  }
}

String _dateLine(BuildContext context, DateTime now) =>
    '${_monthNames[now.month - 1]} ${now.day} · ${_weekdayNames[now.weekday - 1]} · '
    '${TimeOfDay.fromDateTime(now).format(context).toUpperCase()}';

/// Elapsed time as mm:ss, or h:mm:ss past the first hour.
String _clock(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = two(d.inMinutes.remainder(60));
  final s = two(d.inSeconds.remainder(60));
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

class _Circles extends StatelessWidget {
  const _Circles({required this.ink});

  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        for (final (size, alpha) in [(200.0, 0.04), (160.0, 0.07), (120.0, 0.11)])
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ink.withValues(alpha: alpha),
            ),
          ),
        Icon(Icons.edit_note, size: 72, color: ink.withValues(alpha: 0.8)),
      ],
    );
  }
}

/// Bottom sheet listing the allowed apps (tap to open), plus the exit,
/// which needs a press-and-hold so leaving early is a deliberate choice. A
/// strict session has no exit, just when it ends ([strictUntil]).
Future<void> _showAllowedApps(BuildContext context, Duration? elapsed, {DateTime? strictUntil}) async {
  const focusMode = FocusModeService();
  final (apps, allowed) = await (const InstalledAppsService().loadApps(), focusMode.essentials()).wait;
  if (!context.mounted) return;
  final allowedApps = apps.where((app) => allowed.contains(app.packageName)).toList();
  final exited = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => _AllowedAppsSheet(
      apps: allowedApps,
      strictUntil: strictUntil,
      onOpen: (app) {
        Navigator.of(sheetContext).pop();
        launchApp(context, app);
      },
    ),
  );
  if (exited == true && context.mounted) {
    await focusMode.stop();
    if (context.mounted) await _showSummary(context, elapsed);
  }
}

class _AllowedAppsSheet extends StatelessWidget {
  const _AllowedAppsSheet({required this.apps, required this.onOpen, this.strictUntil});

  final List<AppInfo> apps;
  final DateTime? strictUntil;
  final ValueChanged<AppInfo> onOpen;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : Colors.black;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ALLOWED APPS', style: TextStyle(letterSpacing: 4, color: secondary)),
            const SizedBox(height: 12),
            if (apps.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No allowed apps', style: TextStyle(color: secondary)),
              ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (final app in apps)
                  TextButton(
                    onPressed: () => onOpen(app),
                    style: TextButton.styleFrom(foregroundColor: ink),
                    child: Text(app.name, style: const TextStyle(fontSize: 18)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (strictUntil case final until?)
              Text(
                'Strict session · ends at ${TimeOfDay.fromDateTime(until).format(context)}',
                style: TextStyle(fontSize: 15, color: secondary),
              )
            else ...[
              // A tick as the hold starts, a strong one when it exits (the
              // button's own long-press feedback is off so it isn't doubled).
              Listener(
                onPointerDown: (_) => HapticFeedback.selectionClick(),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    // A tap only explains; holding is what exits.
                    onPressed: () {},
                    onLongPress: () {
                      // The long-press effect: on Android the firmest of
                      // the system haptics (heavyImpact felt like a tick).
                      HapticFeedback.vibrate();
                      Navigator.of(context).pop(true);
                    },
                    style: OutlinedButton.styleFrom(
                      enableFeedback: false,
                      foregroundColor: ink,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Exit focus mode', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text('Press and hold to exit', style: TextStyle(fontSize: 13, color: secondary)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-screen "You focused for …" summary after leaving a session.
Future<void> _showSummary(BuildContext context, Duration? elapsed) {
  final focused = elapsed == null
      ? null
      : elapsed.inMinutes < 1
      ? '<1m'
      : formatScreenTime(elapsed);
  return showGeneralDialog<void>(
    context: context,
    pageBuilder: (context, _, _) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final ink = isDark ? Colors.white : Colors.black;
      final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
      return Material(
        color: isDark ? Colors.black : Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(_dateLine(context, DateTime.now()), style: TextStyle(letterSpacing: 4, color: secondary)),
                const Spacer(),
                SizedBox(height: 200, child: _Circles(ink: ink)),
                const SizedBox(height: 24),
                Text('FOCUS SESSION', style: TextStyle(letterSpacing: 4, color: secondary)),
                const Spacer(),
                if (focused != null) ...[
                  Text('YOU FOCUSED FOR', style: TextStyle(letterSpacing: 4, color: ink)),
                  const SizedBox(height: 8),
                  Text(
                    focused,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w600),
                  ),
                ],
                const Spacer(),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(foregroundColor: ink, shape: const StadiumBorder()),
                  child: const Text('DONE', style: TextStyle(letterSpacing: 2)),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
