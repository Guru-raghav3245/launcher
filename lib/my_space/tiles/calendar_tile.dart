import '../../widgets/skeleton.dart';
import 'package:flutter/material.dart';

import '../../services/calendar_service.dart';
import '../tile_card.dart';

/// "Today", "Tomorrow", or the weekday and date, for grouping events.
String dayLabel(BuildContext context, DateTime day, DateTime now) {
  final d = DateTime(day.year, day.month, day.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = d.difference(today).inDays;
  if (diff <= 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  return MaterialLocalizations.of(context).formatMediumDate(d);
}

/// Calendar tile: the next few events over the coming week, grouped by day;
/// tapping one opens it in the calendar app. Asks for calendar access from
/// a button on the tile, and re-reads on resume (access can be granted in
/// Settings, and events change elsewhere).
class CalendarTile extends StatefulWidget {
  const CalendarTile({super.key});

  static const maxEvents = 5;

  @override
  State<CalendarTile> createState() => _CalendarTileState();
}

class _CalendarTileState extends State<CalendarTile> {
  final _calendar = const CalendarService();
  late final _lifecycle = AppLifecycleListener(onResume: _load);
  bool? _hasAccess;
  List<CalendarEvent> _events = const [];

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _load();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final access = await _calendar.hasAccess();
      final events = access ? await _calendar.upcoming() : const <CalendarEvent>[];
      if (mounted) {
        setState(() {
          _hasAccess = access;
          _events = events.take(CalendarTile.maxEvents).toList();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _hasAccess = false); // No calendar channel (tests).
    }
  }

  Future<void> _requestAccess() async {
    if (await _calendar.requestAccess()) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return TileCard(
      label: 'CALENDAR',
      icon: Icons.event_outlined,
      child: switch (_hasAccess) {
        null => const SkeletonLines(lines: 2),
        false => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('See your next events here.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _requestAccess,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('Allow calendar access'),
            ),
          ],
        ),
        true => CalendarBody(events: _events, onOpen: (e) => _calendar.openEvent(e.id)),
      },
    );
  }
}

/// Events grouped under day labels, shared with the Add New Tile preview.
class CalendarBody extends StatelessWidget {
  const CalendarBody({super.key, required this.events, this.onOpen, this.now});

  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent>? onOpen;

  /// For the preview's fixed sample; defaults to the real time.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return Text('Nothing in the next 7 days.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant));
    final today = now ?? DateTime.now();
    String? lastDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final event in events) ...[
          if (dayLabel(context, event.begin, today) case final day when day != lastDay) ...[
            if (lastDay != null) const SizedBox(height: 8),
            Text(
              (lastDay = day).toUpperCase(),
              style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
          InkWell(
            onTap: onOpen == null ? null : () => onOpen!(event),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      event.allDay ? 'All day' : TimeOfDay.fromDateTime(event.begin).format(context),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
