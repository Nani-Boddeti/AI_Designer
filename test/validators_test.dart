// validators_test.dart
// Tests for the pure validator functions extracted from HouseholdSetupScreen.
// These are inline lambdas in the source — we mirror them exactly here.

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Mirror the exact validator lambdas from household_setup_screen.dart
// ---------------------------------------------------------------------------

/// Matches: (v) => (v?.trim().isEmpty ?? true) ? 'Enter a household name' : null
String? validateHouseholdName(String? v) =>
    (v?.trim().isEmpty ?? true) ? 'Enter a household name' : null;

/// Matches: (v) => (v?.trim().isEmpty ?? true) ? 'Enter your name' : null
String? validateProfileName(String? v) =>
    (v?.trim().isEmpty ?? true) ? 'Enter your name' : null;

/// Matches: (v) => (v?.trim().length ?? 0) != 8 ? 'Enter the 8-character code' : null
String? validateInviteCode(String? v) =>
    (v?.trim().length ?? 0) != 8 ? 'Enter the 8-character code' : null;

void main() {
  // -------------------------------------------------------------------------
  group('validateHouseholdName', () {
    test('null input → error', () {
      expect(validateHouseholdName(null), 'Enter a household name');
    });

    test('empty string → error', () {
      expect(validateHouseholdName(''), 'Enter a household name');
    });

    test('whitespace-only → error', () {
      expect(validateHouseholdName('   '), 'Enter a household name');
    });

    test('tab and newline whitespace → error', () {
      expect(validateHouseholdName('\t\n'), 'Enter a household name');
    });

    test('valid name → null (no error)', () {
      expect(validateHouseholdName('Smith Family'), isNull);
    });

    test('single character → valid', () {
      expect(validateHouseholdName('A'), isNull);
    });

    test('name with leading/trailing spaces → valid (trim leaves content)', () {
      expect(validateHouseholdName('  Smith  '), isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('validateProfileName', () {
    test('null input → error', () {
      expect(validateProfileName(null), 'Enter your name');
    });

    test('empty string → error', () {
      expect(validateProfileName(''), 'Enter your name');
    });

    test('whitespace-only → error', () {
      expect(validateProfileName('   '), 'Enter your name');
    });

    test('valid name → null (no error)', () {
      expect(validateProfileName('Sarah'), isNull);
    });

    test('single character → valid', () {
      expect(validateProfileName('S'), isNull);
    });

    test('name with surrounding spaces → valid', () {
      expect(validateProfileName('  Mike  '), isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('validateInviteCode', () {
    test('null → error (treated as 0-length)', () {
      expect(validateInviteCode(null), 'Enter the 8-character code');
    });

    test('empty string → error', () {
      expect(validateInviteCode(''), 'Enter the 8-character code');
    });

    test('7 characters → error', () {
      expect(validateInviteCode('ABC1234'), 'Enter the 8-character code');
    });

    test('exactly 8 characters → valid', () {
      expect(validateInviteCode('ABC12345'), isNull);
    });

    test('9 characters → error', () {
      expect(validateInviteCode('ABC123456'), 'Enter the 8-character code');
    });

    test('8 chars with leading space → error (trim reduces length to 7)', () {
      // ' ABC1234' trims to 'ABC1234' which is 7 chars → error
      expect(validateInviteCode(' ABC1234'), 'Enter the 8-character code');
    });

    test('8 chars with trailing space → error (trim reduces length to 7)', () {
      expect(validateInviteCode('ABC1234 '), 'Enter the 8-character code');
    });

    test('8 chars with leading AND trailing spaces → error (trims to 6)', () {
      // ' ABC123 ' trims to 'ABC123' (6 chars) → error
      expect(validateInviteCode(' ABC123 '), 'Enter the 8-character code');
    });

    test('all whitespace of length 8 → error (trims to empty, length 0)', () {
      expect(validateInviteCode('        '), 'Enter the 8-character code');
    });

    test('exactly 8 lowercase chars → valid', () {
      // Validator only checks length, not casing
      expect(validateInviteCode('abcdefgh'), isNull);
    });
  });
}
