// profile_model_test.dart
// Unit tests for Profile model: fromJson, toJson, copyWith skinTone sentinel,
// toString PII, and equality. Pure Dart — no Flutter/Supabase.

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_designer_assist/data/models/profile.dart';
import 'package:ai_designer_assist/core/constants/app_constants.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _fullJson() => {
      'id': 'p1',
      'household_id': 'h1',
      'auth_user_id': 'auth-uid-1',
      'name': 'Alice',
      'avatar_url': 'avatars/p1/avatar.jpg',
      'age_group': 'adult',
      'gender': 'female',
      'skin_tone': 'medium',
      'style_persona': ['Casual', 'Minimalist'],
      'fit_preferences': {'constraints': ['No shorts']},
      'is_admin': true,
      'created_at': '2024-03-01T00:00:00.000Z',
    };

Map<String, dynamic> _minimalJson() => {
      'id': 'p2',
      'household_id': 'h1',
      'name': 'Bob',
      'age_group': 'adult',
      'created_at': '2024-01-01T00:00:00.000Z',
    };

Profile _makeProfile({
  String id = 'p1',
  String name = 'Alice',
  SkinTone? skinTone = SkinTone.medium,
  bool isAdmin = false,
  Gender gender = Gender.female,
  String? avatarUrl,
}) =>
    Profile(
      id: id,
      householdId: 'h1',
      name: name,
      ageGroup: AgeGroup.adult,
      gender: gender,
      skinTone: skinTone,
      isAdmin: isAdmin,
      avatarUrl: avatarUrl,
      createdAt: DateTime(2024, 3, 1),
    );

