import 'package:flutter/material.dart';

/// The app's theme for [brightness]. Monochrome: the design has no accent
/// hue (DESIGN_LANGUAGE.md); the default seeded scheme tinted sheets and
/// buttons pink. Home also uses it to match its wallpaper's brightness.
/// [fontFamily] null means Android's own font (Roboto).
ThemeData launcherTheme(Brightness brightness, {String? fontFamily}) => ThemeData(
  fontFamily: fontFamily,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.black,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
  ),
);
