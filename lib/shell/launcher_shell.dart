import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../my_space/on_screen.dart';
import '../panels/app_drawer_panel.dart';
import '../panels/home_panel.dart';
import '../panels/mind_space_panel.dart';
import '../panels/my_space_panel.dart';
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

  // Whether the search + apps screen (the vertical pager's page 1) has
  // settled on screen, so it can raise or drop the keyboard (every page
  // stays alive, see _KeepAlive).
  final _drawerShown = ValueNotifier(false);

  final _verticalController = PageController();
  var _pulledDown = false;

  // What [mySpaceOnScreen] is worked out from: the row's page (My Space is
  // 0), whether the vertical pager is on the row, and whether the launcher
  // is in front.
  var _rowPage = 1;
  var _onRow = true;
  var _inFront = true;
  late final _lifecycle = AppLifecycleListener(
    onShow: () => _setVisibility(inFront: true),
    onHide: () => _setVisibility(inFront: false),
  );

  void _setVisibility({int? rowPage, bool? onRow, bool? inFront}) {
    _rowPage = rowPage ?? _rowPage;
    _onRow = onRow ?? _onRow;
    _inFront = inFront ?? _inFront;
    mySpaceOnScreen.value = _rowPage == 0 && _onRow && _inFront;
  }

  static const _appChannel = MethodChannel('student.launcher/app');

  @override
  void initState() {
    super.initState();
    _lifecycle;
    // The Home key, pressed while the launcher is already up (MainActivity's
    // onNewIntent): close any sheet or page and go back to the Home panel.
    _appChannel.setMethodCallHandler((call) async {
      if (call.method == 'home' && mounted) _goHome();
      if (call.method == 'packagesChanged') InstalledAppsService.invalidate();
    });
  }

  static const _pageDuration = Duration(milliseconds: 300);

  /// Closes any sheet or page and animates both pagers back to Home. The
  /// row's pager is detached while the search + apps screen is showing, so
  /// it moves once the vertical pager has brought it back.
  Future<void> _goHome() async {
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (_verticalController.hasClients) {
      await _verticalController.animateToPage(0, duration: _pageDuration, curve: Curves.easeOut);
    }
    if (_rowController.hasClients) {
      await _rowController.animateToPage(1, duration: _pageDuration, curve: Curves.easeOut);
    }
  }

  /// Home's search pill: up to the search + apps screen, as a swipe up would.
  void _openSearch() => _verticalController.animateToPage(1, duration: _pageDuration, curve: Curves.easeOut);

  @override
  void dispose() {
    _appChannel.setMethodCallHandler(null);
    _lifecycle.dispose();
    mySpaceOnScreen.value = false;
    _rowController.dispose();
    _verticalController.dispose();
    _drawerShown.dispose();
    super.dispose();
  }

  /// A pull down past the top of the pager (on Home's row, not inside a
  /// panel's own list) runs the swipe-down action, once per drag.
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
    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) => _onScroll(n, swipeDown),
        child: PageView(
          scrollDirection: Axis.vertical,
          controller: _verticalController,
          physics: const ClampingScrollPhysics(),
          onPageChanged: (page) {
            HapticFeedback.selectionClick();
            _drawerShown.value = page == 1;
            _setVisibility(onRow: page == 0);
            if (_drawerShown.value) TourService.complete(Tour.findApps);
          },
          children: [
            _KeepAlive(PageView(
              controller: _rowController,
              physics: const ClampingScrollPhysics(),
              // A running tour is done once its page arrives.
              onPageChanged: (page) {
                HapticFeedback.selectionClick();
                _setVisibility(rowPage: page);
                switch (page) {
                  case 0:
                    TourService.complete(Tour.organizeDay);
                  case 2:
                    TourService.complete(Tour.usePhoneLess);
                }
              },
              children: [
                const _KeepAlive(MySpacePanel()),
                _KeepAlive(HomePanel(onSearch: _openSearch)),
                const _KeepAlive(MindSpacePanel()),
              ],
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