void main() {
  // -------------------------------------------------------------------------
  group('Profile.fromJson — full payload', () {
    late Profile p;
    setUp(() => p = Profile.fromJson(_fullJson()));

    test('id', () => expect(p.id, 'p1'));
    test('householdId', () => expect(p.householdId, 'h1'));
    test('authUserId', () => expect(p.authUserId, 'auth-uid-1'));
    test('name', () => expect(p.name, 'Alice'));
    test('avatarUrl', () => expect(p.avatarUrl, 'avatars/p1/avatar.jpg'));
    test('ageGroup → adult', () => expect(p.ageGroup, AgeGroup.adult));
    test('gender → female', () => expect(p.gender, Gender.female));
    test('skinTone → medium', () => expect(p.skinTone, SkinTone.medium));
    test('stylePersona list', () => expect(p.stylePersona, ['Casual', 'Minimalist']));
    test('fitPreferences map', () => expect(p.fitPreferences['constraints'], isNotNull));
    test('isAdmin → true', () => expect(p.isAdmin, isTrue));
    test('createdAt year', () => expect(p.createdAt.year, 2024));
  });

  // -------------------------------------------------------------------------
  group('Profile.fromJson — minimal payload', () {
    late Profile p;
    setUp(() => p = Profile.fromJson(_minimalJson()));

    test('authUserId → null', () => expect(p.authUserId, isNull));
    test('avatarUrl → null', () => expect(p.avatarUrl, isNull));
    test('gender → other (default)', () => expect(p.gender, Gender.other));
    test('skinTone → null', () => expect(p.skinTone, isNull));
    test('stylePersona → empty', () => expect(p.stylePersona, isEmpty));
    test('fitPreferences → empty map', () => expect(p.fitPreferences, isEmpty));
    test('isAdmin → false (default)', () => expect(p.isAdmin, isFalse));
  });

  // -------------------------------------------------------------------------
  group('Profile.fromJson — age_group fallback', () {
    Profile _withAgeGroup(String? v) {
      final json = Map<String, dynamic>.from(_minimalJson())
        ..['age_group'] = v ?? 'adult';
      return Profile.fromJson(json);
    }

    test('toddler', () => expect(_withAgeGroup('toddler').ageGroup, AgeGroup.toddler));
    test('child',   () => expect(_withAgeGroup('child').ageGroup,   AgeGroup.child));
    test('teen',    () => expect(_withAgeGroup('teen').ageGroup,    AgeGroup.teen));
    test('adult',   () => expect(_withAgeGroup('adult').ageGroup,   AgeGroup.adult));
    test('unknown → adult', () {
      final json = Map<String, dynamic>.from(_minimalJson())
        ..['age_group'] = 'invalid';
      expect(Profile.fromJson(json).ageGroup, AgeGroup.adult);
    });
  });

  // -------------------------------------------------------------------------
  group('Profile.fromJson — gender fallback', () {
    Profile _withGender(String? v) {
      final json = Map<String, dynamic>.from(_fullJson())
        ..['gender'] = v;
      return Profile.fromJson(json);
    }

    test('male',   () => expect(_withGender('male').gender,   Gender.male));
    test('female', () => expect(_withGender('female').gender, Gender.female));
    test('other',  () => expect(_withGender('other').gender,  Gender.other));
    test('null → other', () => expect(_withGender(null).gender, Gender.other));
    test('unknown → other', () => expect(_withGender('nonbinary').gender, Gender.other));
  });

  // -------------------------------------------------------------------------
  group('Profile.fromJson — skinTone', () {
    Profile _withSkinTone(String? v) {
      final json = Map<String, dynamic>.from(_minimalJson())
        ..['skin_tone'] = v;
      return Profile.fromJson(json);
    }

    test('null → null skinTone', () => expect(_withSkinTone(null).skinTone, isNull));
    test('fair',   () => expect(_withSkinTone('fair').skinTone,   SkinTone.fair));
    test('medium', () => expect(_withSkinTone('medium').skinTone, SkinTone.medium));
    test('dark',   () => expect(_withSkinTone('dark').skinTone,   SkinTone.dark));
    test('unknown → null skinTone', () => expect(_withSkinTone('alabaster').skinTone, isNull));
  });

  // -------------------------------------------------------------------------
  group('Profile.toJson', () {
    test('required keys always present', () {
      final json = _makeProfile().toJson();
      for (final key in ['id', 'household_id', 'name', 'age_group', 'gender',
          'style_persona', 'fit_preferences', 'is_admin', 'created_at']) {
        expect(json.containsKey(key), isTrue, reason: 'missing key: $key');
      }
    });

    test('auth_user_id omitted when null', () {
      final json = _makeProfile().toJson(); // no authUserId
      expect(json.containsKey('auth_user_id'), isFalse);
    });

    test('avatar_url omitted when null', () {
      final json = _makeProfile(avatarUrl: null).toJson();
      expect(json.containsKey('avatar_url'), isFalse);
    });

    test('avatar_url included when set', () {
      final json = _makeProfile(avatarUrl: 'avatars/p1/avatar.jpg').toJson();
      expect(json['avatar_url'], 'avatars/p1/avatar.jpg');
    });

    test('fromJson → toJson → fromJson roundtrip', () {
      final original = Profile.fromJson(_fullJson());
      final restored = Profile.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.ageGroup, original.ageGroup);
      expect(restored.gender, original.gender);
      expect(restored.skinTone, original.skinTone);
      expect(restored.isAdmin, original.isAdmin);
      expect(restored.stylePersona, original.stylePersona);
    });
  });

  // -------------------------------------------------------------------------
  group('Profile.copyWith — skinTone sentinel', () {
    test('omitting skinTone preserves existing value', () {
      final p = _makeProfile(skinTone: SkinTone.olive);
      final copied = p.copyWith(name: 'Changed');
      expect(copied.skinTone, SkinTone.olive);
    });

    test('passing skinTone: null explicitly clears it', () {
      final p = _makeProfile(skinTone: SkinTone.olive);
      final copied = p.copyWith(skinTone: null);
      expect(copied.skinTone, isNull);
    });

    test('passing a new SkinTone replaces existing', () {
      final p = _makeProfile(skinTone: SkinTone.fair);
      expect(p.copyWith(skinTone: SkinTone.dark).skinTone, SkinTone.dark);
    });

    test('null skinTone stays null when omitted', () {
      final p = _makeProfile(skinTone: null);
      expect(p.copyWith(name: 'X').skinTone, isNull);
    });

    test('copyWith preserves isAdmin', () {
      final p = _makeProfile(isAdmin: true);
      expect(p.copyWith(name: 'X').isAdmin, isTrue);
    });

    test('can flip isAdmin', () {
      final p = _makeProfile(isAdmin: false);
      expect(p.copyWith(isAdmin: true).isAdmin, isTrue);
    });

    test('copyWith updates avatarUrl', () {
      final p = _makeProfile(avatarUrl: null);
      expect(
        p.copyWith(avatarUrl: 'avatars/p1/avatar.jpg').avatarUrl,
        'avatars/p1/avatar.jpg',
      );
    });

    test('copyWith preserves all unrelated fields', () {
      final p = _makeProfile(skinTone: SkinTone.brown, isAdmin: true, gender: Gender.male);
      final copied = p.copyWith(name: 'New Name');
      expect(copied.skinTone, SkinTone.brown);
      expect(copied.isAdmin, isTrue);
      expect(copied.gender, Gender.male);
      expect(copied.name, 'New Name');
    });
  });

  // -------------------------------------------------------------------------
  group('Profile.toString — PII check', () {
    test('does not include profile name', () {
      expect(_makeProfile(name: 'Alice').toString(), isNot(contains('Alice')));
    });

    test('includes id', () {
      expect(_makeProfile(id: 'p42').toString(), contains('p42'));
    });
  });

  // -------------------------------------------------------------------------
  group('Profile equality and hashCode', () {
    test('same id → equal regardless of other fields', () {
      final a = _makeProfile(id: 'x', name: 'Alice');
      final b = _makeProfile(id: 'x', name: 'Bob', isAdmin: true);
      expect(a, equals(b));
    });

    test('different id → not equal', () {
      expect(_makeProfile(id: 'x'), isNot(equals(_makeProfile(id: 'y'))));
    });

    test('hashCode matches for same id', () {
      expect(_makeProfile(id: 'z').hashCode, _makeProfile(id: 'z').hashCode);
    });
  });
}
