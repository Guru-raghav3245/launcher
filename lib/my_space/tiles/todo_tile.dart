import 'package:flutter/material.dart';

import '../../models/my_space_tile.dart';
import '../tile_card.dart';

/// Todo tile: a checklist with an inline "add new item" field. Each item is
/// stored as `{"text": String, "done": bool}` in [MySpaceTile.data]['items'].
class TodoTile extends StatefulWidget {
  const TodoTile({super.key, required this.tile, required this.onChanged});

  final MySpaceTile tile;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  State<TodoTile> createState() => _TodoTileState();
}

class _TodoTileState extends State<TodoTile> {
  final _newItemController = TextEditingController();

  List<Map<String, dynamic>> get _items =>
      (widget.tile.data['items'] as List).cast<Map<String, dynamic>>();

  void _setItems(List<Map<String, dynamic>> items) => widget.onChanged({'items': items});

  void _toggle(int index) {
    final items = [..._items];
    items[index] = {...items[index], 'done': !(items[index]['done'] as bool)};
    _setItems(items);
  }

  void _addItem(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _setItems([..._items, {'text': trimmed, 'done': false}]);
    _newItemController.clear();
  }

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return TileCard(
      label: 'TO-DO',
      icon: Icons.checklist,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++)
            _TodoRow(
              text: items[i]['text'] as String,
              done: items[i]['done'] as bool,
              onTap: () => _toggle(i),
            ),
          Row(
            children: [
              const Icon(Icons.add_circle_outline, size: 18, color: Colors.black45),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _newItemController,
                  decoration: const InputDecoration(
                    hintText: 'Add new item',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: _addItem,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({required this.text, required this.done, required this.onTap});

  final String text;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
              color: done ? Colors.black45 : Colors.black54,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? Colors.black38 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
