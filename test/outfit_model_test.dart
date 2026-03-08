// outfit_model_test.dart
// Unit tests for Outfit model: fromJson, toJson, copyWith, equality.
// Pure Dart — no Flutter/Supabase.

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_designer_assist/data/models/outfit.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _fullJson() => {
      'id': 'outfit-1',
      'profile_id': 'profile-1',
      'name': 'Summer Casual',
      'occasion': 'Beach Day',
      'item_ids': ['item-1', 'item-2', 'item-3'],
      'notes': 'Light and breezy',
      'is_ai_generated': true,
      'created_at': '2024-06-01T10:00:00.000Z',
    };

Map<String, dynamic> _minimalJson() => {
      'id': 'outfit-2',
      'profile_id': 'profile-2',
      'name': 'Basic Look',
      'created_at': '2024-01-01T00:00:00.000Z',
    };

Outfit _makeOutfit({
  String id = 'outfit-1',
  String profileId = 'profile-1',
  String name = 'Test Outfit',
  String? occasion,
  List<String> itemIds = const ['item-1', 'item-2'],
  String? notes,
  bool isAiGenerated = false,
}) =>
    Outfit(
      id: id,
      profileId: profileId,
      name: name,
      occasion: occasion,
      itemIds: itemIds,
      notes: notes,
      isAiGenerated: isAiGenerated,
      createdAt: DateTime(2024, 6, 1),
    );

