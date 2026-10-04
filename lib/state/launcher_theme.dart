import 'package:flutter/material.dart';

import '../models/wallpaper.dart';

/// The app's theme for [brightness]. Monochrome: no accent hue
/// (DESIGN_LANGUAGE.md). The colours are sampled from the original app's
/// screens (Phase 11): pure black or white ground, soft ink, one mid-grey for
/// secondary text, and hairline borders. Widgets read the roles rather than
/// picking greys themselves:
/// - `onSurface`: primary text and icons
/// - `onSurfaceVariant`: secondary text, labels, placeholders
/// - `outline`: hairline borders around cards, pills, and tiles
/// - `outlineVariant`: dividers and faint fills
/// Home also uses it to match its wallpaper's brightness.
/// [fontFamily] null means Android's own font (Roboto).
///
/// With a [wallpaper] (the app's theme since Phase 12 task 8), every
/// page is painted on it: page routes are wrapped in its gradient and
/// scaffolds are transparent. On a coloured wallpaper, cards become a
/// translucent ink wash, secondary text gets more contrast, and sheets and
/// dialogs take an opaque version of its colour. A plain black or white one
/// (the default) looks exactly as without.
ThemeData launcherTheme(Brightness brightness, {String? fontFamily, Wallpaper? wallpaper}) {
  final dark = brightness == Brightness.dark;
  final ground = dark ? Colors.black : Colors.white;
  final ink = dark ? const Color(0xFFEBEBEB) : const Color(0xFF222222);
  final coloured = wallpaper != null && (wallpaper.band != null || wallpaper.edge != ground);
  // The wallpaper as one colour: a flat's own, or a gradient's two blended.
  final paper = !coloured ? ground : Color.lerp(wallpaper.edge, wallpaper.band ?? wallpaper.edge, 0.5)!;
  Color wash(double alpha) => ink.withValues(alpha: alpha);
  var scheme = ColorScheme.fromSeed(
    seedColor: Colors.black,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
  ).copyWith(
    primary: ink,
    onPrimary: ground,
    surface: ground,
    onSurface: ink,
    onSurfaceVariant: const Color(0xFF757575),
    outline: dark ? const Color(0xFF484848) : const Color(0xFF909090),
    outlineVariant: dark ? const Color(0xFF2B2B2B) : const Color(0xFFE0E0E0),
    // Sheets, dialogs, and menus sit on the same ground, like the original's;
    // the barrier behind them does the separating.
    surfaceContainerLowest: ground,
    surfaceContainerLow: ground,
    surfaceContainer: dark ? const Color(0xFF040404) : const Color(0xFFFEFEFE),
    surfaceContainerHigh: dark ? const Color(0xFF0C0C0C) : const Color(0xFFF7F7F7),
    surfaceContainerHighest: dark ? const Color(0xFF2B2B2B) : const Color(0xFFE8E8E8),
  );
  if (coloured) {
    scheme = scheme.copyWith(
      surface: paper,
      onPrimary: paper,
      onSurfaceVariant: wash(0.65),
      outline: wash(0.35),
      outlineVariant: wash(0.15),
      surfaceContainerLowest: paper,
      surfaceContainerLow: paper,
      surfaceContainer: wash(0.06),
      surfaceContainerHigh: wash(0.1),
      surfaceContainerHighest: wash(0.18),
    );
  }
  return ThemeData(
    fontFamily: fontFamily,
    colorScheme: scheme,
    scaffoldBackgroundColor: wallpaper == null ? ground : Colors.transparent,
    dividerColor: scheme.outlineVariant,
    bottomSheetTheme: BottomSheetThemeData(
      dragHandleColor: scheme.outlineVariant,
      // Sheets otherwise take surfaceContainerLow, which a coloured
      // wallpaper's translucent roles don't touch; set it plainly.
      backgroundColor: scheme.surfaceContainerLow,
    ),
    pageTransitionsTheme: wallpaper == null
        ? const PageTransitionsTheme()
        : PageTransitionsTheme(
            builders: {for (final platform in TargetPlatform.values) platform: _OnWallpaper(wallpaper)},
          ),
  );
}

/// The usual Android page transition, with the page painted on [wallpaper],
/// so every page shows it and stays opaque while it slides in.
class _OnWallpaper extends PageTransitionsBuilder {
  const _OnWallpaper(this.wallpaper);

  final Wallpaper wallpaper;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => const ZoomPageTransitionsBuilder().buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    DecoratedBox(
      decoration: BoxDecoration(gradient: wallpaper.gradient),
      child: child,
    ),
  );
}
