import 'package:flutter/material.dart';

import '../../models/home_layout_mode.dart';
import '../../models/wallpaper.dart';
import '../../panels/home_panel.dart';
import '../../services/launcher_role_service.dart';
import '../../state/app_settings.dart';
import '../../state/app_settings_scope.dart';
import '../phone_mockup.dart';
import '../../widgets/segmented_toggle.dart';
import '../wallpaper_picker.dart';

/// Live preview of the real Home screen, with pickers that mutate the
/// shared [AppSettings] the preview itself reads. In light theme, the
/// chosen wallpaper also tints this whole step's background (matching the
/// original design), not just the mockup. The CTA requests the Android
/// default-launcher role, then advances regardless of the outcome — the
/// user can always change it later from Settings, so onboarding shouldn't
/// get stuck on a cancelled system dialog.
class CustomizeStep extends StatefulWidget {
  const CustomizeStep({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  State<CustomizeStep> createState() => _CustomizeStepState();
}

class _CustomizeStepState extends State<CustomizeStep> {
  final _roleService = const LauncherRoleService();
  bool _requesting = false;

  Future<void> _setAsLauncher() async {
    setState(() => _requesting = true);
    await _roleService.requestHomeRole();
    if (!mounted) return;
    setState(() => _requesting = false);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);

    return Container(
      // The light wallpaper tints this step (a deep gradient would hide its text).
      color: settings.isDark || settings.lightWallpaper.isDark ? null : settings.lightWallpaper.edge,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                SegmentedToggle<bool>(
                  value: settings.isDark,
                  onChanged: settings.setDark,
                  options: const [(false, Icons.wb_sunny_outlined, 'Light'), (true, Icons.nightlight_round, 'Dark')],
                ),
                SegmentedToggle<HomeLayoutMode>(
                  value: settings.layoutMode,
                  onChanged: settings.setLayoutMode,
                  options: const [
                    (HomeLayoutMode.classic, Icons.dashboard_outlined, 'Classic'),
                    (HomeLayoutMode.minimal, Icons.short_text, 'Minimal'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const PhoneMockup(child: HomePanel(preview: true)),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WALLPAPER',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 2,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  WallpaperPicker(
                    colors: [for (final w in classicLight) w.edge],
                    selectedIndex: classicLight.indexOf(settings.lightWallpaper),
                    onSelected: (i) => settings.setWallpaper(classicLight[i], forDark: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _requesting ? null : _setAsLauncher,
                  child: const Text('Set as my launcher', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
