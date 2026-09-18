import 'package:flutter/material.dart';

enum _Slot { search, mySpace, home, mindSpace, appDrawer }

class _TutorialPage {
  const _TutorialPage({
    required this.active,
    required this.badge,
    required this.title,
    required this.subtitle,
  });

  final _Slot active;
  final String badge;
  final String title;
  final String subtitle;
}

const _pages = [
  _TutorialPage(
    active: _Slot.home,
    badge: 'LONG PRESS',
    title: 'Your Home',
    subtitle: 'Everything begins here.',
  ),
  _TutorialPage(
    active: _Slot.mySpace,
    badge: 'SWIPE RIGHT',
    title: 'My Space',
    subtitle: 'Your tools and daily essentials.',
  ),
  _TutorialPage(
    active: _Slot.mindSpace,
    badge: 'SWIPE LEFT',
    title: 'Mind Space',
    subtitle: 'Awareness, pause, and presence.',
  ),
  _TutorialPage(
    active: _Slot.search,
    badge: 'SWIPE DOWN',
    title: 'Spotlight Search',
    subtitle: 'Open apps with intention.',
  ),
  _TutorialPage(
    active: _Slot.appDrawer,
    badge: 'SWIPE UP',
    title: 'App Drawer',
    subtitle: 'All your apps, one swipe away.',
  ),
];

/// Interactive walkthrough of the Phase 1 nav shell's 5-panel cross
/// layout: Home (long press) and swipe right/left/down/up to the other
/// four panels. Last step's CTA finishes onboarding.
class TutorialStep extends StatefulWidget {
  const TutorialStep({super.key, required this.onFinish});

  final VoidCallback onFinish;

  @override
  State<TutorialStep> createState() => _TutorialStepState();
}

class _TutorialStepState extends State<TutorialStep> {
  int _page = 0;

  void _next() {
    if (_page == _pages.length - 1) {
      widget.onFinish();
    } else {
      setState(() => _page += 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];
    final isLast = _page == _pages.length - 1;

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Text(
            'TUTORIAL',
            style: TextStyle(color: Colors.black45, letterSpacing: 3, fontSize: 13),
          ),
          const Spacer(),
          _NavCross(active: page.active),
          const SizedBox(height: 32),
          Text(page.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(page.subtitle, style: const TextStyle(fontSize: 16, color: Colors.black54)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black26),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              page.badge,
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
          const Spacer(flex: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _pages.length; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page ? Colors.black : Colors.black26,
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _next,
                child: Text(isLast ? "Let's Go" : 'Next', style: const TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavCross extends StatelessWidget {
  const _NavCross({required this.active});

  final _Slot active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Box(icon: Icons.search, active: active == _Slot.search),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Box(icon: Icons.dashboard_outlined, active: active == _Slot.mySpace),
            const SizedBox(width: 12),
            _Box(icon: Icons.home_outlined, active: active == _Slot.home),
            const SizedBox(width: 12),
            _Box(icon: Icons.psychology_outlined, active: active == _Slot.mindSpace),
          ],
        ),
        const SizedBox(height: 12),
        _Box(icon: Icons.apps, active: active == _Slot.appDrawer),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.icon, required this.active});

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 68,
      height: 92,
      decoration: BoxDecoration(
        color: active ? Colors.black : Colors.transparent,
        border: Border.all(color: Colors.black45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: active ? Colors.white : Colors.black87),
    );
  }
}
