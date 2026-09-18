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
  });

  final TextEditingController controller;
  final AppSortMode sortMode;
  final ValueChanged<AppSortMode> onSortModeChanged;
  final String hintText;
  final bool autofocus;
  final bool showSortControl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.black54, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (controller.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.close, color: Colors.black54, size: 20),
                onPressed: controller.clear,
              );
            },
          ),
          if (showSortControl)
            PopupMenuButton<AppSortMode>(
              icon: const Icon(Icons.tune, color: Colors.black54, size: 20),
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
        ],
      ),
    );
  }
}
