import 'package:flutter/material.dart';

import 'app_search.dart';

/// Search field + sort control, shared by the App Drawer (task 7) and
/// Spotlight Search (task 8).
class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    required this.controller,
    required this.sortMode,
    required this.onSortModeChanged,
    this.hintText = 'Search',
    this.autofocus = false,
    this.showSortControl = true,
    this.focusNode,
    this.onClose,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final AppSortMode sortMode;
  final ValueChanged<AppSortMode> onSortModeChanged;
  final String hintText;
  final bool autofocus;
  final bool showSortControl;
  final FocusNode? focusNode;

  /// Shows a ✕ that clears the query, or calls this when it's empty (the
  /// drawer's way back Home, as in the original).
  final VoidCallback? onClose;

  /// Enter on the keyboard (Spotlight opens its first result).
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final iconColor = colors.onSurfaceVariant;
    // Outlined, like the original's search bars.
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: colors.onSurface, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: onSubmitted,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(fontSize: 18, color: iconColor),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (showSortControl)
            PopupMenuButton<AppSortMode>(
              icon: Icon(Icons.tune, color: iconColor, size: 24),
              initialValue: sortMode,
              onSelected: onSortModeChanged,
              itemBuilder: (context) => const [
                PopupMenuItem(value: AppSortMode.alphabetical, child: Text('A-Z')),
                PopupMenuItem(
                  value: AppSortMode.recentlyInstalled,
                  child: Text('Recently installed'),
                ),
              ],
            ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (controller.text.isEmpty && onClose == null) return const SizedBox.shrink();
              return IconButton(
                icon: Icon(Icons.close, color: colors.onSurface, size: 24),
                onPressed: controller.text.isEmpty ? onClose : controller.clear,
              );
            },
          ),
        ],
      ),
    );
  }
}
