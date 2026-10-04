import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'focus_mode_service.dart';
import 'focus_session_notification.dart';

/// A weekly Focus Mode reminder: on [days] (DateTime.monday..sunday) at
/// [hour]:[minute], a notification offers a [durationMinutes] session.
class FocusSchedule {
  const FocusSchedule({
    required this.id,
    required this.name,
    required this.days,
    required this.hour,
    required this.minute,
    required this.durationMinutes,
    this.strict = false,
    this.enabled = true,
  });

  final String id;
  final String name;
  final Set<int> days;
  final int hour;
  final int minute;
  final int durationMinutes;
  final bool strict;
  final bool enabled;

  FocusSchedule copyWith({bool? enabled}) => FocusSchedule(
    id: id,
    name: name,
    days: days,
    hour: hour,
    minute: minute,
    durationMinutes: durationMinutes,
    strict: strict,
    enabled: enabled ?? this.enabled,
  );

  factory FocusSchedule.fromJson(Map<String, dynamic> json) => FocusSchedule(
    id: json['id'] as String,
    name: json['name'] as String,
    days: (json['days'] as List).cast<int>().toSet(),
    hour: json['hour'] as int,
    minute: json['minute'] as int,
    durationMinutes: json['durationMinutes'] as int,
    strict: json['strict'] as bool? ?? false,
    enabled: json['enabled'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'days': (days.toList()..sort()),
    'hour': hour,
    'minute': minute,
    'durationMinutes': durationMinutes,
    'strict': strict,
    'enabled': enabled,
  };
}

/// The next [weekday] at [hour]:[minute] strictly after [now] (same zone).
tz.TZDateTime nextWeekdayTime(tz.TZDateTime now, int weekday, int hour, int minute) {
  var date = tz.TZDateTime(now.location, now.year, now.month, now.day, hour, minute);
  while (date.weekday != weekday || !date.isAfter(now)) {
    date = tz.TZDateTime(now.location, date.year, date.month, date.day + 1, hour, minute);
  }
  return date;
}

/// Persists Focus schedules and keeps their reminders (scheduled weekly
/// notifications via flutter_local_notifications) in step. Tapping a
/// reminder starts the schedule's session.
class FocusScheduleService {
  const FocusScheduleService();

  static const _key = 'focus_schedules';
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Set by [init]; until then (e.g. in tests) reminders aren't touched.
  static var _ready = false;
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'focus_schedules',
      'Focus schedules',
      channelDescription: 'Reminders to start a scheduled Focus session',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  /// Sets up the plugin and time zones; call once from main. If the app was
  /// opened by tapping a reminder, starts that session.
  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (response) => startFromReminder(response.payload),
    );
    _ready = true;
    FocusSessionNotification.ready = true;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) await startFromReminder(launch!.notificationResponse?.payload);
  }

  /// A tapped reminder: start that schedule's session, unless one's running.
  static Future<void> startFromReminder(String? scheduleId) async {
    final schedule = (await const FocusScheduleService().schedules()).where((s) => s.id == scheduleId).firstOrNull;
    if (schedule == null || (await const FocusModeService().status()).active) return;
    await const FocusModeService().start(
      duration: Duration(minutes: schedule.durationMinutes),
      strict: schedule.strict,
    );
  }

  Future<List<FocusSchedule>> schedules() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return [for (final s in jsonDecode(raw) as List) FocusSchedule.fromJson(s as Map<String, dynamic>)];
  }

  Future<void> save(FocusSchedule schedule) async {
    final all = await schedules();
    final i = all.indexWhere((s) => s.id == schedule.id);
    if (i == -1) {
      all.add(schedule);
    } else {
      all[i] = schedule;
    }
    await _write(all);
  }

  Future<void> delete(String id) async => _write((await schedules())..removeWhere((s) => s.id == id));

  Future<void> _write(List<FocusSchedule> all) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final s in all) s.toJson()]));
    if (_ready) await _reschedule(all);
  }

  /// Re-schedules every reminder from what's stored, e.g. after the user
  /// grants exact alarms on the system screen (which reports no result).
  Future<void> refreshReminders() async {
    if (_ready) await _reschedule(await schedules());
  }

  /// Asks for what reminders need: posting notifications (Android 13+) and
  /// exact alarms (user-granted on Android 14+; without it they're inexact).
  Future<void> requestPermissions() async {
    if (!_ready) return;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    if (!(await android?.canScheduleExactNotifications() ?? true)) await android?.requestExactAlarmsPermission();
  }

  /// Rebuilds every reminder from scratch: one weekly notification per
  /// enabled schedule and day, with id `index * 10 + weekday`. Only pending
  /// ones are cancelled: cancelAll would also remove a showing Focus
  /// session notification.
  static Future<void> _reschedule(List<FocusSchedule> all) async {
    await _plugin.cancelAllPendingNotifications();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final mode = (await android?.canScheduleExactNotifications() ?? false)
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final now = tz.TZDateTime.now(tz.local);
    for (final (i, schedule) in all.indexed) {
      if (!schedule.enabled) continue;
      for (final day in schedule.days) {
        await _plugin.zonedSchedule(
          id: i * 10 + day,
          title: 'Time to focus',
          body: '${schedule.name} · ${_durationLabel(schedule.durationMinutes)} · Tap to start',
          scheduledDate: nextWeekdayTime(now, day, schedule.hour, schedule.minute),
          notificationDetails: _details,
          androidScheduleMode: mode,
          payload: schedule.id,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  static String _durationLabel(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    return m == 0 ? '$h h' : '$h h $m min';
  }
}
