import 'package:flutter/material.dart';

import '../panels/mind_space_panel.dart';
import '../search/app_multi_picker_sheet.dart';
import '../services/focus_mode_service.dart';

/// Focus Mode's start sheet: a ruler-style duration picker (15 min to 4 h in
/// 15-minute steps) showing when the session would end, a link to the
/// allowed apps, a strict-mode switch, and Start. Resolves to the chosen
/// duration and strictness, or null if dismissed.
Future<({Duration duration, bool strict})?> showFocusDurationSheet(BuildContext context) {
  return showModalBottomSheet<({Duration duration, bool strict})>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => const _FocusDurationSheet(),
  );
}

const _stepMinutes = 15;
const _steps = 16; // 15 min … 4 h
const _initialStep = 1; // 30 min

class _FocusDurationSheet extends StatefulWidget {
  const _FocusDurationSheet();

  @override
  State<_FocusDurationSheet> createState() => _FocusDurationSheetState();
}

class _FocusDurationSheetState extends State<_FocusDurationSheet> {
  final _ruler = FixedExtentScrollController(initialItem: _initialStep);
  var _step = _initialStep;
  var _strict = false;

  Duration get _duration => Duration(minutes: (_step + 1) * _stepMinutes);

  @override
  void dispose() {
    _ruler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : Colors.black;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final endsAt = TimeOfDay.fromDateTime(DateTime.now().add(_duration)).format(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.center_focus_strong, size: 32),
            const SizedBox(height: 8),
            const Text('Focus Mode', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Stay focused for a set time', style: TextStyle(color: secondary)),
            const SizedBox(height: 20),
            Text(formatScreenTime(_duration), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w500)),
            Text('ends $endsAt', style: TextStyle(color: secondary)),
            const SizedBox(height: 12),
            SizedBox(
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // A vertical wheel turned on its side gives a horizontal,
                  // snapping ruler; the large diameter keeps it flat.
                  RotatedBox(
                    quarterTurns: 3,
                    child: ListWheelScrollView(
                      controller: _ruler,
                      itemExtent: 64,
                      diameterRatio: 100,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (step) => setState(() => _step = step),
                      children: [
                        for (var i = 0; i < _steps; i++)
                          RotatedBox(
                            quarterTurns: 1,
                            child: _Tick(minutes: (i + 1) * _stepMinutes, selected: i == _step, ink: ink),
                          ),
                      ],
                    ),
                  ),
                  IgnorePointer(child: Container(width: 2, height: 72, color: ink)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.apps),
              title: const Text('Allowed apps'),
              subtitle: const Text('Apps you can still use during the session'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                const focusMode = FocusModeService();
                showAppMultiPicker(
                  context,
                  title: 'Allowed apps',
                  subtitle: 'These still open while Focus Mode is on.',
                  load: focusMode.essentials,
                  onChanged: focusMode.setEssential,
                );
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.lock_outline),
              title: const Text('Strict mode'),
              subtitle: const Text("No way to end the session early"),
              value: _strict,
              activeThumbColor: isDark ? Colors.black : Colors.white,
              activeTrackColor: ink,
              onChanged: (value) => setState(() => _strict = value),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop((duration: _duration, strict: _strict)),
                style: FilledButton.styleFrom(
                  backgroundColor: ink,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Start', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One ruler step: a tick, taller and labelled on the hour and half hour.
class _Tick extends StatelessWidget {
  const _Tick({required this.minutes, required this.selected, required this.ink});

  final int minutes;
  final bool selected;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final major = minutes % 30 == 0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 2, height: major ? 28 : 16, color: ink.withValues(alpha: selected ? 1 : 0.3)),
        const SizedBox(height: 6),
        Text(
          major ? _rulerLabel(minutes) : '',
          style: TextStyle(fontSize: 12, color: ink.withValues(alpha: selected ? 1 : 0.5)),
        ),
      ],
    );
  }
}

/// "30m", "1h", "1h 30m": like formatScreenTime, minus the "0m" on the hour.
String _rulerLabel(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
