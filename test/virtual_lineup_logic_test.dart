// virtual_lineup_logic_test.dart
// Tests for the virtual lineup deduplication and maxItemCount logic.
//
// The VirtualLineupScreen groups GeneratedOutfit by profileId and picks
// the lowest variantNumber per profile. All columns share the same
// item-slot count (max across all profiles) so the lineup stays aligned.
// These tests validate that algorithm for all edge cases.

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_designer_assist/data/models/outfit.dart';
import 'package:ai_designer_assist/data/repositories/outfit_repository.dart';

// ---------------------------------------------------------------------------
// Mirror of the lineup logic (same algorithm as VirtualLineupScreen).
// Tests here protect against regressions if the widget logic changes.
// ---------------------------------------------------------------------------

List<GeneratedOutfit> dedupeByProfile(List<GeneratedOutfit> generated) {
  final perProfile = <String, GeneratedOutfit>{};
  for (final g in generated) {
    final existing = perProfile[g.outfit.profileId];
    if (existing == null || g.variantNumber < existing.variantNumber) {
      perProfile[g.outfit.profileId] = g;
    }
  }
  return perProfile.values.toList();
}

int computeMaxItemCount(List<GeneratedOutfit> lineup) =>
    lineup.map((g) => g.outfit.itemIds.length).fold(1, (a, b) => a > b ? a : b);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Outfit _outfit(String profileId, {List<String> itemIds = const []}) => Outfit(
      id: 'outfit-$profileId',
      profileId: profileId,
      name: 'Outfit for $profileId',
      itemIds: itemIds,
      createdAt: DateTime(2024),
    );

GeneratedOutfit _gen(
  String profileId, {
  int variant = 1,
  List<String> itemIds = const ['item-1', 'item-2'],
}) =>
    GeneratedOutfit(
      outfit: _outfit(profileId, itemIds: itemIds),
      profileName: 'Profile $profileId',
      stylingNote: '',
      harmonyScore: 0.8,
      variantNumber: variant,
    );

