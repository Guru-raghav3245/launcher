import 'package:flutter/material.dart';

import '../panels/mind_space_panel.dart';
import '../search/app_multi_picker_sheet.dart';
import '../services/mindful_timer_service.dart';

const _cooldownChoices = [0, 5, 15, 30, 60];

/// Create or edit a Mindful Timer group: name, apps, daily limit, cooldown.
/// Saving asks for the overlay permission the "Time's up" screen needs.
class TimerGroupEditor extends StatefulWidget {
  const TimerGroupEditor({super.key, this.group});

  /// Null for a new group.
  final TimerGroup? group;

  @override
  State<TimerGroupEditor> createState() => _TimerGroupEditorState();
}

class _TimerGroupEditorState extends State<TimerGroupEditor> {
  final _timer = const MindfulTimerService();
  late final _name = TextEditingController(text: widget.group?.name ?? '');
  late final Set<String> _packages = {...?widget.group?.packages};
  late int _dailyMinutes = widget.group?.dailyMinutes ?? 30;
  late int _cooldownMinutes = widget.group?.cooldownMinutes ?? 0;

  bool get _canSave => _name.text.trim().isNotEmpty && _packages.isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await _timer.saveGroup(
      TimerGroup(
        id: widget.group?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        packages: _packages,
        dailyMinutes: _dailyMinutes,
        cooldownMinutes: _cooldownMinutes,
      ),
    );
    if (!mounted) return;
    if (!await _timer.canDrawOverlays() && mounted) {
      final allow = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Overlay permission required'),
          content: const Text(
            "Mindful Timer needs to display over other apps to show the Time's up screen when a session ends.",
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Not now')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Allow')),
          ],
        ),
      );
      if (allow == true) await _timer.requestOverlay();
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : Colors.black;
    final group = widget.group;
    return Scaffold(
      appBar: AppBar(
        title: Text(group == null ? 'New timer' : 'Edit timer'),
        actions: [
          if (group != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await _timer.deleteGroup(group.id);
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
            decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Social, Browsing'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.apps),
            title: const Text('Apps'),
            subtitle: Text(_packages.isEmpty ? 'None yet' : '${_packages.length} selected'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await showAppMultiPicker(
                context,
                title: 'Timed apps',
                subtitle: 'These share one daily limit.',
                load: () async => {..._packages},
                onChanged: (packageName, selected) async =>
                    selected ? _packages.add(packageName) : _packages.remove(packageName),
              );
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Daily limit · ${formatScreenTime(Duration(minutes: _dailyMinutes))}',
            style: const TextStyle(fontSize: 18),
          ),
          Slider(
            value: _dailyMinutes.toDouble(),
            min: 5,
            max: 240,
            divisions: 47,
            activeColor: ink,
            inactiveColor: ink.withValues(alpha: 0.12),
            onChanged: (value) => setState(() => _dailyMinutes = value.round()),
          ),
          const SizedBox(height: 8),
          const Text('Cooldown between sessions', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final minutes in _cooldownChoices)
                ChoiceChip(
                  label: Text(minutes == 0 ? 'Off' : '$minutes min'),
                  selected: _cooldownMinutes == minutes,
                  showCheckmark: false,
                  selectedColor: ink,
                  labelStyle: TextStyle(
                    color: _cooldownMinutes == minutes ? (isDark ? Colors.black : Colors.white) : ink,
                  ),
                  onSelected: (_) => setState(() => _cooldownMinutes = minutes),
                ),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _canSave ? _save : null,
            style: FilledButton.styleFrom(
              backgroundColor: ink,
              foregroundColor: isDark ? Colors.black : Colors.white,
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
