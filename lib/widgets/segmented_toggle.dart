import 'package:flutter/material.dart';

/// A pill-shaped 2-segment toggle (Light/Dark, Classic/Minimal, ...),
/// shared by the onboarding Customize step's pickers (tasks 3-4).
class SegmentedToggle<T> extends StatelessWidget {
  const SegmentedToggle({super.key, required this.options, required this.value, required this.onChanged});

  final List<(T value, IconData icon, String label)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Shrinks (never grows) to fit when a large text size or wide font
    // would push it past the edge.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: isDark ? Colors.white24 : Colors.black26),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in options)
              _Segment(
                icon: option.$2,
                label: option.$3,
                selected: option.$1 == value,
                onTap: () => onChanged(option.$1),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Selected = solid ink fill with inverted text; ink is black in light
    // theme and white in dark theme.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : Colors.black;
    final paper = isDark ? Colors.black : Colors.white;
    final color = selected ? paper : (isDark ? Colors.white60 : Colors.black54);
    return Material(
      color: selected ? ink : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
