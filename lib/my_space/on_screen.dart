import 'dart:async';

import 'package:flutter/widgets.dart';

/// Whether My Space is on screen: its page is the settled one and the
/// launcher is in front. Set by LauncherShell. Every panel stays alive off
/// screen, so tiles that poll check this rather than polling forever.
final mySpaceOnScreen = ValueNotifier(false);

/// For tiles that refresh on a timer (Music, RAM & Storage): [poll] runs
/// once when the tile is built, then every [pollInterval] while My Space is
/// on screen, and straight away whenever it comes back into view.
mixin PollsWhileOnScreen<T extends StatefulWidget> on State<T> {
  Duration get pollInterval;

  void poll();

  Timer? _timer;
  var _stopped = false;

  @override
  void initState() {
    super.initState();
    poll();
    _restartTimer();
    mySpaceOnScreen.addListener(_onScreenChanged);
  }

  void _onScreenChanged() {
    _restartTimer();
    if (mySpaceOnScreen.value && !_stopped) poll();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = mySpaceOnScreen.value && !_stopped ? Timer.periodic(pollInterval, (_) => poll()) : null;
  }

  /// Stops polling for good (e.g. the platform channel isn't there).
  void stopPolling() {
    _stopped = true;
    _restartTimer();
  }

  @override
  void dispose() {
    mySpaceOnScreen.removeListener(_onScreenChanged);
    _timer?.cancel();
    super.dispose();
  }
}
