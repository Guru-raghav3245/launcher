import 'package:flutter/material.dart';

/// Horizontal row of tappable wallpaper swatches, with the selected one
/// outlined — matches the onboarding Customize step's "WALLPAPER" section.
class WallpaperPicker extends StatelessWidget {
  const WallpaperPicker({
    super.key,
    required this.colors,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<Color> colors;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: colors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onSelected(index),
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                color: colors[index],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? ink : ink.withValues(alpha: 0.26),
                  width: selected ? 2 : 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
