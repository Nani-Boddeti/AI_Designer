// wardrobe_item_model_test.dart
// Unit tests for WardrobeItem model: fromJson, toJson, copyWith,
// displayImageUrl, equality. Pure Dart — no Flutter/Supabase.

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_designer_assist/data/models/wardrobe_item.dart';
import 'package:ai_designer_assist/core/constants/app_constants.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _fullJson() => {
      'id': 'item-1',
      'profile_id': 'profile-1',
      'name': 'High-Waist Slim Jeans',
      'category': 'bottom',
      'colors': ['#1A2B3C', '#FFFFFF'],
      'color_names': ['Navy', 'White'],
      'style_tags': ['slim fit', 'high waist', 'casual'],
      'season_tags': ['Fall', 'Winter'],
      'image_url': 'wardrobe/p1/i1/original.jpg',
      'processed_image_url': 'wardrobe/p1/i1/processed.png',
      'brand': 'Levi\'s',
      'size': 'M',
      'ai_description': 'Classic slim jeans.',
      'is_private': false,
      'created_at': '2024-06-01T10:00:00.000Z',
    };

Map<String, dynamic> _minimalJson() => {
      'id': 'item-2',
      'profile_id': 'profile-2',
      'name': 'New Item',
      'category': 'top',
      'created_at': '2024-01-01T00:00:00.000Z',
    };

WardrobeItem _makeItem({
  String id = 'item-1',
  String? imageUrl = 'wardrobe/p1/i1/original.jpg',
  String? processedImageUrl = 'wardrobe/p1/i1/processed.png',
  WardrobeCategory category = WardrobeCategory.bottom,
  bool isPrivate = false,
}) =>
    WardrobeItem(
      id: id,
      profileId: 'profile-1',
      name: 'Test Item',
      category: category,
      imageUrl: imageUrl,
      processedImageUrl: processedImageUrl,
      isPrivate: isPrivate,
      createdAt: DateTime(2024, 6, 1),
    );

