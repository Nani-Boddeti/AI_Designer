// household_model_test.dart
// Unit tests for Household model: subscription getters, fromJson/toJson,
// copyWith sentinel, and equality. Pure Dart — no Flutter/Supabase.

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_designer_assist/data/models/household.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Household _base({
  String tier = 'free',
  DateTime? tierExpiresAt,
  bool dynamicPricing = true,
}) =>
    Household(
      id: 'h1',
      name: 'Test Family',
      inviteCode: 'ABC12345',
      tier: tier,
      tierExpiresAt: tierExpiresAt,
      createdAt: DateTime(2024, 1, 1),
      dynamicPricing: dynamicPricing,
    );

final _future = DateTime.now().add(const Duration(days: 30));
final _past = DateTime.now().subtract(const Duration(days: 1));

void main() {
  // -------------------------------------------------------------------------
  group('Household.isProActive', () {
    test('free tier → false', () {
      expect(_base().isProActive, isFalse);
    });

    test('pro tier, no expiry → false', () {
      expect(_base(tier: 'pro').isProActive, isFalse);
    });

    test('pro tier, future expiry → true', () {
      expect(_base(tier: 'pro', tierExpiresAt: _future).isProActive, isTrue);
    });

    test('pro tier, past expiry → false', () {
      expect(_base(tier: 'pro', tierExpiresAt: _past).isProActive, isFalse);
    });

    test('prime tier, future expiry → false (wrong tier)', () {
      expect(
        _base(tier: 'prime', tierExpiresAt: _future).isProActive,
        isFalse,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('Household.isPrimeActive', () {
    test('free tier → false', () {
      expect(_base().isPrimeActive, isFalse);
    });

    test('prime tier, no expiry → false', () {
      expect(_base(tier: 'prime').isPrimeActive, isFalse);
    });

    test('prime tier, future expiry → true', () {
      expect(
        _base(tier: 'prime', tierExpiresAt: _future).isPrimeActive,
        isTrue,
      );
    });

    test('prime tier, past expiry → false', () {
      expect(
        _base(tier: 'prime', tierExpiresAt: _past).isPrimeActive,
        isFalse,
      );
    });

    test('pro tier, future expiry → false (wrong tier)', () {
      expect(
        _base(tier: 'pro', tierExpiresAt: _future).isPrimeActive,
        isFalse,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('Household.isSubscribed', () {
    test('free → false', () {
      expect(_base().isSubscribed, isFalse);
    });

    test('active pro → true', () {
      expect(
        _base(tier: 'pro', tierExpiresAt: _future).isSubscribed,
        isTrue,
      );
    });

    test('active prime → true', () {
      expect(
        _base(tier: 'prime', tierExpiresAt: _future).isSubscribed,
        isTrue,
      );
    });

    test('expired pro → false', () {
      expect(
        _base(tier: 'pro', tierExpiresAt: _past).isSubscribed,
        isFalse,
      );
    });

    test('expired prime → false', () {
      expect(
        _base(tier: 'prime', tierExpiresAt: _past).isSubscribed,
        isFalse,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('Household.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'id': 'h2',
        'name': 'Smith Family',
        'invite_code': 'XY345678',
        'hemisphere': 'south',
        'tier': 'pro',
        'tier_expires_at': _future.toIso8601String(),
        'created_at': '2024-03-01T00:00:00.000Z',
        'dynamic_pricing': false,
      };
      final h = Household.fromJson(json);
      expect(h.id, 'h2');
      expect(h.name, 'Smith Family');
      expect(h.inviteCode, 'XY345678');
      expect(h.hemisphere, 'south');
      expect(h.tier, 'pro');
      expect(h.tierExpiresAt, isNotNull);
      expect(h.dynamicPricing, isFalse);
    });

    test('missing optional fields default correctly', () {
      final json = {
        'id': 'h3',
        'name': 'Minimal',
        'invite_code': 'MIN12345',
        'created_at': '2024-01-01T00:00:00.000Z',
      };
      final h = Household.fromJson(json);
      expect(h.hemisphere, 'north');
      expect(h.tier, 'free');
      expect(h.tierExpiresAt, isNull);
      expect(h.dynamicPricing, isTrue);
    });

    test('null tier_expires_at → tierExpiresAt is null', () {
      final json = {
        'id': 'h4',
        'name': 'No Expiry',
        'invite_code': 'NOEXP123',
        'tier': 'pro',
        'tier_expires_at': null,
        'created_at': '2024-01-01T00:00:00.000Z',
      };
      final h = Household.fromJson(json);
      expect(h.tierExpiresAt, isNull);
      expect(h.isProActive, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('Household.toJson roundtrip', () {
    test('fromJson → toJson → fromJson produces equivalent object', () {
      final original = _base(tier: 'prime', tierExpiresAt: _future);
      final json = original.toJson();
      final restored = Household.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.tier, original.tier);
      expect(restored.dynamicPricing, original.dynamicPricing);
      expect(restored.isPrimeActive, original.isPrimeActive);
    });

    test('toJson includes all expected keys', () {
      final json = _base().toJson();
      expect(json.containsKey('id'), isTrue);
      expect(json.containsKey('name'), isTrue);
      expect(json.containsKey('invite_code'), isTrue);
      expect(json.containsKey('hemisphere'), isTrue);
      expect(json.containsKey('tier'), isTrue);
      expect(json.containsKey('tier_expires_at'), isTrue);
      expect(json.containsKey('created_at'), isTrue);
      expect(json.containsKey('dynamic_pricing'), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  group('Household.copyWith — tierExpiresAt sentinel', () {
    test('omitting tierExpiresAt keeps existing value', () {
      final h = _base(tier: 'pro', tierExpiresAt: _future);
      final copied = h.copyWith(name: 'New Name');
      expect(copied.tierExpiresAt, equals(h.tierExpiresAt));
    });

    test('passing tierExpiresAt: null explicitly clears it', () {
      final h = _base(tier: 'pro', tierExpiresAt: _future);
      final copied = h.copyWith(tierExpiresAt: null);
      expect(copied.tierExpiresAt, isNull);
      expect(copied.isProActive, isFalse);
    });

    test('passing new DateTime replaces existing', () {
      final h = _base(tier: 'pro', tierExpiresAt: _past);
      final copied = h.copyWith(tierExpiresAt: _future);
      expect(copied.isProActive, isTrue);
    });

    test('copyWith preserves unrelated fields', () {
      final h = _base(tier: 'prime', tierExpiresAt: _future);
      final copied = h.copyWith(name: 'New Family');
      expect(copied.tier, 'prime');
      expect(copied.tierExpiresAt, equals(_future));
      expect(copied.isPrimeActive, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  group('Household equality and hashCode', () {
    test('same id → equal', () {
      final a = _base();
      final b = _base(tier: 'pro', tierExpiresAt: _future);
      // Both have id 'h1'
      expect(a, equals(b));
    });

    test('different id → not equal', () {
      final a = Household(
        id: 'h1', name: 'A', inviteCode: 'CODE0001', createdAt: DateTime(2024),
      );
      final b = Household(
        id: 'h2', name: 'A', inviteCode: 'CODE0001', createdAt: DateTime(2024),
      );
      expect(a, isNot(equals(b)));
    });

    test('hashCode equals for same id', () {
      final a = _base();
      final b = _base(tier: 'pro');
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  // -------------------------------------------------------------------------
  group('Household.toString', () {
    test('does not include household name (PII)', () {
      final h = _base();
      expect(h.toString(), isNot(contains('Test Family')));
    });

    test('includes id and tier', () {
      final h = _base(tier: 'pro');
      expect(h.toString(), contains('h1'));
      expect(h.toString(), contains('pro'));
    });
  });
}
