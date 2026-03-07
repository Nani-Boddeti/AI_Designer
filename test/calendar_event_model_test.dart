// calendar_event_model_test.dart
// Unit tests for CalendarEvent model: fromJson, toJson, copyWith,
// _parseLocalDate, outfitAssignments edge cases. Pure Dart — no Flutter.

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_designer_assist/data/models/calendar_event.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _fullJson() => {
      'id': 'event-1',
      'household_id': 'hh-1',
      'title': 'Family Wedding',
      'event_date': '2024-09-15',
      'occasion': 'Wedding',
      'outfit_assignments': {'profile-1': 'outfit-a', 'profile-2': 'outfit-b'},
      'weather_snapshot': {'temp_c': 28.5, 'description': 'Sunny'},
      'notes': 'Formal attire required',
      'created_at': '2024-08-01T09:00:00.000Z',
    };

Map<String, dynamic> _minimalJson() => {
      'id': 'event-2',
      'household_id': 'hh-1',
      'title': 'Casual Brunch',
      'event_date': '2024-10-05',
      'created_at': '2024-09-01T00:00:00.000Z',
    };

CalendarEvent _makeEvent({
  String id = 'event-1',
  String title = 'Test Event',
  String? occasion,
  Map<String, String> outfitAssignments = const {},
  String? notes,
  DateTime? eventDate,
}) =>
    CalendarEvent(
      id: id,
      householdId: 'hh-1',
      title: title,
      eventDate: eventDate ?? DateTime(2024, 9, 15),
      occasion: occasion,
      outfitAssignments: outfitAssignments,
      notes: notes,
      createdAt: DateTime(2024, 8, 1),
    );

