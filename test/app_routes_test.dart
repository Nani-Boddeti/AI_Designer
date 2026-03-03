// app_routes_test.dart
// Unit tests for AppRoutes path constants and helper methods.
// Pure Dart — no Flutter widgets, no Supabase, no GoRouter instantiation.

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_designer_assist/router/app_router.dart';

void main() {
  // -------------------------------------------------------------------------
  group('AppRoutes — static path constants', () {
    test('splash is "/"', () {
      expect(AppRoutes.splash, equals('/'));
    });

    test('auth is "/auth"', () {
      expect(AppRoutes.auth, equals('/auth'));
    });

    test('householdSetup is "/household-setup"', () {
      expect(AppRoutes.householdSetup, equals('/household-setup'));
    });

    test('home is "/home"', () {
      expect(AppRoutes.home, equals('/home'));
    });

    test('profiles is "/profiles"', () {
      expect(AppRoutes.profiles, equals('/profiles'));
    });

    test('profileEdit contains ":id" placeholder', () {
      expect(AppRoutes.profileEdit, contains(':id'));
      expect(AppRoutes.profileEdit, startsWith('/profiles/'));
    });

    test('wardrobe contains ":profileId" placeholder', () {
      expect(AppRoutes.wardrobe, contains(':profileId'));
    });

    test('addItem contains ":profileId" placeholder', () {
      expect(AppRoutes.addItem, contains(':profileId'));
    });

    test('itemDetail contains both ":profileId" and ":itemId"', () {
      expect(AppRoutes.itemDetail, contains(':profileId'));
      expect(AppRoutes.itemDetail, contains(':itemId'));
    });
  });

  // -------------------------------------------------------------------------
  group('AppRoutes.wardrobePath()', () {
    test('produces correct path for a given profileId', () {
      expect(AppRoutes.wardrobePath('abc'), equals('/wardrobe/abc'));
    });

    test('works with UUID-style id', () {
      expect(
        AppRoutes.wardrobePath('550e8400-e29b-41d4-a716-446655440000'),
        equals('/wardrobe/550e8400-e29b-41d4-a716-446655440000'),
      );
    });

    test('handles empty string id (edge case — no crash)', () {
      expect(AppRoutes.wardrobePath(''), equals('/wardrobe/'));
    });
  });

  // -------------------------------------------------------------------------
  group('AppRoutes.addItemPath()', () {
    test('produces correct path for a given profileId', () {
      expect(AppRoutes.addItemPath('abc'), equals('/wardrobe/abc/add'));
    });

    test('path ends with /add', () {
      expect(AppRoutes.addItemPath('xyz'), endsWith('/add'));
    });

    test('path starts with /wardrobe/', () {
      expect(AppRoutes.addItemPath('xyz'), startsWith('/wardrobe/'));
    });

    test('handles UUID-style id', () {
      expect(
        AppRoutes.addItemPath('550e8400'),
        equals('/wardrobe/550e8400/add'),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('AppRoutes.itemDetailPath()', () {
    test('produces correct path for profileId and itemId', () {
      expect(
        AppRoutes.itemDetailPath('abc', '123'),
        equals('/wardrobe/abc/item/123'),
      );
    });

    test('path contains /item/ segment', () {
      expect(AppRoutes.itemDetailPath('abc', '123'), contains('/item/'));
    });

    test('path starts with /wardrobe/', () {
      expect(
        AppRoutes.itemDetailPath('abc', '123'),
        startsWith('/wardrobe/'),
      );
    });

    test('different profileId and itemId produce different paths', () {
      final path1 = AppRoutes.itemDetailPath('profile1', 'item1');
      final path2 = AppRoutes.itemDetailPath('profile2', 'item2');
      expect(path1, isNot(equals(path2)));
    });

    test('handles UUID-style ids', () {
      expect(
        AppRoutes.itemDetailPath('prof-uuid', 'item-uuid'),
        equals('/wardrobe/prof-uuid/item/item-uuid'),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('AppRoutes.profileEditPath()', () {
    test('produces correct path for a given profileId', () {
      expect(AppRoutes.profileEditPath('xyz'), equals('/profiles/xyz/edit'));
    });

    test('path starts with /profiles/', () {
      expect(AppRoutes.profileEditPath('xyz'), startsWith('/profiles/'));
    });

    test('path ends with /edit', () {
      expect(AppRoutes.profileEditPath('xyz'), endsWith('/edit'));
    });

    test('handles UUID-style id', () {
      expect(
        AppRoutes.profileEditPath('550e8400'),
        equals('/profiles/550e8400/edit'),
      );
    });

    test('handles empty string id (edge case — no crash)', () {
      expect(AppRoutes.profileEditPath(''), equals('/profiles//edit'));
    });
  });

  // -------------------------------------------------------------------------
  group('AppRoutes path helpers — consistency checks', () {
    test('wardrobePath, addItemPath and itemDetailPath all share same prefix', () {
      const profileId = 'test-profile';
      final wardrobe = AppRoutes.wardrobePath(profileId);
      final addItem = AppRoutes.addItemPath(profileId);
      final detail = AppRoutes.itemDetailPath(profileId, 'item99');

      expect(addItem, startsWith(wardrobe));
      expect(detail, startsWith(wardrobe));
    });

    test('profileEditPath is separate from wardrobePath namespace', () {
      expect(AppRoutes.profileEditPath('p1'), isNot(startsWith('/wardrobe')));
    });
  });
}
