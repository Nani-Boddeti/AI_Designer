// generated_outfit_parsing_test.dart
// Tests for the raw AI response → GeneratedOutfit parsing logic in
// OutfitRepository.generateOutfits. The algorithm is mirrored here so tests
// remain pure Dart and don't require Supabase/Gemini.

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_designer_assist/data/models/outfit.dart';
import 'package:ai_designer_assist/data/repositories/outfit_repository.dart';

// ---------------------------------------------------------------------------
// Mirror of the parsing algorithm (same as OutfitRepository.generateOutfits)
// ---------------------------------------------------------------------------

GeneratedOutfit _parse(Map<String, dynamic> raw, {String occasion = 'Wedding'}) {
  final profileId = raw['profile_id'] as String? ?? '';
  final profileName = raw['profile_name'] as String? ?? '';
  final rawItemIds = raw['item_ids'];
  final itemIds = rawItemIds is List
      ? rawItemIds.map((e) => e.toString()).toList()
      : <String>[];
  final note = raw['styling_note'] as String? ?? '';
  final harmonyScore = (raw['harmony_score'] as num?)?.toDouble() ?? 0.75;
  final variantNumber = (raw['variant_number'] as num?)?.toInt() ?? 1;

  final outfit = Outfit(
    id: 'test-id',
    profileId: profileId,
    name: '$profileName\'s $occasion Outfit',
    occasion: occasion,
    itemIds: itemIds,
    notes: note,
    isAiGenerated: true,
    createdAt: DateTime(2024),
  );

  return GeneratedOutfit(
    outfit: outfit,
    profileName: profileName,
    stylingNote: note,
    harmonyScore: harmonyScore,
    variantNumber: variantNumber,
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _fullRaw() => {
      'profile_id': 'profile-1',
      'profile_name': 'Alice',
      'item_ids': ['item-a', 'item-b', 'item-c'],
      'styling_note': 'Bold and chic.',
      'harmony_score': 0.92,
      'variant_number': 1,
    };

void main() {
  // ---------------------------------------------------------------------------
  group('GeneratedOutfit parsing — full payload', () {
    late GeneratedOutfit result;
    setUp(() => result = _parse(_fullRaw()));

    test('profileId extracted correctly', () {
      expect(result.outfit.profileId, 'profile-1');
    });

    test('profileName extracted correctly', () {
      expect(result.profileName, 'Alice');
    });

    test('itemIds extracted as list of strings', () {
      expect(result.outfit.itemIds, ['item-a', 'item-b', 'item-c']);
    });

    test('stylingNote extracted', () {
      expect(result.stylingNote, 'Bold and chic.');
    });

    test('harmonyScore extracted as double', () {
      expect(result.harmonyScore, closeTo(0.92, 0.001));
    });

    test('variantNumber extracted as int', () {
      expect(result.variantNumber, 1);
    });

    test('outfit name formatted correctly', () {
      expect(result.outfit.name, "Alice's Wedding Outfit");
    });

    test('outfit isAiGenerated is true', () {
      expect(result.outfit.isAiGenerated, isTrue);
    });

    test('outfit occasion matches parameter', () {
      expect(result.outfit.occasion, 'Wedding');
    });

    test('outfit notes matches styling_note', () {
      expect(result.outfit.notes, 'Bold and chic.');
    });
  });

  // ---------------------------------------------------------------------------
  group('GeneratedOutfit parsing — missing / null fields', () {
    test('missing profile_id → empty string', () {
      final raw = {..._fullRaw()}..remove('profile_id');
      expect(_parse(raw).outfit.profileId, '');
    });

    test('null profile_id → empty string', () {
      final raw = {..._fullRaw(), 'profile_id': null};
      expect(_parse(raw).outfit.profileId, '');
    });

    test('missing profile_name → empty string', () {
      final raw = {..._fullRaw()}..remove('profile_name');
      expect(_parse(raw).profileName, '');
    });

    test('null profile_name → empty string', () {
      final raw = {..._fullRaw(), 'profile_name': null};
      expect(_parse(raw).profileName, '');
    });

    test('missing styling_note → empty string', () {
      final raw = {..._fullRaw()}..remove('styling_note');
      expect(_parse(raw).stylingNote, '');
    });

    test('null styling_note → empty string', () {
      final raw = {..._fullRaw(), 'styling_note': null};
      expect(_parse(raw).stylingNote, '');
    });

    test('missing harmony_score → default 0.75', () {
      final raw = {..._fullRaw()}..remove('harmony_score');
      expect(_parse(raw).harmonyScore, closeTo(0.75, 0.001));
    });

    test('null harmony_score → default 0.75', () {
      final raw = {..._fullRaw(), 'harmony_score': null};
      expect(_parse(raw).harmonyScore, closeTo(0.75, 0.001));
    });

    test('missing variant_number → default 1', () {
      final raw = {..._fullRaw()}..remove('variant_number');
      expect(_parse(raw).variantNumber, 1);
    });

    test('null variant_number → default 1', () {
      final raw = {..._fullRaw(), 'variant_number': null};
      expect(_parse(raw).variantNumber, 1);
    });

    test('missing item_ids → empty list', () {
      final raw = {..._fullRaw()}..remove('item_ids');
      expect(_parse(raw).outfit.itemIds, isEmpty);
    });

    test('null item_ids → empty list', () {
      final raw = {..._fullRaw(), 'item_ids': null};
      expect(_parse(raw).outfit.itemIds, isEmpty);
    });

    test('item_ids is not a List → empty list', () {
      final raw = {..._fullRaw(), 'item_ids': 'item-a,item-b'};
      expect(_parse(raw).outfit.itemIds, isEmpty);
    });

    test('item_ids is int → empty list (not a list)', () {
      final raw = {..._fullRaw(), 'item_ids': 42};
      expect(_parse(raw).outfit.itemIds, isEmpty);
    });

    test('completely empty map → all defaults', () {
      final result = _parse({});
      expect(result.outfit.profileId, '');
      expect(result.profileName, '');
      expect(result.outfit.itemIds, isEmpty);
      expect(result.stylingNote, '');
      expect(result.harmonyScore, closeTo(0.75, 0.001));
      expect(result.variantNumber, 1);
    });
  });

  // ---------------------------------------------------------------------------
  group('GeneratedOutfit parsing — item_ids coercion', () {
    test('list of strings → preserved', () {
      final raw = {..._fullRaw(), 'item_ids': ['a', 'b', 'c']};
      expect(_parse(raw).outfit.itemIds, ['a', 'b', 'c']);
    });

    test('list with int elements → coerced to strings', () {
      final raw = {..._fullRaw(), 'item_ids': [1, 2, 3]};
      final ids = _parse(raw).outfit.itemIds;
      expect(ids, ['1', '2', '3']);
    });

    test('list with mixed types → all coerced to strings', () {
      final raw = {..._fullRaw(), 'item_ids': ['item-1', 42, true]};
      final ids = _parse(raw).outfit.itemIds;
      expect(ids, ['item-1', '42', 'true']);
    });

    test('empty list → empty itemIds', () {
      final raw = {..._fullRaw(), 'item_ids': <dynamic>[]};
      expect(_parse(raw).outfit.itemIds, isEmpty);
    });

    test('single item list', () {
      final raw = {..._fullRaw(), 'item_ids': ['only-item']};
      expect(_parse(raw).outfit.itemIds, ['only-item']);
    });
  });

  // ---------------------------------------------------------------------------
  group('GeneratedOutfit parsing — numeric type coercion', () {
    test('harmony_score as int → converted to double', () {
      final raw = {..._fullRaw(), 'harmony_score': 1};
      expect(_parse(raw).harmonyScore, isA<double>());
      expect(_parse(raw).harmonyScore, 1.0);
    });

    test('harmony_score 0.0 → 0.0', () {
      final raw = {..._fullRaw(), 'harmony_score': 0.0};
      expect(_parse(raw).harmonyScore, 0.0);
    });

    test('harmony_score 1.0 → 1.0', () {
      final raw = {..._fullRaw(), 'harmony_score': 1.0};
      expect(_parse(raw).harmonyScore, 1.0);
    });

    test('variant_number as double → converted to int', () {
      final raw = {..._fullRaw(), 'variant_number': 2.0};
      expect(_parse(raw).variantNumber, 2);
    });

    test('variant_number 2 → 2', () {
      final raw = {..._fullRaw(), 'variant_number': 2};
      expect(_parse(raw).variantNumber, 2);
    });
  });

  // ---------------------------------------------------------------------------
  group('GeneratedOutfit parsing — occasion in outfit name', () {
    test('occasion appears in outfit name', () {
      final result = _parse(_fullRaw(), occasion: 'Beach Day');
      expect(result.outfit.name, contains('Beach Day'));
    });

    test('profile name appears in outfit name', () {
      final result = _parse({..._fullRaw(), 'profile_name': 'Bob'});
      expect(result.outfit.name, contains('Bob'));
    });

    test('format: "<name>\'s <occasion> Outfit"', () {
      final result = _parse(
        {..._fullRaw(), 'profile_name': 'Carol'},
        occasion: 'Gala',
      );
      expect(result.outfit.name, "Carol's Gala Outfit");
    });

    test('empty profile_name → "\'s Occasion Outfit" still safe', () {
      final result = _parse(
        {..._fullRaw(), 'profile_name': ''},
        occasion: 'Party',
      );
      expect(result.outfit.name, "'s Party Outfit");
    });
  });

  // ---------------------------------------------------------------------------
  group('GeneratedOutfit fields consistency', () {
    test('stylingNote and outfit.notes are the same value', () {
      final result = _parse(_fullRaw());
      expect(result.stylingNote, result.outfit.notes);
    });

    test('profileName in result matches outfit.profileId source', () {
      final result = _parse(_fullRaw());
      expect(result.profileName, 'Alice');
      expect(result.outfit.profileId, 'profile-1');
    });

    test('variantNumber default=1 matches GeneratedOutfit default param', () {
      // Default constructor param for variantNumber is 1
      final g = GeneratedOutfit(
        outfit: Outfit(
          id: 'x',
          profileId: 'p',
          name: 'n',
          itemIds: const [],
          createdAt: DateTime(2024),
        ),
        profileName: 'Test',
        stylingNote: '',
        harmonyScore: 0.5,
      );
      expect(g.variantNumber, 1);
    });
  });
}
