import 'package:flutter/material.dart';

import '../../models/my_space_tile.dart';
import '../tile_card.dart';

const defaultGlassGoal = 8;
const minGlassGoal = 4;
const maxGlassGoal = 12;

String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// Glasses logged on [now]'s day (a stored count from another day is 0).
int glassesToday(Map<String, dynamic> data, DateTime now) =>
    data['date'] == _dayKey(now) ? data['glasses'] as int? ?? 0 : 0;

int glassGoal(Map<String, dynamic> data) => data['goal'] as int? ?? defaultGlassGoal;

/// [data] with today's count set to [glasses].
Map<String, dynamic> withGlasses(Map<String, dynamic> data, int glasses, DateTime now) => {
  ...data,
  'date': _dayKey(now),
  'glasses': glasses,
};

/// Hydration tile: one drop per glass of the daily goal. Tapping a drop sets
/// today's count to it (tapping the last filled one takes it back), so a
/// mis-tap is easy to undo. The count starts over each day.
class HydrationTile extends StatelessWidget {
  const HydrationTile({super.key, required this.tile, required this.onChanged});

  final MySpaceTile tile;
  final ValueChanged<Map<String, dynamic>> onChanged;

  Future<void> _editGoal(BuildContext context) async {
    var goal = glassGoal(tile.data);
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Daily goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$goal glasses', style: const TextStyle(fontSize: 20)),
              Slider(
                value: goal.toDouble(),
                min: minGlassGoal.toDouble(),
                max: maxGlassGoal.toDouble(),
                divisions: maxGlassGoal - minGlassGoal,
                activeColor: Colors.black,
                inactiveColor: Theme.of(context).colorScheme.outlineVariant,
                onChanged: (v) => setState(() => goal = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(context).pop(goal), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (picked != null) onChanged({...tile.data, 'goal': picked});
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final glasses = glassesToday(tile.data, now);
    final goal = glassGoal(tile.data);
    return TileCard(
      label: 'HYDRATION',
      icon: Icons.water_drop_outlined,
      trailing: TextButton(
        onPressed: () => _editGoal(context),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text('Goal $goal'),
      ),
      child: HydrationBody(
        glasses: glasses,
        goal: goal,
        onTapGlass: (index) => onChanged(withGlasses(tile.data, index + 1 == glasses ? index : index + 1, now)),
      ),
    );
  }
}

/// The drops and the "N of goal" line, shared with the Add New Tile preview.
class HydrationBody extends StatelessWidget {
  const HydrationBody({super.key, required this.glasses, required this.goal, this.onTapGlass});

  final int glasses;
  final int goal;
  final ValueChanged<int>? onTapGlass;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 4,
          children: [
            for (var i = 0; i < goal; i++)
              InkResponse(
                onTap: onTapGlass == null ? null : () => onTapGlass!(i),
                radius: 20,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    i < glasses ? Icons.water_drop : Icons.water_drop_outlined,
                    size: 28,
                    color: i < glasses ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          glasses >= goal ? '$glasses of $goal glasses · goal reached' : '$glasses of $goal glasses today',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
