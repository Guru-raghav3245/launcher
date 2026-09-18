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

  @override
  void dispose() {
    _rowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        scrollDirection: Axis.vertical,
        controller: PageController(initialPage: 1),
        physics: const ClampingScrollPhysics(),
        children: [
          const SpotlightSearchPanel(),
          PageView(
            controller: _rowController,
            physics: const ClampingScrollPhysics(),
            children: const [
              MySpacePanel(),
              HomePanel(),
              MindSpacePanel(),
            ],
          ),
          const AppDrawerPanel(),
        ],
      ),
    );
  }
}
