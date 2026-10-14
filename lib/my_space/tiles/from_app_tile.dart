import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/my_space_tile.dart';
import '../../services/app_widget_service.dart';
import '../../widgets/skeleton.dart';
import '../tile_card.dart';

const _viewType = 'student.launcher/appwidget_view';

/// Shortest and tallest a widget tile gets, in dp.
const _minHeight = 72.0;
const _maxHeight = 360.0;

/// From-Apps tile: embeds another app's native Android AppWidget via
/// AppWidgetHost (Phase 3 task 7). The widget was already allocated and
/// bound when the tile was created (see `add_tile_sheet.dart`); this just
/// renders it through a platform view. `data` holds the bound widget id
/// (`AppWidgetHostBridge.kt` re-associates it on every app start since
/// AppWidgetHost.startListening() keeps host-side bindings alive) and the
/// provider's label for the tile header. The tile is as tall as the widget's
/// own proportions make it at the tile's width (a wide, short widget stays
/// short), with a stencil until that's known.
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
      child: FutureBuilder<double?>(
        future: const AppWidgetService().aspect(widgetId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Skeleton(child: SkeletonBar(height: 120));
          }
          return LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              height: ((snapshot.data ?? 0.55) * constraints.maxWidth).clamp(_minHeight, _maxHeight),
              child: AndroidView(
                viewType: _viewType,
                creationParams: {'widgetId': widgetId},
                creationParamsCodec: const StandardMessageCodec(),
              ),
            ),
          );
        },
      ),
    );
  }
}
