import 'package:flutter/material.dart';

/// Stencil placeholders shown while content loads, in place of spinners.
/// Everything inside a [Skeleton] pulses together.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child});

  final Widget child;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(
      begin: 0.45,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
    child: widget.child,
  );
}

/// One stencil shape: a rounded bar, or a circle when [circle] is set.
class SkeletonBar extends StatelessWidget {
  const SkeletonBar({
    super.key,
    this.width,
    this.height = 12,
    this.circle = false,
  });

  final double? width;
  final double height;
  final bool circle;

  @override
  Widget build(BuildContext context) => Container(
    width: circle ? height : width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(circle ? height : 6),
    ),
  );
}

/// A few text-like lines, for the inside of a tile.
class SkeletonLines extends StatelessWidget {
  const SkeletonLines({super.key, this.lines = 3});

  final int lines;

  @override
  Widget build(BuildContext context) => Skeleton(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          // Last line shorter, like a paragraph.
          FractionallySizedBox(
            widthFactor: i == lines - 1 ? 0.55 : 1,
            child: const SkeletonBar(),
          ),
        ],
      ],
    ),
  );
}

/// Rows of icon + name, for the app drawer and app pickers.
class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({super.key, this.rows = 9});

  final int rows;

  @override
  Widget build(BuildContext context) => Skeleton(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const SkeletonBar(height: 34, circle: true),
                const SizedBox(width: 16),
                SkeletonBar(width: 90.0 + (i * 37) % 90, height: 14),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Outlined cards with stencil lines, for My Space.
class TileListSkeleton extends StatelessWidget {
  const TileListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Skeleton(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBar(width: 70, height: 10),
                  const SizedBox(height: 16),
                  const SkeletonBar(height: 14),
                  const SizedBox(height: 10),
                  SkeletonBar(width: 120.0 + i * 30, height: 14),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The shape of a Mind Space day: title, big number, then rows with bars.
class DaySkeleton extends StatelessWidget {
  const DaySkeleton({super.key});

  @override
  Widget build(BuildContext context) => Skeleton(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(25, 24, 25, 24),
      children: [
        const SkeletonBar(width: 110, height: 14),
        const SizedBox(height: 28),
        const SkeletonBar(width: 200, height: 56),
        const SizedBox(height: 14),
        const SkeletonBar(width: 140, height: 14),
        const SizedBox(height: 36),
        for (var i = 0; i < 3; i++) ...[
          const SkeletonBar(width: 160, height: 14),
          const SizedBox(height: 8),
          SkeletonBar(height: 4, width: 280.0 - i * 70),
          const SizedBox(height: 22),
        ],
      ],
    ),
  );
}
