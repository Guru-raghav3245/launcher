import 'package:flutter/material.dart';

import '../../services/system_stats_service.dart';
import '../on_screen.dart';
import '../tile_card.dart';

/// My Space's RAM & Storage tile (Phase 12 task 5): memory in use and
/// storage used, refreshed every 2 s while My Space is on screen.
class SystemTile extends StatefulWidget {
  const SystemTile({super.key});

  @override
  State<SystemTile> createState() => _SystemTileState();
}

class _SystemTileState extends State<SystemTile> with PollsWhileOnScreen {
  final _service = const SystemStatsService();
  SystemStats? _stats;

  @override
  Duration get pollInterval => const Duration(seconds: 2);

  @override
  Future<void> poll() async {
    try {
      final stats = await _service.read();
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      stopPolling(); // No platform channel (tests).
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return TileCard(
      label: 'RAM & STORAGE',
      icon: Icons.memory,
      child: stats == null ? const SizedBox(height: 96) : SystemBody(stats: stats),
    );
  }
}

/// The tile's content, shared with the Add New Tile preview.
class SystemBody extends StatelessWidget {
  const SystemBody({super.key, required this.stats});

  final SystemStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Meter(
          label: 'Memory',
          value: '${formatGigabytes(stats.ramUsed)} of ${formatGigabytes(stats.ramTotal)}',
          fraction: stats.ramFraction,
          note: stats.lowMemory ? 'Low on memory · Android is closing background apps' : null,
        ),
        const SizedBox(height: 16),
        _Meter(
          label: 'Storage',
          value: '${formatGigabytes(stats.storageFree)} free of ${formatGigabytes(stats.storageTotal)}',
          fraction: stats.storageFraction,
        ),
      ],
    );
  }
}

/// A label, its percentage, a reading, and a thin bar, in grayscale.
class _Meter extends StatelessWidget {
  const _Meter({required this.label, required this.value, required this.fraction, this.note});

  final String label;
  final String value;
  final double fraction;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final secondary = TextStyle(color: colors.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('${(fraction * 100).round()}%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 16)),
            const Spacer(),
            Text(value, style: secondary),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: fraction.clamp(0, 1),
            minHeight: 4,
            color: colors.onSurface,
            backgroundColor: colors.outlineVariant,
          ),
        ),
        if (note != null) ...[const SizedBox(height: 6), Text(note!, style: secondary.copyWith(fontSize: 13))],
      ],
    );
  }
}
