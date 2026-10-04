import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../panels/app_drawer_panel.dart';
import '../panels/home_panel.dart';
import '../panels/mind_space_panel.dart';
import '../panels/my_space_panel.dart';
import '../panels/spotlight_search_panel.dart';
import '../services/gestures_service.dart';
import '../services/installed_apps_service.dart';
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
  // can raise or drop the keyboard (every page stays alive, see _KeepAlive).
  final _spotlightShown = ValueNotifier(false);
  final _drawerShown = ValueNotifier(false);

  // Spotlight is only a page while swipe down opens it (Settings → Gestures);
  // the controller is rebuilt when that changes, landing back on Home.
  PageController? _verticalController;
  bool? _hasSpotlight;
  var _pulledDown = false;

  static const _appChannel = MethodChannel('yinyang.launcher/app');

  @override
  void initState() {
    super.initState();
    // The Home key, pressed while the launcher is already up (MainActivity's
    // onNewIntent): close any sheet or page and go back to the Home panel.
    _appChannel.setMethodCallHandler((call) async {
      if (call.method == 'home' && mounted) _goHome();
      if (call.method == 'packagesChanged') InstalledAppsService.invalidate();
    });
  }

  /// Closes any sheet or page and animates both pagers back to Home. The
  /// row's pager is detached while Spotlight or the drawer is showing, so it
  /// moves once the vertical pager has brought it back.
  Future<void> _goHome() async {
    Navigator.of(context).popUntil((route) => route.isFirst);
    const duration = Duration(milliseconds: 300);
    final vertical = _verticalController;
    if (vertical != null && vertical.hasClients) {
      await vertical.animateToPage(_hasSpotlight! ? 1 : 0, duration: duration, curve: Curves.easeOut);
    }
    if (_rowController.hasClients) await _rowController.animateToPage(1, duration: duration, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _appChannel.setMethodCallHandler(null);
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
            if (hasSpotlight) _KeepAlive(SpotlightSearchPanel(shown: _spotlightShown)),
            _KeepAlive(PageView(
              controller: _rowController,
              physics: const ClampingScrollPhysics(),
              // A running tour is done once its page arrives.
              onPageChanged: (page) => switch (page) {
                0 => TourService.complete(Tour.organizeDay),
                2 => TourService.complete(Tour.usePhoneLess),
                _ => null,
              },
              children: const [_KeepAlive(MySpacePanel()), _KeepAlive(HomePanel()), _KeepAlive(MindSpacePanel())],
            )),
            _KeepAlive(AppDrawerPanel(shown: _drawerShown, onClose: _goHome)),
          ],
        ),
      ),
    );
  }
}

/// Keeps a pager's page alive off screen. A PageView disposes pages it
/// scrolls away from, which made every swipe rebuild its panel and reload
/// every app icon (seconds of empty dock and drawer on a low-end phone).
class _KeepAlive extends StatefulWidget {
  const _KeepAlive(this.child);

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
