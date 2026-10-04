import 'package:flutter/material.dart';

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
ThemeData launcherTheme(Brightness brightness, {String? fontFamily}) {
  final dark = brightness == Brightness.dark;
  final ground = dark ? Colors.black : Colors.white;
  final ink = dark ? const Color(0xFFEBEBEB) : const Color(0xFF222222);
  final scheme = ColorScheme.fromSeed(
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
  return ThemeData(
    fontFamily: fontFamily,
    colorScheme: scheme,
    scaffoldBackgroundColor: ground,
    dividerColor: scheme.outlineVariant,
    bottomSheetTheme: BottomSheetThemeData(dragHandleColor: scheme.outlineVariant),
  );
}