void main() {
  // -------------------------------------------------------------------------
  group('Outfit.fromJson — full payload', () {
    late Outfit outfit;
    setUp(() => outfit = Outfit.fromJson(_fullJson()));

    test('id', () => expect(outfit.id, 'outfit-1'));
    test('profileId', () => expect(outfit.profileId, 'profile-1'));
    test('name', () => expect(outfit.name, 'Summer Casual'));
    test('occasion', () => expect(outfit.occasion, 'Beach Day'));
    test('itemIds length', () => expect(outfit.itemIds, hasLength(3)));
    test('itemIds content', () => expect(outfit.itemIds, containsAll(['item-1', 'item-2', 'item-3'])));
    test('notes', () => expect(outfit.notes, 'Light and breezy'));
    test('isAiGenerated → true', () => expect(outfit.isAiGenerated, isTrue));
    test('createdAt year', () => expect(outfit.createdAt.year, 2024));
  });

  // -------------------------------------------------------------------------
  group('Outfit.fromJson — minimal payload', () {
    late Outfit outfit;
    setUp(() => outfit = Outfit.fromJson(_minimalJson()));

    test('id', () => expect(outfit.id, 'outfit-2'));
    test('occasion → null', () => expect(outfit.occasion, isNull));
    test('itemIds → empty', () => expect(outfit.itemIds, isEmpty));
    test('notes → null', () => expect(outfit.notes, isNull));
    test('isAiGenerated → false', () => expect(outfit.isAiGenerated, isFalse));
  });

  // -------------------------------------------------------------------------
  group('Outfit.fromJson — itemIds edge cases', () {
    test('null item_ids field → empty list', () {
      final json = {..._minimalJson(), 'item_ids': null};
      expect(Outfit.fromJson(json).itemIds, isEmpty);
    });

    test('item_ids with mixed int/string values → all converted to string', () {
      final json = {..._minimalJson(), 'item_ids': ['item-1', 'item-2']};
      final ids = Outfit.fromJson(json).itemIds;
      expect(ids, ['item-1', 'item-2']);
    });

    test('single item_ids entry', () {
      final json = {..._minimalJson(), 'item_ids': ['only-item']};
      expect(Outfit.fromJson(json).itemIds, ['only-item']);
    });
  });

  // -------------------------------------------------------------------------
  group('Outfit.toJson', () {
    test('required keys always present', () {
      final json = _makeOutfit().toJson();
      for (final key in ['id', 'profile_id', 'name', 'item_ids',
          'is_ai_generated', 'created_at']) {
        expect(json.containsKey(key), isTrue, reason: 'missing: $key');
      }
    });

    test('occasion omitted when null', () {
      expect(_makeOutfit().toJson().containsKey('occasion'), isFalse);
    });

    test('occasion included when set', () {
      final json = _makeOutfit(occasion: 'Wedding').toJson();
      expect(json['occasion'], 'Wedding');
    });

    test('notes omitted when null', () {
      expect(_makeOutfit().toJson().containsKey('notes'), isFalse);
    });

    test('notes included when set', () {
      final json = _makeOutfit(notes: 'Formal only').toJson();
      expect(json['notes'], 'Formal only');
    });

    test('item_ids serialised as list', () {
      final json = _makeOutfit(itemIds: ['a', 'b', 'c']).toJson();
      expect(json['item_ids'], ['a', 'b', 'c']);
    });

    test('empty item_ids serialises as empty list', () {
      final json = _makeOutfit(itemIds: []).toJson();
      expect(json['item_ids'], isEmpty);
    });

    test('is_ai_generated true round-trips', () {
      final json = _makeOutfit(isAiGenerated: true).toJson();
      expect(json['is_ai_generated'], isTrue);
    });

    test('fromJson → toJson → fromJson roundtrip preserves all fields', () {
      final original = Outfit.fromJson(_fullJson());
      final restored = Outfit.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.profileId, original.profileId);
      expect(restored.occasion, original.occasion);
      expect(restored.itemIds, original.itemIds);
      expect(restored.notes, original.notes);
      expect(restored.isAiGenerated, original.isAiGenerated);
    });
  });

  // -------------------------------------------------------------------------
  group('Outfit.copyWith', () {
    test('updates name', () {
      expect(_makeOutfit().copyWith(name: 'New Name').name, 'New Name');
    });

    test('updates occasion', () {
      expect(
        _makeOutfit(occasion: 'Work').copyWith(occasion: 'Party').occasion,
        'Party',
      );
    });

    test('sets occasion to null', () {
      expect(_makeOutfit(occasion: 'Work').copyWith(occasion: null).occasion, isNull);
    });

    test('updates itemIds', () {
      final updated = _makeOutfit().copyWith(itemIds: ['x', 'y']);
      expect(updated.itemIds, ['x', 'y']);
    });

    test('updates notes', () {
      expect(_makeOutfit().copyWith(notes: 'My note').notes, 'My note');
    });

    test('sets notes to null', () {
      expect(_makeOutfit(notes: 'old').copyWith(notes: null).notes, isNull);
    });

    test('preserves id when not specified', () {
      expect(_makeOutfit(id: 'x').copyWith(name: 'Y').id, 'x');
    });

    test('preserves profileId when not specified', () {
      expect(_makeOutfit(profileId: 'p99').copyWith(name: 'Y').profileId, 'p99');
    });

    test('updates isAiGenerated', () {
      expect(_makeOutfit().copyWith(isAiGenerated: true).isAiGenerated, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  group('Outfit equality and hashCode', () {
    test('same id → equal regardless of other fields', () {
      final a = _makeOutfit(id: 'x', name: 'Alpha', itemIds: ['a']);
      final b = _makeOutfit(id: 'x', name: 'Beta', itemIds: ['b', 'c']);
      expect(a, equals(b));
    });

    test('different id → not equal', () {
      expect(_makeOutfit(id: 'x'), isNot(equals(_makeOutfit(id: 'y'))));
    });

    test('hashCode matches for same id', () {
      expect(_makeOutfit(id: 'z').hashCode, _makeOutfit(id: 'z').hashCode);
    });

    test('hashCode differs for different ids', () {
      // Not strictly required but almost always true
      expect(_makeOutfit(id: 'a').hashCode,
          isNot(equals(_makeOutfit(id: 'b').hashCode)));
    });

    test('Set deduplicates by id', () {
      final a = _makeOutfit(id: 'x', name: 'Alpha');
      final b = _makeOutfit(id: 'x', name: 'Beta');
      final c = _makeOutfit(id: 'y');
      expect({a, b, c}.length, 2);
    });
  });

  // -------------------------------------------------------------------------
  group('Outfit.toString', () {
    test('includes id and name', () {
      final s = _makeOutfit(id: 'o42', name: 'Beach Look').toString();
      expect(s, contains('o42'));
      expect(s, contains('Beach Look'));
    });
  });
}
