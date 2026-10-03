import 'package:flutter/material.dart';

import '../panels/app_drawer_panel.dart';
import '../panels/home_panel.dart';
import '../panels/mind_space_panel.dart';
import '../panels/my_space_panel.dart';
import '../panels/spotlight_search_panel.dart';
import '../services/gestures_service.dart';
import '../services/tour_service.dart';
import '../state/app_settings.dart';
import '../state/app_settings_scope.dart';

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

  // Spotlight is only a page while swipe down opens it (Settings → Gestures);
  // the controller is rebuilt when that changes, landing back on Home.
  PageController? _verticalController;
  bool? _hasSpotlight;
  var _pulledDown = false;

  @override
  void dispose() {
    _rowController.dispose();
    _verticalController?.dispose();
    _spotlightShown.dispose();
    _drawerShown.dispose();
    super.dispose();
  }

  /// Without a Spotlight page, a pull down past the top of the pager (on
  /// Home's row, not inside a panel's own list) runs the swipe-down action,
  /// once per drag.
  bool _onScroll(ScrollNotification notification, SwipeDownAction action) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification) _pulledDown = false;
    if (notification is OverscrollNotification &&
        notification.overscroll < 0 &&
        notification.dragDetails != null &&
        !_pulledDown) {
      _pulledDown = true;
      if (action == SwipeDownAction.notifications) const GesturesService().expandNotifications();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final swipeDown = AppSettingsScope.of(context).swipeDown;
    final hasSpotlight = swipeDown == SwipeDownAction.spotlight;
    if (hasSpotlight != _hasSpotlight) {
      _verticalController?.dispose();
      _verticalController = PageController(initialPage: hasSpotlight ? 1 : 0);
      _hasSpotlight = hasSpotlight;
    }
    final spotlightPages = hasSpotlight ? 1 : 0;
    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) => _onScroll(n, swipeDown),
        child: PageView(
          key: ValueKey(hasSpotlight),
          scrollDirection: Axis.vertical,
          controller: _verticalController,
          physics: const ClampingScrollPhysics(),
          onPageChanged: (page) {
            _spotlightShown.value = hasSpotlight && page == 0;
            _drawerShown.value = page == 1 + spotlightPages;
            if (_drawerShown.value) TourService.complete(Tour.findApps);
          },
          children: [
            if (hasSpotlight) SpotlightSearchPanel(shown: _spotlightShown),
            PageView(
              controller: _rowController,
              physics: const ClampingScrollPhysics(),
              // A running tour is done once its page arrives.
              onPageChanged: (page) => switch (page) {
                0 => TourService.complete(Tour.organizeDay),
                2 => TourService.complete(Tour.usePhoneLess),
                _ => null,
              },
              children: const [MySpacePanel(), HomePanel(), MindSpacePanel()],
            ),
            AppDrawerPanel(shown: _drawerShown),
          ],
        ),
      ),
    );
  }
}
