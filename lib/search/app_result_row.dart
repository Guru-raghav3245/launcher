import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import '../state/app_settings_scope.dart';

/// A single app row (icon + name), shared by the App Drawer's flat/search
/// results and Spotlight Search.
class AppResultRow extends StatelessWidget {
  const AppResultRow({
    super.key,
    required this.app,
    required this.onTap,
    this.onLongPress,
    this.height = 64,
    this.iconSize = 40,
    this.labelSize = 16,
    this.labelLines = 1,
    this.trailing,
  });

  final AppInfo app;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double height;

  /// 0 hides the icon; [labelSize] 0 hides the name (the Drawer look editor).
  final double iconSize;
  final double labelSize;
  final int labelLines;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              if (iconSize > 0) AppIcon(icon: app.icon, size: iconSize),
              if (iconSize > 0 && labelSize > 0) const SizedBox(width: 16),
              Expanded(
                child: labelSize == 0
                    ? const SizedBox.shrink()
                    : Text(
                        app.name,
                        maxLines: labelLines,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: labelSize),
                      ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.icon, this.size = 40});

  final Uint8List? icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final data = icon;
    if (data == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.apps, size: 20),
      );
    }
    // The icon tint from Settings → Appearance (grayscale by default), so
    // every icon in the launcher matches the calm, colourless design.
    final matrix = context.dependOnInheritedWidgetOfExactType<AppSettingsScope>()?.notifier?.iconTint.matrix;
    final image = Image.memory(data, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: matrix == null ? image : ColorFiltered(colorFilter: ColorFilter.matrix(matrix), child: image),
    );
  }
}
