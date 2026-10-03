import 'package:flutter/material.dart';

import '../models/wallpaper.dart';
import '../state/app_settings.dart';
import 'segmented_toggle.dart';

/// Launcher Settings' wallpaper chooser, after the original's: a Light /
/// Dark switch for which theme's wallpaper is being picked (starting on the
/// current theme), then the Classic flats for that theme and the Gradient
/// collection, which both themes share.
class WallpaperGallery extends StatefulWidget {
  const WallpaperGallery({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<WallpaperGallery> createState() => _WallpaperGalleryState();
}

class _WallpaperGalleryState extends State<WallpaperGallery> {
  late bool _forDark = widget.settings.isDark;

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final selected = _forDark ? settings.darkWallpaper : settings.lightWallpaper;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget strip(String label, List<Wallpaper> wallpapers) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(label, style: TextStyle(fontSize: 13, color: secondary)),
        ),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: wallpapers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _Swatch(
              wallpaper: wallpapers[i],
              selected: wallpapers[i] == selected,
              outline: settings.isDark ? Colors.white : Colors.black,
              onTap: () => settings.setWallpaper(wallpapers[i], forDark: _forDark),
            ),
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Wallpaper', style: TextStyle(fontSize: 18, letterSpacing: 0.5)),
            const SizedBox(width: 16),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: SegmentedToggle<bool>(
                  value: _forDark,
                  onChanged: (v) => setState(() => _forDark = v),
                  options: const [(false, Icons.wb_sunny_outlined, 'Light'), (true, Icons.nightlight_round, 'Dark')],
                ),
              ),
            ),
          ],
        ),
        strip('Classic', _forDark ? classicDark : classicLight),
        strip('Gradient', gradients),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.wallpaper, required this.selected, required this.outline, required this.onTap});

  final Wallpaper wallpaper;
  final bool selected;
  final Color outline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        decoration: BoxDecoration(
          gradient: wallpaper.gradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? outline : outline.withValues(alpha: 0.15), width: selected ? 2 : 1),
        ),
        child: selected
            ? Icon(Icons.check_circle, size: 20, color: wallpaper.isDark ? Colors.white : Colors.black)
            : null,
      ),
    );
  }
}