void main() {
  // -------------------------------------------------------------------------
  group('WardrobeItem.fromJson — full payload', () {
    late WardrobeItem item;
    setUp(() => item = WardrobeItem.fromJson(_fullJson()));

    test('id parsed correctly', () => expect(item.id, 'item-1'));
    test('profileId parsed correctly', () => expect(item.profileId, 'profile-1'));
    test('name parsed correctly', () => expect(item.name, 'High-Waist Slim Jeans'));
    test('category parsed as bottom', () => expect(item.category, WardrobeCategory.bottom));
    test('colors parsed as list', () => expect(item.colors, ['#1A2B3C', '#FFFFFF']));
    test('colorNames parsed', () => expect(item.colorNames, ['Navy', 'White']));
    test('styleTags parsed', () => expect(item.styleTags, hasLength(3)));
    test('seasonTags parsed', () => expect(item.seasonTags, contains('Fall')));
    test('imageUrl parsed', () => expect(item.imageUrl, 'wardrobe/p1/i1/original.jpg'));
    test('processedImageUrl parsed', () => expect(item.processedImageUrl, 'wardrobe/p1/i1/processed.png'));
    test('brand parsed', () => expect(item.brand, "Levi's"));
    test('size parsed', () => expect(item.size, 'M'));
    test('aiDescription parsed', () => expect(item.aiDescription, isNotNull));
    test('isPrivate defaults to false', () => expect(item.isPrivate, isFalse));
    test('createdAt parsed', () => expect(item.createdAt.year, 2024));
  });

  // -------------------------------------------------------------------------
  group('WardrobeItem.fromJson — minimal payload', () {
    late WardrobeItem item;
    setUp(() => item = WardrobeItem.fromJson(_minimalJson()));

    test('id parsed', () => expect(item.id, 'item-2'));
    test('category defaults to top', () => expect(item.category, WardrobeCategory.top));
    test('colors defaults to empty list', () => expect(item.colors, isEmpty));
    test('colorNames defaults to empty', () => expect(item.colorNames, isEmpty));
    test('styleTags defaults to empty', () => expect(item.styleTags, isEmpty));
    test('seasonTags defaults to empty', () => expect(item.seasonTags, isEmpty));
    test('imageUrl is null', () => expect(item.imageUrl, isNull));
    test('processedImageUrl is null', () => expect(item.processedImageUrl, isNull));
    test('brand is null', () => expect(item.brand, isNull));
    test('isPrivate defaults to false', () => expect(item.isPrivate, isFalse));
  });

  // -------------------------------------------------------------------------
  group('WardrobeItem.fromJson — category parsing', () {
    WardrobeItem _withCategory(String cat) => WardrobeItem.fromJson({
          ..._minimalJson(),
          'category': cat,
        });

    test('"top" → WardrobeCategory.top', () {
      expect(_withCategory('top').category, WardrobeCategory.top);
    });
    test('"bottom" → WardrobeCategory.bottom', () {
      expect(_withCategory('bottom').category, WardrobeCategory.bottom);
    });
    test('"dress" → WardrobeCategory.dress', () {
      expect(_withCategory('dress').category, WardrobeCategory.dress);
    });
    test('"outerwear" → WardrobeCategory.outerwear', () {
      expect(_withCategory('outerwear').category, WardrobeCategory.outerwear);
    });
    test('"shoes" → WardrobeCategory.shoes', () {
      expect(_withCategory('shoes').category, WardrobeCategory.shoes);
    });
    test('"accessory" → WardrobeCategory.accessory', () {
      expect(_withCategory('accessory').category, WardrobeCategory.accessory);
    });
    test('"swimwear" → WardrobeCategory.swimwear', () {
      expect(_withCategory('swimwear').category, WardrobeCategory.swimwear);
    });
    test('unknown string falls back to top', () {
      expect(_withCategory('unknown_xyz').category, WardrobeCategory.top);
    });
    test('null category falls back to top', () {
      final json = Map<String, dynamic>.from(_minimalJson())
        ..remove('category');
      expect(WardrobeItem.fromJson(json).category, WardrobeCategory.top);
    });
  });

  // -------------------------------------------------------------------------
  group('WardrobeItem.toJson', () {
    test('all required keys present', () {
      final json = _makeItem().toJson();
      expect(json.containsKey('id'), isTrue);
      expect(json.containsKey('profile_id'), isTrue);
      expect(json.containsKey('name'), isTrue);
      expect(json.containsKey('category'), isTrue);
      expect(json.containsKey('colors'), isTrue);
      expect(json.containsKey('is_private'), isTrue);
      expect(json.containsKey('created_at'), isTrue);
    });

    test('null optional fields omitted from toJson', () {
      final item = _makeItem(imageUrl: null, processedImageUrl: null);
      final json = item.toJson();
      expect(json.containsKey('image_url'), isFalse);
      expect(json.containsKey('processed_image_url'), isFalse);
    });

    test('fromJson → toJson → fromJson roundtrip', () {
      final original = WardrobeItem.fromJson(_fullJson());
      final restored = WardrobeItem.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.category, original.category);
      expect(restored.colors, original.colors);
      expect(restored.brand, original.brand);
      expect(restored.isPrivate, original.isPrivate);
    });

    test('category serialised as lowercase string value', () {
      final json = _makeItem(category: WardrobeCategory.outerwear).toJson();
      expect(json['category'], 'outerwear');
    });
  });

  // -------------------------------------------------------------------------
  group('WardrobeItem.displayImageUrl', () {
    test('returns processedImageUrl when both set', () {
      final item = _makeItem(
        imageUrl: 'original.jpg',
        processedImageUrl: 'processed.png',
      );
      expect(item.displayImageUrl, 'processed.png');
    });

    test('returns imageUrl when processedImageUrl is null', () {
      final item = _makeItem(
        imageUrl: 'original.jpg',
        processedImageUrl: null,
      );
      expect(item.displayImageUrl, 'original.jpg');
    });

    test('returns null when both are null', () {
      final item = _makeItem(imageUrl: null, processedImageUrl: null);
      expect(item.displayImageUrl, isNull);
    });

    test('returns processedImageUrl even when imageUrl is null', () {
      final item = _makeItem(imageUrl: null, processedImageUrl: 'processed.png');
      expect(item.displayImageUrl, 'processed.png');
    });
  });

  // -------------------------------------------------------------------------
  group('WardrobeItem.copyWith', () {
    test('updates imageUrl', () {
      final item = _makeItem(imageUrl: 'old.jpg');
      expect(item.copyWith(imageUrl: 'new.jpg').imageUrl, 'new.jpg');
    });

    test('updates processedImageUrl', () {
      final item = _makeItem();
      final updated = item.copyWith(processedImageUrl: 'signed-url.png');
      expect(updated.processedImageUrl, 'signed-url.png');
    });

    test('omitting field preserves existing value', () {
      final item = _makeItem(isPrivate: true);
      expect(item.copyWith(name: 'Changed').isPrivate, isTrue);
    });

    test('can flip isPrivate', () {
      final item = _makeItem(isPrivate: false);
      expect(item.copyWith(isPrivate: true).isPrivate, isTrue);
    });

    test('copyWith returns new instance with same id', () {
      final item = _makeItem();
      final updated = item.copyWith(name: 'New Name');
      expect(updated.id, item.id);
      expect(updated.name, 'New Name');
    });
  });

  // -------------------------------------------------------------------------
  group('WardrobeItem equality and hashCode', () {
    test('same id → equal regardless of other fields', () {
      final a = _makeItem(id: 'x', imageUrl: 'a.jpg');
      final b = _makeItem(id: 'x', imageUrl: 'b.jpg');
      expect(a, equals(b));
    });

    test('different id → not equal', () {
      final a = _makeItem(id: 'x');
      final b = _makeItem(id: 'y');
      expect(a, isNot(equals(b)));
    });

    test('hashCode matches for same id', () {
      expect(_makeItem(id: 'z').hashCode, equals(_makeItem(id: 'z').hashCode));
    });
  });
}
