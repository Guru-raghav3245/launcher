import 'package:flutter/material.dart';

/// Renders [child] inside a small phone-frame outline, at a fixed design
/// size so it looks the same regardless of the host device — used to
/// live-preview the real Home screen during onboarding (tasks 2-5).
class PhoneMockup extends StatelessWidget {
  const PhoneMockup({super.key, required this.child, this.width = 220, this.frameColor = Colors.black54});

  final Widget child;
  final double width;
  final Color frameColor;

  static const _designSize = Size(390, 844);

  @override
  Widget build(BuildContext context) {
    final height = width * _designSize.height / _designSize.width;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: frameColor, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _designSize.width,
            height: _designSize.height,
            // A fixed size and no insets, so the real Home chrome lays out
            // consistently at this design size instead of the host device's
            // (much larger) screen; the text scale and time format carry over.
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: _designSize,
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
                viewInsets: EdgeInsets.zero,
              ),
              // A preview only: the real Home inside must not take taps.
              child: IgnorePointer(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
