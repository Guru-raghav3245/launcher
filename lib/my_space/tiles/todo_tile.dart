import 'package:flutter/material.dart';

import '../../models/my_space_tile.dart';
import '../tile_card.dart';

/// Most a checklist grows before it scrolls inside its tile.
const _maxListHeight = 220.0;

typedef ChecklistItems = List<Map<String, dynamic>>;

ChecklistItems _itemsOf(Object? raw) => ((raw as List?) ?? const []).cast<Map<String, dynamic>>();

/// Todo tile: a checklist with an inline "add new item" field. Each item is
/// stored as `{"text": String, "done": bool}` in [MySpaceTile.data]['items'].
/// A long list scrolls inside the tile.
class TodoTile extends StatelessWidget {
  const TodoTile({super.key, required this.tile, required this.onChanged});

  final MySpaceTile tile;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  Widget build(BuildContext context) {
    return TileCard(
      label: 'TO-DO',
      icon: Icons.checklist,
      child: Checklist(items: _itemsOf(tile.data['items']), onChanged: (items) => onChanged({'items': items})),
    );
  }
}

/// Todo and Tasks in one tile: swipe sideways between a plain checklist and
/// a list of tasks with due dates. Stored as `items` (the checklist) and
/// `tasks` (`{"text", "done", "due"?: ISO date}`) in [MySpaceTile.data].
class TodoTasksTile extends StatefulWidget {
  const TodoTasksTile({super.key, required this.tile, required this.onChanged});

  final MySpaceTile tile;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  State<TodoTasksTile> createState() => _TodoTasksTileState();
}

class _TodoTasksTileState extends State<TodoTasksTile> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final data = widget.tile.data;
    final colors = Theme.of(context).colorScheme;
    return TileCard(
      label: _page == 0 ? 'TO-DO' : 'TASKS',
      icon: _page == 0 ? Icons.checklist : Icons.event_available_outlined,
      trailing: Row(
        children: [
          for (var i = 0; i < 2; i++)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(left: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == _page ? colors.onSurface : colors.outlineVariant,
              ),
            ),
        ],
      ),
      // Tall enough for the longer page's rows and the add field, up to the cap.
      child: SizedBox(
        height: ((_itemsOf(data['items']).length > _itemsOf(data['tasks']).length
                        ? _itemsOf(data['items']).length
                        : _itemsOf(data['tasks']).length) *
                    31.0 +
                52)
            .clamp(96.0, 250.0),
        child: PageView(
          onPageChanged: (page) => setState(() => _page = page),
          children: [
            Checklist(
              items: _itemsOf(data['items']),
              expanded: true,
              onChanged: (items) => widget.onChanged({...data, 'items': items}),
            ),
            Checklist(
              items: _itemsOf(data['tasks']),
              expanded: true,
              withDueDates: true,
              onChanged: (tasks) => widget.onChanged({...data, 'tasks': tasks}),
            ),
          ],
        ),
      ),
    );
  }
}

/// A scrolling checklist with an add field underneath. [expanded] fills the
/// space it's given instead of sizing to its items; [withDueDates] lets each
/// item carry a due date and sorts the open ones by it.
class Checklist extends StatefulWidget {
  const Checklist({
    super.key,
    required this.items,
    required this.onChanged,
    this.expanded = false,
    this.withDueDates = false,
  });

  final ChecklistItems items;
  final ValueChanged<ChecklistItems> onChanged;
  final bool expanded;
  final bool withDueDates;

  @override
  State<Checklist> createState() => _ChecklistState();
}

class _ChecklistState extends State<Checklist> {
  final _newItemController = TextEditingController();
  DateTime? _due;

  void _toggle(Map<String, dynamic> item) {
    final items = [for (final i in widget.items) identical(i, item) ? {...i, 'done': !(i['done'] as bool)} : i];
    widget.onChanged(items);
  }

  void _addItem(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    widget.onChanged([
      ...widget.items,
      {'text': trimmed, 'done': false, if (_due != null) 'due': _dateOnly(_due!).toIso8601String()},
    ]);
    _newItemController.clear();
    setState(() => _due = null);
  }

  Future<void> _pickDue() async {
    final today = _dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _due = picked);
  }

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = widget.withDueDates ? _byDue(widget.items) : widget.items;
    final today = _dateOnly(DateTime.now());
    final rows = [
      for (final item in items)
        _TodoRow(
          text: item['text'] as String,
          done: item['done'] as bool,
          due: item['due'] == null ? null : DateTime.parse(item['due'] as String),
          today: today,
          onTap: () => _toggle(item),
        ),
    ];
    final list = widget.expanded
        ? Expanded(child: ListView(padding: EdgeInsets.zero, children: rows))
        : ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _maxListHeight),
            child: ListView(padding: EdgeInsets.zero, shrinkWrap: true, children: rows),
          );
    return Column(
      mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        list,
        Row(
          children: [
            Icon(Icons.add_circle_outline, size: 18, color: colors.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _newItemController,
                decoration: InputDecoration(
                  hintText: widget.withDueDates ? 'Add new task' : 'Add new item',
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: _addItem,
              ),
            ),
            if (widget.withDueDates)
              TextButton.icon(
                onPressed: _pickDue,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: _due == null ? colors.onSurfaceVariant : colors.onSurface,
                ),
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(_due == null ? 'Due' : _dueLabel(_due!, today)),
              ),
          ],
        ),
      ],
    );
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Open items first, soonest due first (undated last); finished ones sink.
ChecklistItems _byDue(ChecklistItems items) {
  DateTime? due(Map<String, dynamic> i) => i['due'] == null ? null : DateTime.parse(i['due'] as String);
  int rank(Map<String, dynamic> i) => i['done'] == true ? 1 : 0;
  final sorted = [...items];
  sorted.sort((a, b) {
    if (rank(a) != rank(b)) return rank(a) - rank(b);
    final da = due(a), db = due(b);
    if (da == null || db == null) return da == db ? 0 : (da == null ? 1 : -1);
    return da.compareTo(db);
  });
  return sorted;
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _dueLabel(DateTime due, DateTime today) {
  final days = due.difference(today).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  return '${_weekdays[due.weekday - 1]}, ${_months[due.month - 1]} ${due.day}';
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({required this.text, required this.done, required this.onTap, this.due, required this.today});

  final String text;
  final bool done;
  final VoidCallback onTap;
  final DateTime? due;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final overdue = due != null && !done && due!.isBefore(today);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(done ? Icons.check_box : Icons.check_box_outline_blank, size: 20, color: colors.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? colors.onSurfaceVariant : colors.onSurface,
                ),
              ),
            ),
            if (due != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  overdue ? 'Overdue · ${_dueLabel(due!, today)}' : _dueLabel(due!, today),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: overdue ? FontWeight.bold : null,
                    color: overdue ? colors.onSurface : colors.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
