// usage_state_test.dart
// Unit tests for UsageState: remaining, canGenerate.
// Also covers email validation regex mirrored from auth_screen.dart.
// Pure Dart — no Flutter/Supabase/Riverpod.

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_designer_assist/presentation/providers/usage_provider.dart';
import 'package:ai_designer_assist/core/constants/app_constants.dart';

// Mirror of the email validation regex used in auth_screen.dart.
bool isValidEmail(String v) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());

void main() {
  // -------------------------------------------------------------------------
  group('UsageState — default constructor', () {
    test('count defaults to 0', () {
      expect(const UsageState().count, 0);
    });

    test('limit defaults to freeHouseholdLimit (15)', () {
      expect(const UsageState().limit, TierLimits.freeHouseholdLimit);
    });

    test('canGenerate is true when count == 0', () {
      expect(const UsageState().canGenerate, isTrue);
    });

    test('remaining equals limit when count == 0', () {
      const s = UsageState();
      expect(s.remaining, s.limit);
    });
  });

  // -------------------------------------------------------------------------
  group('UsageState.canGenerate', () {
    test('true when count < limit', () {
      expect(const UsageState(count: 0, limit: 15).canGenerate, isTrue);
    });

    test('true when count is 1 below limit', () {
      expect(const UsageState(count: 14, limit: 15).canGenerate, isTrue);
    });

    test('false when count equals limit', () {
      expect(const UsageState(count: 15, limit: 15).canGenerate, isFalse);
    });

    test('false when count exceeds limit (defensive)', () {
      expect(const UsageState(count: 20, limit: 15).canGenerate, isFalse);
    });

    test('false for pro user at pro limit', () {
      expect(
        const UsageState(count: 50, limit: 50).canGenerate,
        isFalse,
      );
    });

    test('true for pro user with remaining suggestions', () {
      expect(
        const UsageState(count: 49, limit: 50).canGenerate,
        isTrue,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('UsageState.remaining', () {
    test('remaining = limit - count when positive', () {
      expect(const UsageState(count: 5, limit: 15).remaining, 10);
    });

    test('remaining = 0 when count == limit', () {
      expect(const UsageState(count: 15, limit: 15).remaining, 0);
    });

    test('remaining clamped to 0 when count exceeds limit', () {
      // clamp prevents negative remaining
      expect(const UsageState(count: 20, limit: 15).remaining, 0);
    });

    test('remaining clamped to limit maximum (count < 0 edge case)', () {
      // clamp(0, limit) caps at limit
      expect(const UsageState(count: 0, limit: 50).remaining, 50);
    });

    test('remaining for prime user (200 limit)', () {
      expect(const UsageState(count: 180, limit: 200).remaining, 20);
    });
  });

  // -------------------------------------------------------------------------
  group('UsageState — boundary: count == 0', () {
    test('count 0, limit 15 → canGenerate true, remaining 15', () {
      const s = UsageState(count: 0, limit: 15);
      expect(s.canGenerate, isTrue);
      expect(s.remaining, 15);
    });
  });

  // -------------------------------------------------------------------------
  group('UsageState — boundary: exactly at limit', () {
    for (final limit in [15, 50, 200]) {
      test('count == limit ($limit) → canGenerate false, remaining 0', () {
        final s = UsageState(count: limit, limit: limit);
        expect(s.canGenerate, isFalse);
        expect(s.remaining, 0);
      });
    }
  });

  // -------------------------------------------------------------------------
  group('Email validation regex (mirrored from auth_screen.dart)', () {
    group('valid emails', () {
      final valid = [
        'user@example.com',
        'user.name@domain.co',
        'user+tag@example.org',
        'u@a.io',
        'test123@sub.domain.com',
        '  user@example.com  ', // leading/trailing spaces trimmed
      ];
      for (final email in valid) {
        test('"$email" is valid', () => expect(isValidEmail(email), isTrue));
      }
    });

    group('invalid emails', () {
      final invalid = [
        '',
        'notanemail',
        '@nodomain.com',
        'noatsign',
        'missing@tld',
        'spaces in@email.com',
        'double@@domain.com',
        'user@',
        '@',
        'user @example.com', // space before @
        'user@ example.com', // space after @
      ];
      for (final email in invalid) {
        test('"$email" is invalid', () => expect(isValidEmail(email), isFalse));
      }
    });
  });
}
