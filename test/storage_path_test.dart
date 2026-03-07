// storage_path_test.dart
// Unit tests for storage path normalisation logic mirrored from
// SupabaseService._normalizePath (private static).
//
// The logic: given a value that may be either a plain storage path
// ("wardrobe/x/y.jpg") or a legacy full public URL
// ("https://.../object/public/{bucket}/wardrobe/x/y.jpg"),
// extract and return only the storage path.

import 'package:flutter_test/flutter_test.dart';

// Mirror of SupabaseService._normalizePath — kept in sync manually.
String normalizePath(String urlOrPath, String bucket) {
  if (!urlOrPath.startsWith('http')) return urlOrPath;
  final marker = '/object/public/$bucket/';
  final idx = urlOrPath.indexOf(marker);
  return idx >= 0 ? urlOrPath.substring(idx + marker.length) : urlOrPath;
}

void main() {
  const wardrobeBucket = 'wardrobe-images';
  const processedBucket = 'processed-images';
  const avatarBucket = 'avatars';

  // -------------------------------------------------------------------------
  group('normalizePath — plain paths (no-op)', () {
    test('plain wardrobe path returned as-is', () {
      const path = 'wardrobe/profile-1/item-1/original.jpg';
      expect(normalizePath(path, wardrobeBucket), equals(path));
    });

    test('plain processed path returned as-is', () {
      const path = 'wardrobe/profile-1/item-1/processed.png';
      expect(normalizePath(path, processedBucket), equals(path));
    });

    test('plain avatar path returned as-is', () {
      const path = 'avatars/profile-1/avatar.jpg';
      expect(normalizePath(path, avatarBucket), equals(path));
    });

    test('empty string returned as-is', () {
      expect(normalizePath('', wardrobeBucket), equals(''));
    });
  });

  // -------------------------------------------------------------------------
  group('normalizePath — full public URLs', () {
    const ref = 'https://abcdefghijklmno.supabase.co/storage/v1';

    test('extracts path from wardrobe-images public URL', () {
      const url =
          '$ref/object/public/wardrobe-images/wardrobe/p1/i1/original.jpg';
      expect(
        normalizePath(url, wardrobeBucket),
        equals('wardrobe/p1/i1/original.jpg'),
      );
    });

    test('extracts path from processed-images public URL', () {
      const url =
          '$ref/object/public/processed-images/wardrobe/p1/i1/processed.png';
      expect(
        normalizePath(url, processedBucket),
        equals('wardrobe/p1/i1/processed.png'),
      );
    });

    test('extracts path from avatars public URL', () {
      const url = '$ref/object/public/avatars/avatars/p1/avatar.jpg';
      expect(
        normalizePath(url, avatarBucket),
        equals('avatars/p1/avatar.jpg'),
      );
    });

    test('UUID-containing path extracted correctly', () {
      const profileId = '550e8400-e29b-41d4-a716-446655440000';
      const itemId = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';
      const url =
          '$ref/object/public/wardrobe-images/wardrobe/$profileId/$itemId/original.jpg';
      expect(
        normalizePath(url, wardrobeBucket),
        equals('wardrobe/$profileId/$itemId/original.jpg'),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('normalizePath — edge cases', () {
    test('wrong bucket in URL → returned unchanged', () {
      const url =
          'https://x.supabase.co/storage/v1/object/public/other-bucket/file.jpg';
      // We're looking for /object/public/wardrobe-images/ — not found
      expect(normalizePath(url, wardrobeBucket), equals(url));
    });

    test('http URL without known bucket marker → returned unchanged', () {
      const url = 'http://example.com/some/image.jpg';
      expect(normalizePath(url, wardrobeBucket), equals(url));
    });

    test('https URL without supabase pattern → returned unchanged', () {
      const url = 'https://cdn.example.com/image.jpg';
      expect(normalizePath(url, wardrobeBucket), equals(url));
    });

    test('path with nested folders extracted correctly', () {
      const url =
          'https://x.supabase.co/storage/v1/object/public/wardrobe-images/a/b/c/d/file.jpg';
      expect(
        normalizePath(url, wardrobeBucket),
        equals('a/b/c/d/file.jpg'),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('normalizePath — idempotency', () {
    test('calling twice on a path is no-op', () {
      const path = 'wardrobe/p1/i1/original.jpg';
      expect(
        normalizePath(normalizePath(path, wardrobeBucket), wardrobeBucket),
        equals(path),
      );
    });

    test('calling twice on a URL produces same result as once', () {
      const url =
          'https://x.supabase.co/storage/v1/object/public/wardrobe-images/wardrobe/p1/i1/original.jpg';
      final once = normalizePath(url, wardrobeBucket);
      final twice = normalizePath(once, wardrobeBucket);
      expect(twice, equals(once));
    });
  });
}
