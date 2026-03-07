// error_utils_test.dart
// Unit tests for userFriendlyError() — pure Dart, no Flutter required.

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_designer_assist/core/utils/error_utils.dart';

void main() {
  // -------------------------------------------------------------------------
  group('userFriendlyError — auth errors', () {
    test('email not confirmed', () {
      expect(
        userFriendlyError('AuthException: email not confirmed'),
        'Please confirm your email first.',
      );
    });

    test('email not confirmed — case insensitive', () {
      expect(
        userFriendlyError('Email Not Confirmed'),
        'Please confirm your email first.',
      );
    });

    test('invalid login credentials', () {
      expect(
        userFriendlyError('invalid login credentials'),
        'Incorrect email or password.',
      );
    });

    test('invalid login credentials — mixed case', () {
      expect(
        userFriendlyError('Invalid Login Credentials'),
        'Incorrect email or password.',
      );
    });

    test('user already registered', () {
      expect(
        userFriendlyError('user already registered'),
        'An account with this email already exists.',
      );
    });

    test('email rate limit', () {
      expect(
        userFriendlyError('email rate limit exceeded'),
        'Too many attempts. Please wait a moment.',
      );
    });
  });

  // -------------------------------------------------------------------------
  group('userFriendlyError — network errors', () {
    test('SocketException', () {
      expect(
        userFriendlyError('SocketException: connection refused'),
        'Network error — please check your connection.',
      );
    });

    test('network keyword', () {
      expect(
        userFriendlyError('network unavailable'),
        'Network error — please check your connection.',
      );
    });

    test('connection refused', () {
      expect(
        userFriendlyError('connection refused'),
        'Network error — please check your connection.',
      );
    });

    test('handshake failure', () {
      expect(
        userFriendlyError('TLS handshake error'),
        'Network error — please check your connection.',
      );
    });

    test('timeout', () {
      expect(
        userFriendlyError('timeout after 30 seconds'),
        'Request timed out. Please try again.',
      );
    });

    test('TimeoutException class name', () {
      expect(
        userFriendlyError('TimeoutException: Future not completed'),
        'Request timed out. Please try again.',
      );
    });
  });

  // -------------------------------------------------------------------------
  group('userFriendlyError — household errors', () {
    test('invite not found', () {
      expect(
        userFriendlyError('No household found for that invite code.'),
        'Invalid invite code.',
      );
    });

    test('invite code not found — alternate phrasing', () {
      expect(
        userFriendlyError('invite code not found in database'),
        'Invalid invite code.',
      );
    });
  });

  // -------------------------------------------------------------------------
  group('userFriendlyError — generic fallback', () {
    test('unknown exception → generic message', () {
      expect(
        userFriendlyError('some random internal error xyz'),
        'Something went wrong. Please try again.',
      );
    });

    test('empty string → generic message', () {
      expect(
        userFriendlyError(''),
        'Something went wrong. Please try again.',
      );
    });

    test('Exception object with known message', () {
      expect(
        userFriendlyError(Exception('email not confirmed')),
        'Please confirm your email first.',
      );
    });

    test('Exception object with unknown message → generic', () {
      expect(
        userFriendlyError(Exception('something completely unknown')),
        'Something went wrong. Please try again.',
      );
    });

    test('non-string non-Exception type → generic fallback', () {
      expect(
        userFriendlyError(42),
        'Something went wrong. Please try again.',
      );
    });

    test('null-like toString → generic fallback', () {
      expect(
        userFriendlyError(Object()),
        'Something went wrong. Please try again.',
      );
    });
  });

  // -------------------------------------------------------------------------
  group('userFriendlyError — never exposes raw details', () {
    test('internal stack trace keywords not surfaced', () {
      const rawError =
          'PostgrestException: duplicate key value violates unique constraint '
          '"profiles_auth_user_id_key" on table "profiles"';
      final friendly = userFriendlyError(rawError);
      expect(friendly, isNot(contains('PostgrestException')));
      expect(friendly, isNot(contains('profiles_auth_user_id')));
      expect(friendly, 'Something went wrong. Please try again.');
    });

    test('supabase URL not exposed', () {
      const rawError =
          'ClientException: https://xyz.supabase.co returned 500';
      final friendly = userFriendlyError(rawError);
      expect(friendly, isNot(contains('supabase.co')));
    });
  });
}
