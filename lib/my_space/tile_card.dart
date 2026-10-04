import 'package:flutter/material.dart';

import '../state/app_settings.dart';
import '../state/app_settings_scope.dart';

/// Shared chrome for a My Space dashboard tile: a bordered card with a
/// small icon+label header above the tile's own content. Used by both the
/// empty-state preview cards and the real tile bodies (tasks 3-6).
class TileCard extends StatelessWidget {
  const TileCard({super.key, required this.label, required this.icon, required this.child, this.trailing});

  final String label;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style = context.dependOnInheritedWidgetOfExactType<AppSettingsScope>()?.notifier?.cardStyle;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: style == CardStyle.borderless ? null : Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: Color.lerp(Theme.of(context).colorScheme.onSurface, Theme.of(context).colorScheme.surface, 0.25),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                // The original's caps label: larger, wider, softer ink.
                style: TextStyle(
                  color: Color.lerp(
                    Theme.of(context).colorScheme.onSurface,
                    Theme.of(context).colorScheme.surface,
                    0.25,
                  ),
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              if (trailing != null) ...[const Spacer(), trailing!],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
