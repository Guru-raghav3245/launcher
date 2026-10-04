import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/my_space_tile.dart';
import '../tile_card.dart';

const _viewType = 'student.launcher/appwidget_view';

/// From-Apps tile: embeds another app's native Android AppWidget via
/// AppWidgetHost (Phase 3 task 7). The widget was already allocated and
/// bound when the tile was created (see `add_tile_sheet.dart`); this just
/// renders it through a platform view. `data` holds the bound widget id
/// (`AppWidgetHostBridge.kt` re-associates it on every app start since
/// AppWidgetHost.startListening() keeps host-side bindings alive) and the
/// provider's label for the tile header.
class FromAppTile extends StatelessWidget {
  const FromAppTile({super.key, required this.tile});

  final MySpaceTile tile;

  @override
  Widget build(BuildContext context) {
    final widgetId = tile.data['widgetId'] as int;
    final label = (tile.data['label'] as String?) ?? 'Widget';
    return TileCard(
      label: label.toUpperCase(),
      icon: Icons.widgets_outlined,
      child: SizedBox(
        height: 180,
        child: AndroidView(
          viewType: _viewType,
          creationParams: {'widgetId': widgetId},
          creationParamsCodec: const StandardMessageCodec(),
        ),
      ),
    );
  }
}
