import 'package:flutter/material.dart';

import '../../state/app_settings_scope.dart';

/// First onboarding screen. The Light/Dark buttons set the initial theme
/// and advance to the next step.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key, required this.onNext});

  final VoidCallback onNext;

  void _choose(BuildContext context, bool isDark) {
    AppSettingsScope.of(context).setDark(isDark);
    onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2B2D33),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Spacer(flex: 3),
              const Text(
                'WELCOME TO',
                style: TextStyle(color: Colors.white60, letterSpacing: 4, fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Text(
                'Yin Yang Launcher.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              const Text(
                'Start with light or dark.',
                style: TextStyle(color: Colors.white60, fontSize: 16),
              ),
              const Spacer(flex: 2),
              Row(
                children: [
                  Expanded(
                    child: _ThemeChoiceButton(
                      label: 'Light',
                      icon: Icons.wb_sunny_outlined,
                      background: Colors.white,
                      foreground: Colors.black,
                      onTap: () => _choose(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ThemeChoiceButton(
                      label: 'Dark',
                      icon: Icons.nightlight_round,
                      background: Colors.black,
                      foreground: Colors.white,
                      onTap: () => _choose(context, true),
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeChoiceButton extends StatelessWidget {
  const _ThemeChoiceButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(color: foreground, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
