import 'package:flutter/material.dart';

/// Renders [child] inside a small phone-frame outline, at a fixed design
/// size so it looks the same regardless of the host device — used to
/// live-preview the real Home screen during onboarding (tasks 2-5).
class PhoneMockup extends StatelessWidget {
  const PhoneMockup({super.key, required this.child, this.width = 220});

  final Widget child;
  final double width;

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
        border: Border.all(color: Colors.black54, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _designSize.width,
            height: _designSize.height,
            // A fixed MediaQuery so the real Home chrome (SafeArea, text
            // sizes) lays out consistently at this design size instead of
            // the host device's actual (much larger) screen size.
            child: MediaQuery(
              data: const MediaQueryData(size: _designSize),
              // A preview only: the real Home inside must not take taps.
              child: IgnorePointer(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
