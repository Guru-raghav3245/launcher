import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

/// "Back on Oct 6, 2026, 12:17 PM", in the device's locale.
String breakEndLabel(BuildContext context, DateTime endsAt) {
  final date = MaterialLocalizations.of(context).formatMediumDate(endsAt);
  return 'Back on $date, ${TimeOfDay.fromDateTime(endsAt).format(context)}';
}

/// The quiet screen shown instead of an app that's on a Mindful Break.
Future<void> showBreakBlock(BuildContext context, AppInfo app, DateTime endsAt) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final ink = isDark ? Colors.white : Colors.black;
      final secondary = isDark ? Colors.white60 : Colors.black54;
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bedtime_outlined, size: 48, color: ink.withValues(alpha: 0.8)),
              const SizedBox(height: 16),
              Text(
                '${app.name} is on a break',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(breakEndLabel(context, endsAt), style: TextStyle(fontSize: 15, color: secondary)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: ink,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
