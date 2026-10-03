import 'package:flutter/painting.dart';

/// A Home wallpaper: a flat colour (Classic) or a soft gradient, an [edge]
/// colour with a lighter (or, on pale ones, deeper) [band] across the middle.
/// Colours are sampled from the original launcher's Classic and Gradient
/// collections.
class Wallpaper {
  const Wallpaper(this.id, this.edge, [this.band]);

  final String id;
  final Color edge;
  final Color? band;

  /// Whether Home should draw white text and icons on it.
  bool get isDark => edge.computeLuminance() < 0.4;

  Gradient get gradient => switch (band) {
    final band? => LinearGradient(
      begin: const Alignment(-0.6, -1),
      end: const Alignment(0.6, 1),
      colors: [edge, band, edge],
      stops: const [0.1, 0.55, 1],
    ),
    // Classic: a near-flat diagonal, as before.
    null => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        edge,
        Color.lerp(edge, isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000), isDark ? 0.04 : 0.06)!,
      ],
    ),
  };
}

/// Classic flats for the light theme (the original five; `light-0` is the
/// default).
const classicLight = [
  Wallpaper('light-0', Color(0xFFF3F1F6)),
  Wallpaper('light-1', Color(0xFFDCDEE3)),
  Wallpaper('light-2', Color(0xFFAEB8CB)),
  Wallpaper('light-3', Color(0xFFC9BFE3)),
  Wallpaper('light-4', Color(0xFFE7E2D8)),
];

/// Classic flats for the dark theme (`dark-0`, black, is the default).
const classicDark = [
  Wallpaper('dark-0', Color(0xFF000000)),
  Wallpaper('dark-1', Color(0xFF222222)),
  Wallpaper('dark-2', Color(0xFF22253A)),
  Wallpaper('dark-3', Color(0xFF161D22)),
  Wallpaper('dark-4', Color(0xFF1A1622)),
];

/// The Gradient collection, offered in both themes: twelve deep, four pale.
const gradients = [
  Wallpaper('gradient-ocean', Color(0xFF1B254E), Color(0xFF23567E)),
  Wallpaper('gradient-plum', Color(0xFF2E202E), Color(0xFF643D67)),
  Wallpaper('gradient-dusk', Color(0xFF20202E), Color(0xFF3F3D67)),
  Wallpaper('gradient-violet', Color(0xFF311B4E), Color(0xFF54237E)),
  Wallpaper('gradient-magenta', Color(0xFF73134A), Color(0xFF922968)),
  Wallpaper('gradient-teal', Color(0xFF1B4E48), Color(0xFF237E6E)),
  Wallpaper('gradient-ember', Color(0xFF4E1B1B), Color(0xFF7E2323)),
  Wallpaper('gradient-lavender', Color(0xFF2F2D44), Color(0xFF675E7A)),
  Wallpaper('gradient-sea', Color(0xFF202E2E), Color(0xFF3D6767)),
  Wallpaper('gradient-rose', Color(0xFF442D2D), Color(0xFF7A5E5E)),
  Wallpaper('gradient-graphite', Color(0xFF2A2A2A), Color(0xFF4E4E4E)),
  Wallpaper('gradient-crimson', Color(0xFF2F1212), Color(0xFF702121)),
  Wallpaper('gradient-mist', Color(0xFFEEEEEE), Color(0xFFE2E1E1)),
  Wallpaper('gradient-lilac', Color(0xFFEFEAF7), Color(0xFFEBE4F6)),
  Wallpaper('gradient-ice', Color(0xFFE3F4F6), Color(0xFFDFF2F5)),
  Wallpaper('gradient-blush', Color(0xFFF4F0F0), Color(0xFFE9E1E1)),
];

Wallpaper? wallpaperById(String id) {
  for (final w in [...classicLight, ...classicDark, ...gradients]) {
    if (w.id == id) return w;
  }
  return null;
}
