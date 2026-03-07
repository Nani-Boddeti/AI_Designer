// calendar_events_map_test.dart
// Unit tests for the calendarEventsMapProvider grouping logic and
// CalendarNotifier.eventsForDay predicate. Mirrors the algorithm — pure Dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_designer_assist/data/models/calendar_event.dart';

// ---------------------------------------------------------------------------
// Mirrors of the production algorithms
// ---------------------------------------------------------------------------

/// Mirror of calendarEventsMapProvider grouping logic.
Map<DateTime, List<CalendarEvent>> groupEventsByDay(List<CalendarEvent> events) {
  final Map<DateTime, List<CalendarEvent>> map = {};
  for (final event in events) {
    final day = DateTime(
        event.eventDate.year, event.eventDate.month, event.eventDate.day);
    map.putIfAbsent(day, () => []).add(event);
  }
  return map;
}

/// Mirror of CalendarNotifier.eventsForDay predicate.
List<CalendarEvent> eventsForDay(List<CalendarEvent> events, DateTime day) {
  return events.where((e) {
    return e.eventDate.year == day.year &&
        e.eventDate.month == day.month &&
        e.eventDate.day == day.day;
  }).toList();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

CalendarEvent _event({
  String id = 'event-1',
  DateTime? eventDate,
  String title = 'Test Event',
}) =>
    CalendarEvent(
      id: id,
      householdId: 'hh-1',
      title: title,
      eventDate: eventDate ?? DateTime(2024, 9, 15),
      createdAt: DateTime(2024, 8, 1),
    );

void main() {
  // ---------------------------------------------------------------------------
  group('groupEventsByDay — basic grouping', () {
    test('empty list → empty map', () {
      expect(groupEventsByDay([]), isEmpty);
    });

    test('single event → map with one key', () {
      final map = groupEventsByDay([_event()]);
      expect(map, hasLength(1));
    });

    test('single event → key is midnight DateTime for that date', () {
      final event = _event(eventDate: DateTime(2024, 9, 15, 14, 30));
      final map = groupEventsByDay([event]);
      // Key must be date-only (midnight)
      final key = map.keys.first;
      expect(key, DateTime(2024, 9, 15));
      expect(key.hour, 0);
      expect(key.minute, 0);
    });

    test('two events on same day → one map key, two values', () {
      final e1 = _event(id: '1', eventDate: DateTime(2024, 9, 15, 9, 0));
      final e2 = _event(id: '2', eventDate: DateTime(2024, 9, 15, 18, 0));
      final map = groupEventsByDay([e1, e2]);
      expect(map, hasLength(1));
      expect(map[DateTime(2024, 9, 15)], hasLength(2));
    });

    test('two events on different days → two map keys', () {
      final e1 = _event(id: '1', eventDate: DateTime(2024, 9, 15));
      final e2 = _event(id: '2', eventDate: DateTime(2024, 9, 16));
      final map = groupEventsByDay([e1, e2]);
      expect(map, hasLength(2));
    });

    test('three events, two on same day, one on another → two keys', () {
      final events = [
        _event(id: '1', eventDate: DateTime(2024, 10, 1)),
        _event(id: '2', eventDate: DateTime(2024, 10, 1)),
        _event(id: '3', eventDate: DateTime(2024, 10, 2)),
      ];
      final map = groupEventsByDay(events);
      expect(map, hasLength(2));
      expect(map[DateTime(2024, 10, 1)], hasLength(2));
      expect(map[DateTime(2024, 10, 2)], hasLength(1));
    });

    test('events spread across months → grouped correctly', () {
      final events = [
        _event(id: '1', eventDate: DateTime(2024, 1, 15)),
        _event(id: '2', eventDate: DateTime(2024, 2, 15)),
        _event(id: '3', eventDate: DateTime(2024, 3, 15)),
      ];
      final map = groupEventsByDay(events);
      expect(map, hasLength(3));
      expect(map.containsKey(DateTime(2024, 1, 15)), isTrue);
      expect(map.containsKey(DateTime(2024, 2, 15)), isTrue);
      expect(map.containsKey(DateTime(2024, 3, 15)), isTrue);
    });

    test('key normalization: time component stripped from event date', () {
      // Two events with the same date but different times → same key
      final e1 = _event(id: '1', eventDate: DateTime(2024, 6, 1, 0, 0));
      final e2 = _event(id: '2', eventDate: DateTime(2024, 6, 1, 23, 59));
      final map = groupEventsByDay([e1, e2]);
      expect(map.keys.single, DateTime(2024, 6, 1));
    });

    test('events list order preserved within each day bucket', () {
      final e1 = _event(id: 'first', eventDate: DateTime(2024, 9, 15));
      final e2 = _event(id: 'second', eventDate: DateTime(2024, 9, 15));
      final map = groupEventsByDay([e1, e2]);
      final bucket = map[DateTime(2024, 9, 15)]!;
      expect(bucket.first.id, 'first');
      expect(bucket.last.id, 'second');
    });

    test('same event date across different years → separate keys', () {
      final e1 = _event(id: '1', eventDate: DateTime(2023, 6, 15));
      final e2 = _event(id: '2', eventDate: DateTime(2024, 6, 15));
      final map = groupEventsByDay([e1, e2]);
      expect(map, hasLength(2));
    });

    test('leap year date (Feb 29) grouped correctly', () {
      final e = _event(eventDate: DateTime(2024, 2, 29));
      final map = groupEventsByDay([e]);
      expect(map.containsKey(DateTime(2024, 2, 29)), isTrue);
    });

    test('10 events on the same day → single bucket with 10 entries', () {
      final events = List.generate(
        10,
        (i) => _event(id: 'e$i', eventDate: DateTime(2024, 12, 25)),
      );
      final map = groupEventsByDay(events);
      expect(map[DateTime(2024, 12, 25)], hasLength(10));
    });
  });

  // ---------------------------------------------------------------------------
  group('eventsForDay predicate', () {
    test('no events → empty result', () {
      expect(eventsForDay([], DateTime(2024, 9, 15)), isEmpty);
    });

    test('exact date match → returned', () {
      final e = _event(eventDate: DateTime(2024, 9, 15));
      expect(eventsForDay([e], DateTime(2024, 9, 15)), hasLength(1));
    });

    test('different day → not returned', () {
      final e = _event(eventDate: DateTime(2024, 9, 16));
      expect(eventsForDay([e], DateTime(2024, 9, 15)), isEmpty);
    });

    test('different month → not returned', () {
      final e = _event(eventDate: DateTime(2024, 8, 15));
      expect(eventsForDay([e], DateTime(2024, 9, 15)), isEmpty);
    });

    test('different year → not returned', () {
      final e = _event(eventDate: DateTime(2023, 9, 15));
      expect(eventsForDay([e], DateTime(2024, 9, 15)), isEmpty);
    });

    test('event with time component still matches on day', () {
      final e = _event(eventDate: DateTime(2024, 9, 15, 14, 30));
      expect(eventsForDay([e], DateTime(2024, 9, 15)), hasLength(1));
    });

    test('multiple events — only matching day returned', () {
      final events = [
        _event(id: '1', eventDate: DateTime(2024, 9, 15)),
        _event(id: '2', eventDate: DateTime(2024, 9, 16)),
        _event(id: '3', eventDate: DateTime(2024, 9, 15)),
      ];
      final result = eventsForDay(events, DateTime(2024, 9, 15));
      expect(result, hasLength(2));
      expect(result.map((e) => e.id), containsAll(['1', '3']));
    });

    test('all events on different days — none match target day', () {
      final events = [
        _event(id: '1', eventDate: DateTime(2024, 9, 10)),
        _event(id: '2', eventDate: DateTime(2024, 9, 11)),
      ];
      expect(eventsForDay(events, DateTime(2024, 9, 15)), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group('groupEventsByDay + eventsForDay integration', () {
    test('grouping then lookup returns same events', () {
      final events = [
        _event(id: 'a', eventDate: DateTime(2024, 9, 15)),
        _event(id: 'b', eventDate: DateTime(2024, 9, 15)),
        _event(id: 'c', eventDate: DateTime(2024, 9, 16)),
      ];
      final map = groupEventsByDay(events);
      final forDay15 = map[DateTime(2024, 9, 15)] ?? [];
      final predDay15 = eventsForDay(events, DateTime(2024, 9, 15));

      expect(forDay15.map((e) => e.id).toSet(),
          equals(predDay15.map((e) => e.id).toSet()));
    });

    test('all grouped keys match eventsForDay with non-empty result', () {
      final events = [
        _event(id: '1', eventDate: DateTime(2024, 1, 1)),
        _event(id: '2', eventDate: DateTime(2024, 6, 15)),
        _event(id: '3', eventDate: DateTime(2024, 12, 31)),
      ];
      final map = groupEventsByDay(events);
      for (final key in map.keys) {
        expect(eventsForDay(events, key), isNotEmpty);
      }
    });
  });
}
