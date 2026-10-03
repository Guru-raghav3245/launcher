import 'package:flutter/material.dart';

import '../services/tour_service.dart';

/// "Take a look around": the four goal tours, after the original. Picking
/// one closes the sheet and starts its hint on Home; Skip tour retires the
/// Home chip (the sheet stays reachable from Settings).
Future<void> showTourPicker(BuildContext context) async {
  final done = await const TourService().done();
  if (!context.mounted) return;
  final tour = await showModalBottomSheet<Tour>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final ink = isDark ? Colors.white : Colors.black;
      final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
      final stroke = Theme.of(context).colorScheme.outline;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Take a look around', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Pick one. You can open this again anytime.', style: TextStyle(color: secondary)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: stroke),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final (i, tour) in Tour.values.indexed) ...[
                      if (i > 0) Divider(height: 1, indent: 20, endIndent: 20, color: stroke),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: ink),
                          ),
                          child: Icon(tour.icon, size: tour == Tour.customizeHome ? 8 : 18, color: ink),
                        ),
                        title: Text(tour.title, style: const TextStyle(fontSize: 17)),
                        subtitle: Text(tour.gesture),
                        trailing: Icon(
                          done.contains(tour) ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: ink,
                          size: 20,
                        ),
                        onTap: () => Navigator.of(context).pop(tour),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    const TourService().skip();
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(foregroundColor: secondary),
                  child: const Text('Skip tour'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (tour != null) TourService.start(tour);
}

/// Home's pill that opens [showTourPicker].
class TourChip extends StatelessWidget {
  const TourChip({super.key, required this.ink});

  final Color ink;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => showTourPicker(context),
      icon: Icon(Icons.contrast, size: 16, color: ink),
      label: Text('Take a look around', style: TextStyle(color: ink, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: ink.withValues(alpha: 0.4)),
        shape: const StadiumBorder(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// The running tour's hint over Home: Home fades, and a gesture marker with
/// its prompt sits in the middle. Everything but Cancel ignores touches, so
/// the real swipe or press goes straight through to the launcher.
class TourOverlay extends StatelessWidget {
  const TourOverlay({super.key, required this.tour, required this.isDark});

  final Tour tour;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ink = isDark ? Colors.white : Colors.black;
    final line = Container(color: ink.withValues(alpha: 0.5), width: 1.5, height: 1.5);
    final marker = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.9),
        border: Border.all(color: ink.withValues(alpha: 0.6)),
      ),
      child: Icon(tour.icon, size: tour == Tour.customizeHome ? 10 : 22, color: ink),
    );
    // The marker and a trail in the direction to move.
    final gesture = switch (tour) {
      Tour.findApps => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          marker,
          SizedBox(height: 90, child: line),
        ],
      ),
      Tour.usePhoneLess => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          marker,
          SizedBox(width: 90, child: line),
        ],
      ),
      Tour.organizeDay => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 90, child: line),
          marker,
        ],
      ),
      Tour.customizeHome => marker,
    };
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    gesture,
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Text(
                        tour.prompt,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, color: ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Center(
            child: TextButton(
              onPressed: TourService.cancel,
              style: TextButton.styleFrom(foregroundColor: ink),
              child: const Text('Cancel'),
            ),
          ),
        ),
      ],
    );
  }
}
