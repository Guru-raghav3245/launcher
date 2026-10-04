import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../panels/mind_space_panel.dart';
import '../services/focus_schedule_service.dart';

const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S']; // DateTime.monday (1) … sunday (7)

/// "Weekdays · 9:00 AM · 1h", for a schedule's list row.
String _summary(BuildContext context, FocusSchedule s) {
  final days = switch (s.days) {
    final d when d.length == 7 => 'Every day',
    final d when d.length == 5 && d.every((day) => day <= 5) => 'Weekdays',
    final d when d.length == 2 && d.containsAll([6, 7]) => 'Weekends',
    final d => (d.toList()..sort()).map((day) => MaterialLocalizations.of(context).narrowWeekdays[day % 7]).join(' '),
  };
  final time = TimeOfDay(hour: s.hour, minute: s.minute).format(context);
  return '$days · $time · ${formatScreenTime(Duration(minutes: s.durationMinutes))}${s.strict ? ' · strict' : ''}';
}

/// Focus schedules: weekly reminders to start Focus Mode, each with an
/// on/off switch, plus "New schedule".
class FocusSchedulesPage extends StatefulWidget {
  const FocusSchedulesPage({super.key});

  @override
  State<FocusSchedulesPage> createState() => _FocusSchedulesPageState();
}

class _FocusSchedulesPageState extends State<FocusSchedulesPage> {
  final _service = const FocusScheduleService();
  // The exact-alarm grant happens on a system screen; coming back from it,
  // re-schedule so the reminders pick it up.
  late final _lifecycle = AppLifecycleListener(onResume: _service.refreshReminders);
  List<FocusSchedule>? _schedules;

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final schedules = await _service.schedules();
    if (mounted) setState(() => _schedules = schedules);
  }

  Future<void> _edit([FocusSchedule? schedule]) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FocusScheduleEditor(schedule: schedule)));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : Colors.black;
    final stroke = Theme.of(context).colorScheme.outline;
    return Scaffold(
      appBar: AppBar(title: const Text('Focus schedules')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          for (final schedule in _schedules ?? const <FocusSchedule>[])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: stroke),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.only(left: 20, right: 8, top: 6, bottom: 6),
                  title: Text(schedule.name, style: const TextStyle(fontSize: 18)),
                  subtitle: Text(_summary(context, schedule)),
                  trailing: Switch(
                    value: schedule.enabled,
                    activeThumbColor: isDark ? Colors.black : Colors.white,
                    activeTrackColor: ink,
                    onChanged: (enabled) async {
                      HapticFeedback.selectionClick();
                      await _service.save(schedule.copyWith(enabled: enabled));
                      await _refresh();
                    },
                  ),
                  onTap: () => _edit(schedule),
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _edit,
            icon: const Icon(Icons.add),
            label: const Text('New schedule'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ink,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Create or edit a schedule: name, days, start time, length, strict mode.
class FocusScheduleEditor extends StatefulWidget {
  const FocusScheduleEditor({super.key, this.schedule});

  /// Null for a new schedule.
  final FocusSchedule? schedule;

  @override
  State<FocusScheduleEditor> createState() => _FocusScheduleEditorState();
}

class _FocusScheduleEditorState extends State<FocusScheduleEditor> {
  final _service = const FocusScheduleService();
  late final _name = TextEditingController(text: widget.schedule?.name ?? '');
  late final Set<int> _days = {...(widget.schedule?.days ?? {1, 2, 3, 4, 5})};
  late var _time = TimeOfDay(hour: widget.schedule?.hour ?? 9, minute: widget.schedule?.minute ?? 0);
  late int _durationMinutes = widget.schedule?.durationMinutes ?? 60;
  late bool _strict = widget.schedule?.strict ?? false;

  bool get _canSave => _name.text.trim().isNotEmpty && _days.isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  // Permissions first: saving schedules the reminders, and whether they're
  // exact depends on the exact-alarm grant at that moment.
  Future<void> _save() async {
    await _service.requestPermissions();
    await _service.save(
      FocusSchedule(
        id: widget.schedule?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        days: _days,
        hour: _time.hour,
        minute: _time.minute,
        durationMinutes: _durationMinutes,
        strict: _strict,
        enabled: widget.schedule?.enabled ?? true,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : Colors.black;
    final paper = isDark ? Colors.black : Colors.white;
    final schedule = widget.schedule;
    return Scaffold(
      appBar: AppBar(
        title: Text(schedule == null ? 'New schedule' : 'Edit schedule'),
        actions: [
          if (schedule != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await _service.delete(schedule.id);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Deep work, Wind down'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          const Text('Days', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var day = 1; day <= 7; day++)
                GestureDetector(
                  onTap: () => setState(() => _days.contains(day) ? _days.remove(day) : _days.add(day)),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _days.contains(day) ? ink : null,
                      border: Border.all(color: ink.withValues(alpha: 0.3)),
                    ),
                    child: Text(_dayLetters[day - 1], style: TextStyle(color: _days.contains(day) ? paper : ink)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('Starts at'),
            trailing: Text(_time.format(context), style: const TextStyle(fontSize: 18)),
            onTap: () async {
              final picked = await showTimePicker(context: context, initialTime: _time);
              if (picked != null) setState(() => _time = picked);
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Length · ${formatScreenTime(Duration(minutes: _durationMinutes))}',
            style: const TextStyle(fontSize: 18),
          ),
          Slider(
            value: _durationMinutes.toDouble(),
            min: 15,
            max: 240,
            divisions: 15,
            activeColor: ink,
            inactiveColor: ink.withValues(alpha: 0.12),
            onChanged: (value) => setState(() => _durationMinutes = value.round()),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.lock_outline),
            title: const Text('Strict mode'),
            subtitle: const Text('No way to end the session early'),
            value: _strict,
            activeThumbColor: paper,
            activeTrackColor: ink,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _strict = value);
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _canSave ? _save : null,
            style: FilledButton.styleFrom(
              backgroundColor: ink,
              foregroundColor: paper,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
