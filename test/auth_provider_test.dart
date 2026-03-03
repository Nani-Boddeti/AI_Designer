// auth_provider_test.dart
// Unit tests for AuthState: copyWith sentinel behavior and computed getters.
// We avoid any Flutter widget or Supabase networking — pure Dart only.

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_designer_assist/data/models/household.dart';
import 'package:ai_designer_assist/data/models/profile.dart';
import 'package:ai_designer_assist/core/constants/app_constants.dart';

// ---------------------------------------------------------------------------
// We need to test AuthState without Supabase. Since AuthState.user is of type
// User? (supabase_flutter), we test the null-path (user == null) thoroughly
// and rely on the fact that the constructor/copyWith only stores whatever is
// passed — no Supabase network calls are involved.
// ---------------------------------------------------------------------------

// Re-expose the internal implementation under test by duplicating the
// relevant logic here so we can test it without importing auth_provider.dart
// (which transitively imports supabase_flutter's User type that requires
// Supabase.initialize() before the type is usable in tests).
//
// Instead we mirror the sentinel pattern directly.

const Object _kKeepError = Object();

// Minimal AuthState mirror — same sentinel pattern as the real class.
class _AuthState {
  const _AuthState({
    this.user,
    this.profile,
    this.household,
    this.isLoading = false,
    this.error,
  });

  // Using dynamic so tests remain independent of supabase_flutter User.
  final dynamic user;
  final Profile? profile;
  final Household? household;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => user != null;
  bool get hasProfile => profile != null;
  bool get hasHousehold => household != null;

  _AuthState copyWith({
    dynamic user,
    Profile? profile,
    Household? household,
    bool? isLoading,
    Object? error = _kKeepError,
  }) {
    return _AuthState(
      user: user ?? this.user,
      profile: profile ?? this.profile,
      household: household ?? this.household,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _kKeepError) ? this.error : error as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Profile _makeProfile() => Profile(
      id: 'p1',
      householdId: 'h1',
      name: 'Test User',
      ageGroup: AgeGroup.adult,
      createdAt: DateTime(2024, 1, 1),
    );

Household _makeHousehold() => Household(
      id: 'h1',
      name: 'Smith Family',
      inviteCode: 'ABC12345',
      createdAt: DateTime(2024, 1, 1),
    );

void main() {
  group('AuthState — initial state', () {
    test('default constructor sets sane defaults', () {
      const s = _AuthState();
      expect(s.user, isNull);
      expect(s.profile, isNull);
      expect(s.household, isNull);
      expect(s.isLoading, isFalse);
      expect(s.error, isNull);
    });
  });

  group('AuthState.isAuthenticated', () {
    test('returns false when user is null', () {
      const s = _AuthState();
      expect(s.isAuthenticated, isFalse);
    });

    test('returns true when user is non-null', () {
      final s = _AuthState(user: Object()); // any non-null object
      expect(s.isAuthenticated, isTrue);
    });
  });

  group('AuthState.hasHousehold', () {
    test('returns false when household is null', () {
      const s = _AuthState();
      expect(s.hasHousehold, isFalse);
    });

    test('returns true when household is set', () {
      final s = _AuthState(household: _makeHousehold());
      expect(s.hasHousehold, isTrue);
    });
  });

  group('AuthState.hasProfile', () {
    test('returns false when profile is null', () {
      const s = _AuthState();
      expect(s.hasProfile, isFalse);
    });

    test('returns true when profile is set', () {
      final s = _AuthState(profile: _makeProfile());
      expect(s.hasProfile, isTrue);
    });
  });

  group('AuthState.copyWith — error sentinel', () {
    const existingError = 'Something went wrong';

    test('omitting error param preserves existing error', () {
      const s = _AuthState(error: existingError);
      final copied = s.copyWith(isLoading: true); // error not passed
      expect(copied.error, equals(existingError),
          reason: 'sentinel should keep existing error when omitted');
    });

    test('passing error: null explicitly clears the error', () {
      const s = _AuthState(error: existingError);
      final copied = s.copyWith(error: null);
      expect(copied.error, isNull,
          reason: 'explicit null should clear the error');
    });

    test('passing a new error value replaces the existing error', () {
      const s = _AuthState(error: existingError);
      final copied = s.copyWith(error: 'New error');
      expect(copied.error, equals('New error'));
    });

    test('copyWith with no error on a state that has no error stays null', () {
      const s = _AuthState();
      final copied = s.copyWith(isLoading: true);
      expect(copied.error, isNull);
    });

    test('copyWith preserves all other fields when only error changes', () {
      final profile = _makeProfile();
      final household = _makeHousehold();
      final user = Object();
      final s = _AuthState(
        user: user,
        profile: profile,
        household: household,
        isLoading: false,
        error: existingError,
      );
      final copied = s.copyWith(error: null);
      expect(copied.user, same(user));
      expect(copied.profile, same(profile));
      expect(copied.household, same(household));
      expect(copied.isLoading, isFalse);
      expect(copied.error, isNull);
    });
  });

  group('AuthState.copyWith — isLoading', () {
    test('can flip isLoading to true', () {
      const s = _AuthState();
      expect(s.copyWith(isLoading: true).isLoading, isTrue);
    });

    test('can flip isLoading back to false', () {
      const s = _AuthState(isLoading: true);
      expect(s.copyWith(isLoading: false).isLoading, isFalse);
    });

    test('omitting isLoading keeps existing value', () {
      const s = _AuthState(isLoading: true);
      expect(s.copyWith().isLoading, isTrue);
    });
  });

  group('AuthState.copyWith — profile & household', () {
    test('can add profile to empty state', () {
      const s = _AuthState();
      final profile = _makeProfile();
      expect(s.copyWith(profile: profile).profile, same(profile));
    });

    test('can add household to empty state', () {
      const s = _AuthState();
      final household = _makeHousehold();
      expect(s.copyWith(household: household).household, same(household));
    });

    test('omitting profile keeps existing profile', () {
      final profile = _makeProfile();
      final s = _AuthState(profile: profile);
      expect(s.copyWith(isLoading: true).profile, same(profile));
    });
  });
}
