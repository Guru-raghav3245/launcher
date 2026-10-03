import 'package:flutter/material.dart';

import 'tool_intro.dart';
import 'tool_pages.dart';

/// The tools in Mind Space's Action tab, in display order.
final mindSpaceTools = [
  MindSpaceTool(
    id: 'mindful_pause',
    icon: Icons.self_improvement,
    title: 'Mindful Pause',
    summary: 'Add a short pause before opening distracting apps.',
    whatItDoes:
        'Puts a short breathing screen in front of the apps you pick. When it ends, the app opens; '
        'if you change your mind, skip it and nothing opens.',
    whyItMatters:
        'Many app opens are reflexes, not decisions. A few seconds of pause is often enough to notice '
        "you didn't really mean to open it.",
    howItWorks:
        'Choose the apps to pause and how long the pause lasts (10 to 60 seconds). Opening one from '
        "this launcher shows the pause, along with how much you've used it today.",
    page: (context) => const MindfulPausePage(),
  ),
  MindSpaceTool(
    id: 'mindful_timer',
    icon: Icons.timer_outlined,
    title: 'Mindful Timer',
    summary: 'Decide how long to use distracting apps before you start.',
    whatItDoes:
        'Gives a group of apps one daily time limit. Each time you open one, you choose how long this '
        "session lasts; when it's up, a Time's up screen covers the app.",
    whyItMatters:
        'Endless feeds are built to have no natural stopping point. Deciding the length up front gives '
        'you one, and the daily limit keeps small sessions from adding up.',
    howItWorks:
        'Make a timer: name it, pick its apps, set the daily limit and an optional cooldown between '
        "sessions. Once the limit is used up, those apps won't open from this launcher until tomorrow.",
    page: (context) => const MindfulTimerPage(),
  ),
  MindSpaceTool(
    id: 'mindful_break',
    icon: Icons.bedtime_outlined,
    title: 'Mindful Break',
    summary: 'Step away from an app for a few days.',
    whatItDoes:
        'Hides an app from your App Drawer and search for 1, 3, 7, or 30 days. Opening it any other way '
        "shows a quiet screen with when it's back.",
    whyItMatters:
        "Some apps are easier to leave than to limit. Out of sight for a few days, you'll find out whether "
        'you miss it, or just the habit of opening it.',
    howItWorks:
        'Pick an app and how long its break lasts. It comes back on its own when the time is up, or end '
        'the break early from this page.',
    page: (context) => const MindfulBreakPage(),
  ),
  MindSpaceTool(
    id: 'focus_mode',
    icon: Icons.center_focus_strong,
    title: 'Focus Mode',
    summary: 'Hide everything but a few apps for a set time.',
    whatItDoes:
        'Blocks every app except the ones you allow, for as long as the session runs: until you stop '
        'it, or for a set time.',
    whyItMatters:
        'Deep work and real rest both need fewer interruptions. Focus Mode removes the option to '
        'drift, instead of relying on willpower.',
    howItWorks:
        'Pick your allowed apps (your phone and messages apps are allowed from the start), then start '
        'a session. Anything else you open from this launcher is refused until the session ends.',
    page: (context) => const FocusModePage(),
  ),
];

/// Mind Space's Action tab, laid out like the original's: the per-app tools
/// under "Apps you reach for", Focus Mode under "Focus time".
class ActionTab extends StatelessWidget {
  const ActionTab({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget section(String title, String subtitle, Iterable<MindSpaceTool> tools) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant)),
        const SizedBox(height: 14),
        for (final tool in tools)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 22),
            child: _ToolCard(tool: tool),
          ),
      ],
    );
    // The panel paints its own background, which would hide the cards' ink
    // splashes; give them a Material of their own to splash on.
    return Material(
      type: MaterialType.transparency,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(13, 30, 13, 24),
        children: [
          const Text('Your tools', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
          const SizedBox(height: 30),
          section(
            'Apps you reach for',
            'For the apps that pull you in.',
            mindSpaceTools.where((t) => t.id != 'focus_mode'),
          ),
          const SizedBox(height: 22),
          section(
            'Focus time',
            'Step away from everything for a set stretch.',
            mindSpaceTools.where((t) => t.id == 'focus_mode'),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool});

  final MindSpaceTool tool;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: colors.outline),
    );
    return Material(
      color: colors.surfaceContainer,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: () => tool.open(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
          child: Row(
            children: [
              // ponytail: an icon stands in for the original's grayscale
              // illustrations (its own artwork); draw ours to replace it.
              SizedBox(width: 40, child: Icon(tool.icon, size: 32, color: colors.onSurface)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tool.title, style: const TextStyle(fontSize: 19)),
                    const SizedBox(height: 2),
                    Text(tool.summary, style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
