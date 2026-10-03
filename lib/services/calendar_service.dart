import 'package:flutter/services.dart';

/// One occurrence of a calendar event.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.begin,
    required this.end,
    required this.allDay,
  });

  final int id;
  final String title;
  final DateTime begin;
  final DateTime end;
  final bool allDay;
}

/// Reads upcoming events through `CalendarBridge.kt` (READ_CALENDAR).
class CalendarService {
  const CalendarService();

  static const _channel = MethodChannel('yinyang.launcher/calendar');

  Future<bool> hasAccess() async => await _channel.invokeMethod<bool>('hasAccess') ?? false;

  /// Shows Android's permission dialog, or, if the user has turned it down
  /// for good, opens this app's settings page. True once granted.
  Future<bool> requestAccess() async => await _channel.invokeMethod<bool>('requestAccess') ?? false;

  /// Event occurrences from now to [days] ahead, soonest first.
  Future<List<CalendarEvent>> upcoming({int days = 7}) async {
    final rows = await _channel.invokeListMethod<Map<Object?, Object?>>('events', {'days': days}) ?? const [];
    return [
      for (final r in rows)
        CalendarEvent(
          id: r['id'] as int,
          title: (r['title'] as String?)?.trim().isNotEmpty == true ? r['title'] as String : '(No title)',
          begin: DateTime.fromMillisecondsSinceEpoch(r['begin'] as int),
          end: DateTime.fromMillisecondsSinceEpoch(r['end'] as int),
          allDay: r['allDay'] as bool,
        ),
    ];
  }

  Future<void> openEvent(int id) => _channel.invokeMethod('openEvent', {'id': id});
}
