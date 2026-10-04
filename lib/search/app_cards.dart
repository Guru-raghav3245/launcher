import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import 'app_result_row.dart';

/// App cards four to a row in an outlined box (the original's Spotlight
/// style): the search + apps screen's recent apps before anything is typed.
/// [highlightFirst] rings the first card in ink, as the one Enter opens.
class AppCards extends StatelessWidget {
  const AppCards({super.key, required this.apps, required this.onOpen, this.highlightFirst = false});

  final List<AppInfo> apps;
  final ValueChanged<AppInfo> onOpen;
  final bool highlightFirst;

  static const _perRow = 4;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget card(int i) {
      final app = apps[i];
      return Material(
        color: colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: highlightFirst && i == 0 ? BorderSide(color: colors.onSurface, width: 1.5) : BorderSide.none,
        ),
        child: InkWell(
          onTap: () => onOpen(app),
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: SizedBox(
            height: 88,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(icon: app.icon, size: 34),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    app.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var start = 0; start < apps.length; start += _perRow)
            Padding(
              padding: EdgeInsets.only(top: start == 0 ? 0 : 8),
              child: Row(
                children: [
                  for (var i = start; i < start + _perRow; i++) ...[
                    if (i > start) const SizedBox(width: 8),
                    Expanded(child: i < apps.length ? card(i) : const SizedBox.shrink()),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
