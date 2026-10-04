import 'package:flutter/material.dart';

import '../services/app_widget_service.dart';

/// What another app's widget looks like (Phase 12 task 6), [height] tall,
/// for the Add New Tile sheet's From Apps rows and Manage tiles. A faint
/// box while it renders, and a widget glyph if the app offers no picture.
class WidgetPreview extends StatelessWidget {
  const WidgetPreview({super.key, required this.provider, required this.height, this.width});

  final String provider;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      width: width,
      child: FutureBuilder(
        future: const AppWidgetService().preview(provider),
        builder: (context, snapshot) {
          final png = snapshot.data;
          if (png != null) {
            return Image.memory(png, fit: BoxFit.contain, gaplessPlayback: true);
          }
          return DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: snapshot.connectionState == ConnectionState.done
                ? Icon(Icons.widgets_outlined, color: colors.onSurfaceVariant)
                : null,
          );
        },
      ),
    );
  }
}
