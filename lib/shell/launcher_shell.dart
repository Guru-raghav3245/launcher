import 'package:flutter/material.dart';

import '../panels/app_drawer_panel.dart';
import '../panels/home_panel.dart';
import '../panels/mind_space_panel.dart';
import '../panels/my_space_panel.dart';
import '../panels/spotlight_search_panel.dart';

/// The 5-panel cross navigation: swipe down for Search, up for App Drawer,
/// and left/right between My Space, Home, and Mind Space.
///
/// Implemented as a vertical PageView (Search / [horizontal row] / Drawer)
/// containing a horizontal PageView (My Space / Home / Mind Space), so each
/// axis has its own PageView and gestures resolve by drag direction.
class LauncherShell extends StatefulWidget {
  const LauncherShell({super.key});

  @override
  State<LauncherShell> createState() => _LauncherShellState();
}

class _LauncherShellState extends State<LauncherShell> {
  final _rowController = PageController(initialPage: 1);

  // Which vertical page has settled on screen, so Spotlight and the drawer
  // can raise or drop the keyboard (all pages are built up front).
  final _spotlightShown = ValueNotifier(false);
  final _drawerShown = ValueNotifier(false);

  @override
  void dispose() {
    _rowController.dispose();
    _spotlightShown.dispose();
    _drawerShown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        scrollDirection: Axis.vertical,
        controller: PageController(initialPage: 1),
        physics: const ClampingScrollPhysics(),
        onPageChanged: (page) {
          _spotlightShown.value = page == 0;
          _drawerShown.value = page == 2;
        },
        children: [
          SpotlightSearchPanel(shown: _spotlightShown),
          PageView(
            controller: _rowController,
            physics: const ClampingScrollPhysics(),
            children: const [
              MySpacePanel(),
              HomePanel(),
              MindSpacePanel(),
            ],
          ),
          AppDrawerPanel(shown: _drawerShown),
        ],
      ),
    );
  }
}
