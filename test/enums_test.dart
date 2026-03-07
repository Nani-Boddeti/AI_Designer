// enums_test.dart
// Unit tests for all app enums: WardrobeCategory, AgeGroup, Gender, SkinTone.
// Pure Dart — no Flutter/Supabase.

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_designer_assist/core/constants/app_constants.dart';

void main() {
  // -------------------------------------------------------------------------
  group('WardrobeCategory.fromString', () {
    test('all known values round-trip via name', () {
      for (final cat in WardrobeCategory.values) {
        expect(WardrobeCategory.fromString(cat.name), cat);
      }
    });

    test('unknown string → top (fallback)', () {
      expect(WardrobeCategory.fromString('unknown'), WardrobeCategory.top);
    });

    test('empty string → top (fallback)', () {
      expect(WardrobeCategory.fromString(''), WardrobeCategory.top);
    });

    test('trims whitespace before matching', () {
      expect(WardrobeCategory.fromString('  bottom  '), WardrobeCategory.bottom);
    });

    test('case-insensitive: "SHOES" → shoes', () {
      expect(WardrobeCategory.fromString('SHOES'), WardrobeCategory.shoes);
    });

    test('case-insensitive: "Outerwear" → outerwear', () {
      expect(WardrobeCategory.fromString('Outerwear'), WardrobeCategory.outerwear);
    });

    test('"dress" → dress', () {
      expect(WardrobeCategory.fromString('dress'), WardrobeCategory.dress);
    });

    test('"swimwear" → swimwear', () {
      expect(WardrobeCategory.fromString('swimwear'), WardrobeCategory.swimwear);
    });

    test('"accessory" → accessory', () {
      expect(WardrobeCategory.fromString('accessory'), WardrobeCategory.accessory);
    });
  });

  // -------------------------------------------------------------------------
  group('WardrobeCategory.displayName', () {
    test('top → "Top"', () => expect(WardrobeCategory.top.displayName, 'Top'));
    test('bottom → "Bottom"', () => expect(WardrobeCategory.bottom.displayName, 'Bottom'));
    test('shoes → "Shoes"', () => expect(WardrobeCategory.shoes.displayName, 'Shoes'));
    test('accessory → "Accessory"', () => expect(WardrobeCategory.accessory.displayName, 'Accessory'));
    test('outerwear → "Outerwear"', () => expect(WardrobeCategory.outerwear.displayName, 'Outerwear'));
    test('dress → "Dress"', () => expect(WardrobeCategory.dress.displayName, 'Dress'));
    test('swimwear → "Swimwear"', () => expect(WardrobeCategory.swimwear.displayName, 'Swimwear'));
  });

  // -------------------------------------------------------------------------
  group('WardrobeCategory.value', () {
    test('value equals name for all categories', () {
      for (final cat in WardrobeCategory.values) {
        expect(cat.value, cat.name);
      }
    });
  });

  // -------------------------------------------------------------------------
  group('AgeGroup.fromString', () {
    test('all known values round-trip', () {
      for (final ag in AgeGroup.values) {
        expect(AgeGroup.fromString(ag.name), ag);
      }
    });

    test('unknown string → adult (fallback)', () {
      expect(AgeGroup.fromString('elder'), AgeGroup.adult);
    });

    test('"toddler" → toddler', () => expect(AgeGroup.fromString('toddler'), AgeGroup.toddler));
    test('"child" → child',   () => expect(AgeGroup.fromString('child'),   AgeGroup.child));
    test('"teen" → teen',     () => expect(AgeGroup.fromString('teen'),    AgeGroup.teen));
    test('"adult" → adult',   () => expect(AgeGroup.fromString('adult'),   AgeGroup.adult));
  });

  // -------------------------------------------------------------------------
  group('AgeGroup.displayName', () {
    test('toddler contains "Toddler"', () => expect(AgeGroup.toddler.displayName, contains('Toddler')));
    test('child contains "Child"',     () => expect(AgeGroup.child.displayName,   contains('Child')));
    test('teen contains "Teen"',       () => expect(AgeGroup.teen.displayName,    contains('Teen')));
    test('adult contains "Adult"',     () => expect(AgeGroup.adult.displayName,   contains('Adult')));
  });

  // -------------------------------------------------------------------------
  group('Gender.fromString', () {
    test('null → other', () => expect(Gender.fromString(null), Gender.other));
    test('unknown → other', () => expect(Gender.fromString('nonbinary'), Gender.other));
    test('"male" → male',     () => expect(Gender.fromString('male'),   Gender.male));
    test('"female" → female', () => expect(Gender.fromString('female'), Gender.female));
    test('"other" → other',   () => expect(Gender.fromString('other'),  Gender.other));

    test('all known values round-trip', () {
      for (final g in Gender.values) {
        expect(Gender.fromString(g.name), g);
      }
    });
  });

  // -------------------------------------------------------------------------
  group('Gender.displayName', () {
    test('male → "Male"',     () => expect(Gender.male.displayName,   'Male'));
    test('female → "Female"', () => expect(Gender.female.displayName, 'Female'));
    test('other is non-empty', () => expect(Gender.other.displayName, isNotEmpty));
  });

  // -------------------------------------------------------------------------
  group('SkinTone.fromString', () {
    test('null → null', () => expect(SkinTone.fromString(null), isNull));
    test('unknown → null', () => expect(SkinTone.fromString('alabaster'), isNull));

    test('all known values round-trip', () {
      for (final st in SkinTone.values) {
        expect(SkinTone.fromString(st.name), st);
      }
    });

    test('"fair" → fair',     () => expect(SkinTone.fromString('fair'),   SkinTone.fair));
    test('"light" → light',   () => expect(SkinTone.fromString('light'),  SkinTone.light));
    test('"medium" → medium', () => expect(SkinTone.fromString('medium'), SkinTone.medium));
    test('"olive" → olive',   () => expect(SkinTone.fromString('olive'),  SkinTone.olive));
    test('"brown" → brown',   () => expect(SkinTone.fromString('brown'),  SkinTone.brown));
    test('"dark" → dark',     () => expect(SkinTone.fromString('dark'),   SkinTone.dark));
  });

  // -------------------------------------------------------------------------
  group('SkinTone.displayName', () {
    test('all display names are non-empty strings', () {
      for (final st in SkinTone.values) {
        expect(st.displayName, isNotEmpty);
      }
    });

    test('fair → "Fair"',   () => expect(SkinTone.fair.displayName,   'Fair'));
    test('medium → "Medium"', () => expect(SkinTone.medium.displayName, 'Medium'));
    test('dark → "Dark"',   () => expect(SkinTone.dark.displayName,   'Dark'));
  });

  // -------------------------------------------------------------------------
  group('SkinTone.swatchColor', () {
    test('all swatch colours are non-zero', () {
      for (final st in SkinTone.values) {
        expect(st.swatchColor, isNonZero);
      }
    });

    test('each tone has a distinct swatch colour', () {
      final swatches = SkinTone.values.map((s) => s.swatchColor).toSet();
      expect(swatches.length, equals(SkinTone.values.length));
    });
  });
}
