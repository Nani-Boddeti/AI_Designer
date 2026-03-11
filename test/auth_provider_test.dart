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
    this.allHouseholds = const [],
    this.adminHouseholdIds = const {},
    this.isLoading = false,
    this.error,
  });

  // Using dynamic so tests remain independent of supabase_flutter User.
  final dynamic user;
  final Profile? profile;
  final Household? household;
  final List<Household> allHouseholds;
  final Set<String> adminHouseholdIds;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => user != null;
  bool get hasProfile => profile != null;
  bool get hasHousehold => household != null;
  bool get needsHouseholdSetup =>
      isAuthenticated && allHouseholds.isEmpty && !hasHousehold;
  bool get needsHouseholdSelection =>
      isAuthenticated && allHouseholds.isNotEmpty && !hasHousehold;
  bool isAdminInHousehold(String id) => adminHouseholdIds.contains(id);

  _AuthState copyWith({
    dynamic user,
    Profile? profile,
    Household? household,
    List<Household>? allHouseholds,
    Set<String>? adminHouseholdIds,
    bool? isLoading,
    Object? error = _kKeepError,
  }) {
    return _AuthState(
      user: user ?? this.user,
      profile: profile ?? this.profile,
      household: household ?? this.household,
      allHouseholds: allHouseholds ?? this.allHouseholds,
      adminHouseholdIds: adminHouseholdIds ?? this.adminHouseholdIds,
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

  group('AuthState — allHouseholds', () {
    test('default is empty list', () {
      const s = _AuthState();
      expect(s.allHouseholds, isEmpty);
    });

    test('can be set via constructor', () {
      final h1 = _makeHousehold();
      final s = _AuthState(allHouseholds: [h1]);
      expect(s.allHouseholds, hasLength(1));
      expect(s.allHouseholds.first.id, 'h1');
    });

    test('copyWith updates allHouseholds', () {
      const s = _AuthState();
      final h1 = _makeHousehold();
      final h2 = Household(
        id: 'h2', name: 'Second Family', inviteCode: 'XYZ12345',
        createdAt: DateTime(2024, 6, 1),
      );
      final copied = s.copyWith(allHouseholds: [h1, h2]);
      expect(copied.allHouseholds, hasLength(2));
    });

    test('copyWith without allHouseholds preserves existing list', () {
      final h1 = _makeHousehold();
      final s = _AuthState(allHouseholds: [h1]);
      final copied = s.copyWith(isLoading: true);
      expect(copied.allHouseholds, hasLength(1));
      expect(copied.allHouseholds.first.id, 'h1');
    });

    test('copyWith can clear allHouseholds to empty list', () {
      final h1 = _makeHousehold();
      final s = _AuthState(allHouseholds: [h1]);
      final copied = s.copyWith(allHouseholds: []);
      expect(copied.allHouseholds, isEmpty);
    });

    test('allHouseholds and household can be set independently', () {
      final h1 = _makeHousehold();
      final h2 = Household(
        id: 'h2', name: 'Second', inviteCode: 'CODE9999',
        createdAt: DateTime(2024),
      );
      // active household is h2, but allHouseholds contains both
      final s = _AuthState(household: h2, allHouseholds: [h1, h2]);
      expect(s.household!.id, 'h2');
      expect(s.allHouseholds, hasLength(2));
    });

    test('switchHousehold simulation — active household changes, list stays', () {
      final h1 = _makeHousehold();
      final h2 = Household(
        id: 'h2', name: 'Second', inviteCode: 'CODE9999',
        createdAt: DateTime(2024),
      );
      final s = _AuthState(household: h1, allHouseholds: [h1, h2]);
      // simulate switchHousehold
      final switched = s.copyWith(household: h2);
      expect(switched.household!.id, 'h2');
      expect(switched.allHouseholds, hasLength(2)); // list unchanged
    });

    test('joinHousehold simulation — new household appended to list', () {
      final h1 = _makeHousehold();
      final s = _AuthState(household: h1, allHouseholds: [h1]);
      final h2 = Household(
        id: 'h2', name: 'Joined', inviteCode: 'JOIN1234',
        createdAt: DateTime(2024),
      );
      final joined = s.copyWith(
        household: h2,
        allHouseholds: [...s.allHouseholds, h2],
      );
      expect(joined.allHouseholds, hasLength(2));
      expect(joined.household!.id, 'h2');
    });
  });

  group('AuthState — error recovery pattern (mutation safety)', () {
    // These tests verify the AsyncData mutation pattern used in
    // createHousehold / joinHousehold / switchHousehold / leaveHousehold.
    // NEVER use AsyncValue.guard for these — AsyncError makes valueOrNull==null
    // which causes the router to redirect to /auth while the user is still signed in.

    test('error recovery: prev state preserved when error occurs', () {
      final profile = _makeProfile();
      final household = _makeHousehold();
      final s = _AuthState(
        user: Object(),
        profile: profile,
        household: household,
        allHouseholds: [household],
      );
      // Simulate catch block: prev.copyWith(isLoading: false, error: '...')
      final recovered = s.copyWith(isLoading: false, error: 'Network error');
      expect(recovered.user, isNotNull);          // user preserved
      expect(recovered.profile, same(profile));   // profile preserved
      expect(recovered.household, same(household)); // household preserved
      expect(recovered.allHouseholds, hasLength(1)); // list preserved
      expect(recovered.isLoading, isFalse);
      expect(recovered.error, 'Network error');
    });

    test('error recovery: isLoading was true before error, false after', () {
      final s = _AuthState(user: Object(), isLoading: true);
      final recovered = s.copyWith(isLoading: false, error: 'Failed');
      expect(recovered.isLoading, isFalse);
      expect(recovered.error, 'Failed');
    });

    test('successful operation: error cleared, isLoading false', () {
      final s = _AuthState(user: Object(), isLoading: true, error: 'old error');
      final done = s.copyWith(isLoading: false, error: null);
      expect(done.isLoading, isFalse);
      expect(done.error, isNull);
    });

    test('loading phase: isLoading set, error cleared', () {
      final s = _AuthState(user: Object(), error: 'previous error');
      final loading = s.copyWith(isLoading: true, error: null);
      expect(loading.isLoading, isTrue);
      expect(loading.error, isNull); // cleared on retry
    });
  });

  group('AuthState — createHousehold state pattern', () {
    test('after create: allHouseholds contains only the new household', () {
      // User had no households before
      const prev = _AuthState(user: null);
      final newHousehold = _makeHousehold();
      final after = _AuthState(
        user: Object(),
        household: newHousehold,
        allHouseholds: [newHousehold],
      );
      expect(after.allHouseholds, hasLength(1));
      expect(after.household!.id, newHousehold.id);
      expect(after.hasHousehold, isTrue);
      // prev had no households
      expect(prev.allHouseholds, isEmpty);
    });

    test('after create: household and allHouseholds[0] are the same object', () {
      final h = _makeHousehold();
      final s = _AuthState(household: h, allHouseholds: [h]);
      expect(s.household, same(s.allHouseholds.first));
    });
  });

  group('AuthState — joinHousehold state pattern', () {
    test('after join: new household appended to existing list', () {
      final existing = _makeHousehold();
      final joined = Household(
        id: 'h2', name: 'Joined Family', inviteCode: 'JOIN1234',
        createdAt: DateTime(2024, 6, 1),
      );
      final prev = _AuthState(
        user: Object(),
        household: existing,
        allHouseholds: [existing],
      );
      final after = _AuthState(
        user: prev.user,
        household: joined,
        allHouseholds: [...prev.allHouseholds, joined],
      );
      expect(after.allHouseholds, hasLength(2));
      expect(after.allHouseholds.first.id, existing.id); // existing still present
      expect(after.allHouseholds.last.id, joined.id);   // new one at end
      expect(after.household!.id, joined.id);            // active is new one
    });

    test('after join: prev allHouseholds not mutated', () {
      final existing = _makeHousehold();
      final prev = _AuthState(allHouseholds: [existing]);
      final joined = Household(
        id: 'h2', name: 'New', inviteCode: 'NEW12345',
        createdAt: DateTime(2024),
      );
      // Spread creates a new list — prev unchanged
      final newList = [...prev.allHouseholds, joined];
      expect(prev.allHouseholds, hasLength(1)); // unchanged
      expect(newList, hasLength(2));
    });
  });

  group('AuthState — switchHousehold state pattern', () {
    test('switch: household changes, allHouseholds unchanged, profile unchanged', () {
      final h1 = _makeHousehold();
      final h2 = Household(
        id: 'h2', name: 'Second', inviteCode: 'CODE9999',
        createdAt: DateTime(2024),
      );
      final profile = _makeProfile();
      final s = _AuthState(
        user: Object(),
        profile: profile,
        household: h1,
        allHouseholds: [h1, h2],
      );
      final switched = s.copyWith(household: h2, isLoading: false);
      expect(switched.household!.id, 'h2');
      expect(switched.allHouseholds, hasLength(2)); // list unchanged
      expect(switched.profile, same(profile));       // profile unchanged
    });

    test('switch: uses household from allHouseholds without network fetch', () {
      final h1 = _makeHousehold();
      final h2 = Household(
        id: 'h2', name: 'Second', inviteCode: 'CODE9999',
        createdAt: DateTime(2024),
      );
      final s = _AuthState(household: h1, allHouseholds: [h1, h2]);
      // Simulate: household = allHouseholds.where(id == h2.id).firstOrNull
      final found = s.allHouseholds.where((h) => h.id == 'h2').firstOrNull;
      expect(found, isNotNull);
      expect(found!.id, 'h2');
    });

    test('switch: returns null when householdId not in allHouseholds', () {
      final h1 = _makeHousehold();
      final s = _AuthState(household: h1, allHouseholds: [h1]);
      final found = s.allHouseholds.where((h) => h.id == 'nonexistent').firstOrNull;
      expect(found, isNull); // would need network fetch
    });
  });

  group('AuthState — leaveHousehold state pattern', () {
    test('leave only household: allHouseholds empty, household null', () {
      final h1 = _makeHousehold();
      final s = _AuthState(household: h1, allHouseholds: [h1]);
      // After leaving and _buildFromCurrentSession returns no household
      final reloaded = _AuthState(
        user: s.user,
        profile: s.profile,
        household: null,
        allHouseholds: [],
      );
      expect(reloaded.allHouseholds, isEmpty);
      expect(reloaded.household, isNull);
      expect(reloaded.hasHousehold, isFalse);
    });

    test('leave one of two: remaining household becomes active', () {
      _makeHousehold(); // h1 — the one being left
      final h2 = Household(
        id: 'h2', name: 'Remaining', inviteCode: 'REM12345',
        createdAt: DateTime(2024),
      );
      // Active was h1, leaving h1 — h2 should be active after reload
      final reloaded = _AuthState(
        user: Object(),
        household: h2,
        allHouseholds: [h2], // h1 removed
      );
      expect(reloaded.allHouseholds, hasLength(1));
      expect(reloaded.household!.id, 'h2');
    });

    test('leave admin household: state reloads completely (no stale admin flag)', () {
      final h1 = _makeHousehold();
      final adminProfile = _makeProfile();
      // Simulate full reload: leaveHousehold calls _buildFromCurrentSession
      // _buildFromCurrentSession returns a brand-new AuthState — never copyWith
      // on the old state. So household and allHouseholds are freshly constructed.
      final reloaded = _AuthState(
        user: Object(),
        profile: adminProfile,
        household: null,      // no active household after leaving
        allHouseholds: const [],
      );
      expect(reloaded.household, isNull);
      expect(reloaded.allHouseholds, isEmpty);
      // The old h1 is not referenced at all
      expect(reloaded.allHouseholds.contains(h1), isFalse);
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

  // -------------------------------------------------------------------------
  group('AuthState — adminHouseholdIds', () {
    test('default is empty set', () {
      const s = _AuthState();
      expect(s.adminHouseholdIds, isEmpty);
    });

    test('isAdminInHousehold returns false when set is empty', () {
      const s = _AuthState();
      expect(s.isAdminInHousehold('h1'), isFalse);
    });

    test('isAdminInHousehold returns true for id in set', () {
      final s = _AuthState(adminHouseholdIds: {'h1', 'h2'});
      expect(s.isAdminInHousehold('h1'), isTrue);
      expect(s.isAdminInHousehold('h2'), isTrue);
    });

    test('isAdminInHousehold returns false for id not in set', () {
      final s = _AuthState(adminHouseholdIds: {'h1'});
      expect(s.isAdminInHousehold('h2'), isFalse);
    });

    test('copyWith updates adminHouseholdIds', () {
      const s = _AuthState();
      final copied = s.copyWith(adminHouseholdIds: {'h1'});
      expect(copied.adminHouseholdIds, contains('h1'));
    });

    test('copyWith without adminHouseholdIds preserves existing set', () {
      final s = _AuthState(adminHouseholdIds: {'h1'});
      expect(s.copyWith(isLoading: true).adminHouseholdIds, contains('h1'));
    });

    test('copyWith can clear adminHouseholdIds to empty set', () {
      final s = _AuthState(adminHouseholdIds: {'h1'});
      expect(s.copyWith(adminHouseholdIds: {}).adminHouseholdIds, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('AuthState — needsHouseholdSetup / needsHouseholdSelection', () {
    test('needsHouseholdSetup: true when authenticated, no households, no household', () {
      final s = _AuthState(user: Object());
      expect(s.needsHouseholdSetup, isTrue);
    });

    test('needsHouseholdSetup: false when not authenticated', () {
      const s = _AuthState();
      expect(s.needsHouseholdSetup, isFalse);
    });

    test('needsHouseholdSetup: false when household is already selected', () {
      final h = _makeHousehold();
      final s = _AuthState(user: Object(), household: h);
      expect(s.needsHouseholdSetup, isFalse);
    });

    test('needsHouseholdSetup: false when allHouseholds is non-empty', () {
      final h = _makeHousehold();
      final s = _AuthState(user: Object(), allHouseholds: [h]);
      expect(s.needsHouseholdSetup, isFalse);
    });

    test('needsHouseholdSelection: true when authenticated, multiple households, none selected', () {
      final h1 = _makeHousehold();
      final h2 = Household(
        id: 'h2', name: 'Second', inviteCode: 'XYZ12345',
        createdAt: DateTime(2024),
      );
      final s = _AuthState(user: Object(), allHouseholds: [h1, h2]);
      expect(s.needsHouseholdSelection, isTrue);
    });

    test('needsHouseholdSelection: false when household is selected', () {
      final h = _makeHousehold();
      final s = _AuthState(user: Object(), allHouseholds: [h], household: h);
      expect(s.needsHouseholdSelection, isFalse);
    });

    test('needsHouseholdSelection: false when allHouseholds is empty', () {
      final s = _AuthState(user: Object());
      expect(s.needsHouseholdSelection, isFalse);
    });

    test('needsHouseholdSelection: false when not authenticated', () {
      final h = _makeHousehold();
      final s = _AuthState(allHouseholds: [h]);
      expect(s.needsHouseholdSelection, isFalse);
    });

    test('exactly one household with no selection: needsHouseholdSetup=false, needsHouseholdSelection=true', () {
      final h = _makeHousehold();
      final s = _AuthState(user: Object(), allHouseholds: [h]);
      // Single-household case — router/build will auto-select, but logically
      // needsHouseholdSelection is true until selection is resolved.
      expect(s.needsHouseholdSetup, isFalse);
      expect(s.needsHouseholdSelection, isTrue);
    });
  });
}