void main() {
  // -------------------------------------------------------------------------
  group('dedupeByProfile — single profile', () {
    test('single variant → kept as-is', () {
      final result = dedupeByProfile([_gen('p1', variant: 1)]);
      expect(result, hasLength(1));
      expect(result.first.outfit.profileId, 'p1');
    });

    test('two variants → variant 1 (lowest) is kept', () {
      final result = dedupeByProfile([
        _gen('p1', variant: 2),
        _gen('p1', variant: 1),
      ]);
      expect(result, hasLength(1));
      expect(result.first.variantNumber, 1);
    });

    test('only variant 2 present → variant 2 is kept', () {
      final result = dedupeByProfile([_gen('p1', variant: 2)]);
      expect(result, hasLength(1));
      expect(result.first.variantNumber, 2);
    });

    test('variant order in input does not matter — always picks lowest', () {
      final withV1First = dedupeByProfile([
        _gen('p1', variant: 1),
        _gen('p1', variant: 2),
      ]);
      final withV2First = dedupeByProfile([
        _gen('p1', variant: 2),
        _gen('p1', variant: 1),
      ]);
      expect(withV1First.first.variantNumber, 1);
      expect(withV2First.first.variantNumber, 1);
    });
  });

  // -------------------------------------------------------------------------
  group('dedupeByProfile — multiple profiles', () {
    test('two profiles, two variants each → two entries', () {
      final input = [
        _gen('p1', variant: 1),
        _gen('p1', variant: 2),
        _gen('p2', variant: 1),
        _gen('p2', variant: 2),
      ];
      expect(dedupeByProfile(input), hasLength(2));
    });

    test('each profile keeps its own lowest variant independently', () {
      final input = [
        _gen('p1', variant: 2),
        _gen('p1', variant: 1),
        _gen('p2', variant: 2), // p2 only has variant 2
      ];
      final result = dedupeByProfile(input);
      expect(result, hasLength(2));
      final p1 = result.firstWhere((g) => g.outfit.profileId == 'p1');
      final p2 = result.firstWhere((g) => g.outfit.profileId == 'p2');
      expect(p1.variantNumber, 1);
      expect(p2.variantNumber, 2);
    });

    test('three profiles, all with both variants → three entries', () {
      final input = [
        for (final p in ['p1', 'p2', 'p3']) ...[
          _gen(p, variant: 1),
          _gen(p, variant: 2),
        ]
      ];
      expect(dedupeByProfile(input), hasLength(3));
    });

    test('all profiles end up with variantNumber 1', () {
      final input = [
        for (final p in ['p1', 'p2', 'p3']) ...[
          _gen(p, variant: 1),
          _gen(p, variant: 2),
        ]
      ];
      final result = dedupeByProfile(input);
      expect(result.every((g) => g.variantNumber == 1), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  group('dedupeByProfile — edge cases', () {
    test('empty input → empty output', () {
      expect(dedupeByProfile([]), isEmpty);
    });

    test('each entry is a different profile → all kept', () {
      final input = ['p1', 'p2', 'p3', 'p4']
          .map((p) => _gen(p, variant: 1))
          .toList();
      expect(dedupeByProfile(input), hasLength(4));
    });

    test('result profileIds are unique', () {
      final input = [
        _gen('p1', variant: 1),
        _gen('p1', variant: 2),
        _gen('p2', variant: 1),
        _gen('p2', variant: 2),
      ];
      final ids = dedupeByProfile(input).map((g) => g.outfit.profileId).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  // -------------------------------------------------------------------------
  group('computeMaxItemCount — uniform column height', () {
    test('single profile, 3 items → 3', () {
      final lineup = [_gen('p1', itemIds: ['a', 'b', 'c'])];
      expect(computeMaxItemCount(lineup), 3);
    });

    test('two profiles same count → that count', () {
      final lineup = [
        _gen('p1', itemIds: ['a', 'b']),
        _gen('p2', itemIds: ['c', 'd']),
      ];
      expect(computeMaxItemCount(lineup), 2);
    });

    test('mixed counts → returns max', () {
      final lineup = [
        _gen('p1', itemIds: ['a']),
        _gen('p2', itemIds: ['b', 'c', 'd']),
        _gen('p3', itemIds: ['e', 'f']),
      ];
      expect(computeMaxItemCount(lineup), 3);
    });

    test('one profile has no items → min result is 1 (never 0)', () {
      final lineup = [_gen('p1', itemIds: [])];
      expect(computeMaxItemCount(lineup), greaterThanOrEqualTo(1));
    });

    test('all profiles have no items → minimum 1', () {
      final lineup = [
        _gen('p1', itemIds: []),
        _gen('p2', itemIds: []),
      ];
      expect(computeMaxItemCount(lineup), 1);
    });

    test('empty lineup → minimum 1 (no division by zero)', () {
      expect(computeMaxItemCount([]), 1);
    });

    test('large outfit (7 items) → 7', () {
      final lineup = [
        _gen('p1', itemIds: List.generate(7, (i) => 'item-$i')),
        _gen('p2', itemIds: ['a', 'b']),
      ];
      expect(computeMaxItemCount(lineup), 7);
    });

    test('single item outfits → 1', () {
      final lineup = [
        _gen('p1', itemIds: ['a']),
        _gen('p2', itemIds: ['b']),
        _gen('p3', itemIds: ['c']),
      ];
      expect(computeMaxItemCount(lineup), 1);
    });
  });

  // -------------------------------------------------------------------------
  group('dedupeByProfile + computeMaxItemCount — integration', () {
    test('2 members × 2 variants: deduped to 2, maxItems from variant 1s', () {
      final raw = [
        _gen('p1', variant: 1, itemIds: ['a', 'b', 'c']),
        _gen('p1', variant: 2, itemIds: ['d']),
        _gen('p2', variant: 1, itemIds: ['e', 'f']),
        _gen('p2', variant: 2, itemIds: ['g', 'h', 'i', 'j']),
      ];
      final lineup = dedupeByProfile(raw);
      expect(lineup, hasLength(2));
      // After dedup: p1 has 3 items (v1), p2 has 2 items (v1) → max = 3
      expect(computeMaxItemCount(lineup), 3);
    });

    test('one member has more items than others — maxItemCount drives layout', () {
      final raw = [
        _gen('p1', variant: 1, itemIds: ['a']),
        _gen('p1', variant: 2, itemIds: ['b', 'c']),
        _gen('p2', variant: 1, itemIds: ['d', 'e', 'f', 'g']),
        _gen('p2', variant: 2, itemIds: ['h']),
      ];
      final lineup = dedupeByProfile(raw);
      // p1 v1 has 1 item, p2 v1 has 4 items → max = 4
      expect(computeMaxItemCount(lineup), 4);
    });

    test('single member session — dedupes to 1 entry', () {
      final raw = [
        _gen('p1', variant: 1, itemIds: ['a', 'b']),
        _gen('p1', variant: 2, itemIds: ['c']),
      ];
      final lineup = dedupeByProfile(raw);
      expect(lineup, hasLength(1));
      expect(computeMaxItemCount(lineup), 2);
    });
  });
}
