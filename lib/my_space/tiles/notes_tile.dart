import 'package:flutter/material.dart';

import '../../models/my_space_tile.dart';
import '../tile_card.dart';

/// Notes tile: freeform text, persisted via [onChanged] on every edit.
class NotesTile extends StatefulWidget {
  const NotesTile({super.key, required this.tile, required this.onChanged});

  final MySpaceTile tile;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  State<NotesTile> createState() => _NotesTileState();
}

class _NotesTileState extends State<NotesTile> {
  late final _controller = TextEditingController(text: widget.tile.data['text'] as String? ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TileCard(
      label: 'NOTES',
      icon: Icons.notes,
      child: TextField(
        controller: _controller,
        maxLines: null,
        minLines: 2,
        decoration: const InputDecoration(
          hintText: 'Jot quick thoughts',
          border: InputBorder.none,
          isDense: true,
        ),
        onChanged: (text) => widget.onChanged({'text': text}),
      ),
    );
  }
}