void main() {
  // -------------------------------------------------------------------------
  group('CalendarEvent.fromJson — full payload', () {
    late CalendarEvent event;
    setUp(() => event = CalendarEvent.fromJson(_fullJson()));

    test('id', () => expect(event.id, 'event-1'));
    test('householdId', () => expect(event.householdId, 'hh-1'));
    test('title', () => expect(event.title, 'Family Wedding'));
    test('occasion', () => expect(event.occasion, 'Wedding'));
    test('notes', () => expect(event.notes, 'Formal attire required'));
    test('outfitAssignments has 2 entries',
        () => expect(event.outfitAssignments, hasLength(2)));
    test('outfitAssignments profile-1 → outfit-a',
        () => expect(event.outfitAssignments['profile-1'], 'outfit-a'));
    test('outfitAssignments profile-2 → outfit-b',
        () => expect(event.outfitAssignments['profile-2'], 'outfit-b'));
    test('weatherSnapshot temp_c',
        () => expect(event.weatherSnapshot['temp_c'], 28.5));
    test('createdAt year', () => expect(event.createdAt.year, 2024));
  });

  // -------------------------------------------------------------------------
  group('CalendarEvent.fromJson — minimal payload', () {
    late CalendarEvent event;
    setUp(() => event = CalendarEvent.fromJson(_minimalJson()));

    test('occasion → null', () => expect(event.occasion, isNull));
    test('notes → null', () => expect(event.notes, isNull));
    test('outfitAssignments → empty map',
        () => expect(event.outfitAssignments, isEmpty));
    test('weatherSnapshot → empty map',
        () => expect(event.weatherSnapshot, isEmpty));
  });

  // -------------------------------------------------------------------------
  group('CalendarEvent._parseLocalDate — no UTC shift', () {
    test('event_date parses to correct year/month/day', () {
      final event = CalendarEvent.fromJson(_fullJson());
      expect(event.eventDate.year, 2024);
      expect(event.eventDate.month, 9);
      expect(event.eventDate.day, 15);
    });

    test('local midnight — hour is 0', () {
      final event = CalendarEvent.fromJson(_fullJson());
      expect(event.eventDate.hour, 0);
      expect(event.eventDate.minute, 0);
    });

    test('day-1 boundary date (2024-01-01)', () {
      final json = {..._minimalJson(), 'event_date': '2024-01-01'};
      final event = CalendarEvent.fromJson(json);
      expect(event.eventDate.day, 1);
      expect(event.eventDate.month, 1);
      expect(event.eventDate.year, 2024);
    });

    test('end-of-month date (2024-02-29 — leap year)', () {
      final json = {..._minimalJson(), 'event_date': '2024-02-29'};
      final event = CalendarEvent.fromJson(json);
      expect(event.eventDate.day, 29);
      expect(event.eventDate.month, 2);
    });

    test('toJson event_date is date-only string without time component', () {
      final json = _makeEvent(
        eventDate: DateTime(2024, 9, 15, 14, 30),
      ).toJson();
      expect(json['event_date'], '2024-09-15');
      expect((json['event_date'] as String).contains('T'), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('CalendarEvent.fromJson — outfitAssignments edge cases', () {
    test('null outfit_assignments → empty map', () {
      final json = {..._minimalJson(), 'outfit_assignments': null};
      expect(CalendarEvent.fromJson(json).outfitAssignments, isEmpty);
    });

    test('empty outfit_assignments map → empty', () {
      final json = {..._minimalJson(), 'outfit_assignments': <String, dynamic>{}};
      expect(CalendarEvent.fromJson(json).outfitAssignments, isEmpty);
    });

    test('all values coerced to String via toString()', () {
      final json = {
        ..._minimalJson(),
        'outfit_assignments': {'p1': 'outfit-x'},
      };
      final event = CalendarEvent.fromJson(json);
      expect(event.outfitAssignments['p1'], isA<String>());
    });

    test('multiple assignments round-trip correctly', () {
      final assignments = {
        'profile-1': 'outfit-a',
        'profile-2': 'outfit-b',
        'profile-3': 'outfit-c',
      };
      final json = {..._minimalJson(), 'outfit_assignments': assignments};
      final event = CalendarEvent.fromJson(json);
      expect(event.outfitAssignments, equals(assignments));
    });
  });

  // -------------------------------------------------------------------------
  group('CalendarEvent.toJson', () {
    test('required keys present', () {
      final json = _makeEvent().toJson();
      for (final key in ['id', 'household_id', 'title', 'event_date',
          'outfit_assignments', 'weather_snapshot', 'created_at']) {
        expect(json.containsKey(key), isTrue, reason: 'missing: $key');
      }
    });

    test('occasion omitted when null', () {
      expect(_makeEvent().toJson().containsKey('occasion'), isFalse);
    });

    test('occasion included when set', () {
      expect(_makeEvent(occasion: 'Party').toJson()['occasion'], 'Party');
    });

    test('notes omitted when null', () {
      expect(_makeEvent().toJson().containsKey('notes'), isFalse);
    });

    test('notes included when set', () {
      expect(_makeEvent(notes: 'Bring jacket').toJson()['notes'], 'Bring jacket');
    });

    test('outfit_assignments included even when empty', () {
      final json = _makeEvent().toJson();
      expect(json.containsKey('outfit_assignments'), isTrue);
      expect(json['outfit_assignments'], isEmpty);
    });

    test('outfit_assignments serialised correctly', () {
      final json = _makeEvent(
        outfitAssignments: {'p1': 'o1', 'p2': 'o2'},
      ).toJson();
      expect(json['outfit_assignments'], {'p1': 'o1', 'p2': 'o2'});
    });

    test('fromJson → toJson → fromJson roundtrip', () {
      final original = CalendarEvent.fromJson(_fullJson());
      final restored = CalendarEvent.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.occasion, original.occasion);
      expect(restored.notes, original.notes);
      expect(restored.outfitAssignments, original.outfitAssignments);
      expect(restored.eventDate.year, original.eventDate.year);
      expect(restored.eventDate.month, original.eventDate.month);
      expect(restored.eventDate.day, original.eventDate.day);
    });
  });

  // -------------------------------------------------------------------------
  group('CalendarEvent.copyWith — outfitAssignments mutations', () {
    test('adds outfit assignment via copyWith', () {
      final event = _makeEvent(outfitAssignments: {'p1': 'o1'});
      final updated = event.copyWith(
        outfitAssignments: {...event.outfitAssignments, 'p2': 'o2'},
      );
      expect(updated.outfitAssignments, {'p1': 'o1', 'p2': 'o2'});
    });

    test('removes outfit assignment via copyWith', () {
      final event = _makeEvent(
        outfitAssignments: {'p1': 'o1', 'p2': 'o2'},
      );
      final reduced = Map<String, String>.from(event.outfitAssignments)
        ..remove('p1');
      final updated = event.copyWith(outfitAssignments: reduced);
      expect(updated.outfitAssignments, hasLength(1));
      expect(updated.outfitAssignments.containsKey('p1'), isFalse);
    });

    test('replaces outfit assignment for same profile', () {
      final event = _makeEvent(outfitAssignments: {'p1': 'old-outfit'});
      final updated = event.copyWith(
        outfitAssignments: {'p1': 'new-outfit'},
      );
      expect(updated.outfitAssignments['p1'], 'new-outfit');
    });

    test('clears all assignments', () {
      final event = _makeEvent(outfitAssignments: {'p1': 'o1'});
      expect(event.copyWith(outfitAssignments: {}).outfitAssignments, isEmpty);
    });

    test('omitting outfitAssignments preserves existing', () {
      final event = _makeEvent(outfitAssignments: {'p1': 'o1'});
      expect(event.copyWith(title: 'New Title').outfitAssignments, {'p1': 'o1'});
    });

    test('updates title', () {
      expect(_makeEvent(title: 'Old').copyWith(title: 'New').title, 'New');
    });

    test('sets occasion', () {
      expect(_makeEvent().copyWith(occasion: 'Gala').occasion, 'Gala');
    });

    test('original is immutable — copyWith does not mutate source', () {
      final event = _makeEvent(outfitAssignments: {'p1': 'o1'});
      event.copyWith(outfitAssignments: {'p1': 'o1', 'p2': 'o2'});
      expect(event.outfitAssignments, hasLength(1));
    });
  });

  // -------------------------------------------------------------------------
  group('CalendarEvent equality and hashCode', () {
    test('same id → equal regardless of other fields', () {
      final a = _makeEvent(id: 'x', title: 'Alpha');
      final b = _makeEvent(id: 'x', title: 'Beta',
          outfitAssignments: {'p': 'o'});
      expect(a, equals(b));
    });

    test('different id → not equal', () {
      expect(_makeEvent(id: 'x'), isNot(equals(_makeEvent(id: 'y'))));
    });

    test('hashCode matches for same id', () {
      expect(_makeEvent(id: 'z').hashCode, _makeEvent(id: 'z').hashCode);
    });

    test('Set deduplicates by id', () {
      final a = _makeEvent(id: 'x', title: 'A');
      final b = _makeEvent(id: 'x', title: 'B');
      final c = _makeEvent(id: 'y');
      expect({a, b, c}.length, 2);
    });
  });
}
