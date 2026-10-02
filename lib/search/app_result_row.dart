import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

/// A single app row (icon + name), shared by the App Drawer's flat/search
/// results and Spotlight Search.
class AppResultRow extends StatelessWidget {
  const AppResultRow({super.key, required this.app, required this.onTap, this.height = 64, this.trailing});

  final AppInfo app;
  final VoidCallback onTap;
  final double height;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              AppIcon(icon: app.icon),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  app.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.memory(data, width: size, height: size, fit: BoxFit.cover),
    );
  }
}
