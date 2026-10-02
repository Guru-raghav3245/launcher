import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One Mind Space tool (Mindful Pause, Focus Mode, ...): an explainer shown
/// the first time it's opened, then its own settings page every time after.
class MindSpaceTool {
  const MindSpaceTool({
    required this.id,
    required this.icon,
    required this.title,
    required this.summary,
    required this.whatItDoes,
    required this.whyItMatters,
    required this.howItWorks,
    required this.page,
  });

  final String id;
  final IconData icon;
  final String title;

  /// One line under the title in the Action tab's list.
  final String summary;
  final String whatItDoes;
  final String whyItMatters;
  final String howItWorks;
  final WidgetBuilder page;

  String get _seenKey => 'tool_intro_seen_$id';

  /// Pushes the explainer on first use (its "Let's go" swaps in the
  /// tool's page and remembers it was seen), otherwise the page directly.
  Future<void> open(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    final seen = prefs.getBool(_seenKey) ?? false;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => seen
            ? page(context)
            : _ToolIntroPage(
                tool: this,
                onStart: () async {
                  await prefs.setBool(_seenKey, true);
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: page));
                  }
                },
              ),
      ),
    );
  }
}

class _ToolIntroPage extends StatelessWidget {
  const _ToolIntroPage({required this.tool, required this.onStart});

  final MindSpaceTool tool;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? Colors.white70 : Colors.black54;
    Widget section(String heading, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(fontSize: 16, height: 1.5, color: secondary)),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Icon(tool.icon, size: 48),
            const SizedBox(height: 16),
            Text(
              tool.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            section('What it does', tool.whatItDoes),
            section('Why it matters', tool.whyItMatters),
            section('How it works', tool.howItWorks),
            FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Let's go", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
