import 'package:flutter/material.dart';

import 'tool_intro.dart';
import 'tool_pages.dart';

/// The tools in Mind Space's Action tab, in display order. Mindful Break
/// joins this list in Phase 7 task 7.
final mindSpaceTools = [
  MindSpaceTool(
    id: 'mindful_pause',
    icon: Icons.self_improvement,
    title: 'Mindful Pause',
    summary: 'A breath before the apps you choose.',
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
    summary: 'A daily limit, and a length for every session.',
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
    id: 'focus_mode',
    icon: Icons.center_focus_strong,
    title: 'Focus Mode',
    summary: 'A session with only the apps you allow.',
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

/// Mind Space's Action tab: the list of tools to take time back.
class ActionTab extends StatelessWidget {
  const ActionTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? Colors.white60 : Colors.black54;
    final stroke = isDark ? Colors.white24 : Colors.black26;
    // The panel paints its own background, which would hide the rows' ink
    // splashes; give them a Material of their own to splash on.
    return Material(
      type: MaterialType.transparency,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        children: [
          const Text('Your tools', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Small frictions that help you take time back.', style: TextStyle(fontSize: 15, color: secondary)),
          const SizedBox(height: 24),
          for (final tool in mindSpaceTools)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: stroke),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  leading: Icon(tool.icon, size: 28),
                  title: Text(tool.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  subtitle: Text(tool.summary),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => tool.open(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
