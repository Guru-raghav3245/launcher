import 'dart:async';

import 'package:flutter/widgets.dart';

/// Like `AppLifecycleListener(onResume: refresh)`, but [refresh] runs a
/// moment after the app is back. Panels refresh when the launcher returns
/// from an app (or from recents), which is exactly when the system animates
/// it in; waiting out that animation keeps those first frames free for it.
/// Dispose it like any listener.
class SettledResumeListener {
  SettledResumeListener(this._refresh, {this.delay = const Duration(milliseconds: 450)}) {
    _listener = AppLifecycleListener(
      onResume: () {
        _timer?.cancel();
        _timer = Timer(delay, _refresh);
      },
    );
  }

  final VoidCallback _refresh;
  final Duration delay;
  late final AppLifecycleListener _listener;
  Timer? _timer;

  void dispose() {
    _timer?.cancel();
    _listener.dispose();
  }
}
