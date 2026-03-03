// ignore_for_file: constant_identifier_names

/// Application-wide constants, enums, and option lists.
// ---------------------------------------------------------------------------
// Supabase table names
// ---------------------------------------------------------------------------
class SupabaseTables {
  SupabaseTables._();

  static const String households = 'households';
  static const String profiles = 'profiles';
  static const String wardrobeItems = 'wardrobe_items';
  static const String outfits = 'outfits';
  static const String calendarEvents = 'calendar_events';
}

// ---------------------------------------------------------------------------
// Supabase storage buckets
// ---------------------------------------------------------------------------
class SupabaseBuckets {
  SupabaseBuckets._();

  static const String avatars = 'avatars';
  static const String wardrobeImages = 'wardrobe-images';
  static const String processedImages = 'processed-images';
}

// ---------------------------------------------------------------------------
// Wardrobe category enum
// ---------------------------------------------------------------------------
enum WardrobeCategory {
  top,
  bottom,
  shoes,
  accessory,
  outerwear,
  dress,
  swimwear;

  String get displayName {
    switch (this) {
      case WardrobeCategory.top:
        return 'Top';
      case WardrobeCategory.bottom:
        return 'Bottom';
      case WardrobeCategory.shoes:
        return 'Shoes';
      case WardrobeCategory.accessory:
        return 'Accessory';
      case WardrobeCategory.outerwear:
        return 'Outerwear';
      case WardrobeCategory.dress:
        return 'Dress';
      case WardrobeCategory.swimwear:
        return 'Swimwear';
    }
  }

  String get value => name;

  static WardrobeCategory fromString(String value) {
    return WardrobeCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => WardrobeCategory.top,
    );
  }
}

// ---------------------------------------------------------------------------
// Age group enum
// ---------------------------------------------------------------------------
enum AgeGroup {
  toddler,
  child,
  teen,
  adult;

  String get displayName {
    switch (this) {
      case AgeGroup.toddler:
        return 'Toddler (0–4)';
      case AgeGroup.child:
        return 'Child (5–12)';
      case AgeGroup.teen:
        return 'Teen (13–17)';
      case AgeGroup.adult:
        return 'Adult (18+)';
    }
  }

  String get value => name;

  static AgeGroup fromString(String value) {
    return AgeGroup.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AgeGroup.adult,
    );
  }
}

// ---------------------------------------------------------------------------
// Skin tone options (Fitzpatrick-based, inclusive labels)
// ---------------------------------------------------------------------------

enum SkinTone {
  fair,
  light,
  medium,
  olive,
  brown,
  dark;

  String get displayName {
    switch (this) {
      case SkinTone.fair:   return 'Fair';
      case SkinTone.light:  return 'Light';
      case SkinTone.medium: return 'Medium';
      case SkinTone.olive:  return 'Olive';
      case SkinTone.brown:  return 'Brown';
      case SkinTone.dark:   return 'Dark';
    }
  }

  /// Representative swatch colour for the UI picker.
  int get swatchColor {
    switch (this) {
      case SkinTone.fair:   return 0xFFFFDBAC;
      case SkinTone.light:  return 0xFFF1C27D;
      case SkinTone.medium: return 0xFFE0AC69;
      case SkinTone.olive:  return 0xFFC68642;
      case SkinTone.brown:  return 0xFF8D5524;
      case SkinTone.dark:   return 0xFF4A2912;
    }
  }

  String get value => name;

  static SkinTone? fromString(String? value) {
    if (value == null) return null;
    return SkinTone.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SkinTone.medium,
    );
  }
}

// ---------------------------------------------------------------------------
// Style persona options
// ---------------------------------------------------------------------------
class StylePersonas {
  StylePersonas._();

  static const List<String> all = [
    'Classic',
    'Casual',
    'Sporty',
    'Bohemian',
    'Preppy',
    'Edgy',
    'Romantic',
    'Minimalist',
    'Streetwear',
    'Business Casual',
    'Glam',
    'Vintage',
    'Cottagecore',
    'Athleisure',
    'Tropical',
  ];
}

// ---------------------------------------------------------------------------
// Fit constraint options
// ---------------------------------------------------------------------------
class FitConstraints {
  FitConstraints._();

  static const List<String> all = [
    'Modest coverage',
    'No shorts',
    'No sleeveless',
    'Sensory-friendly',
    'Easy to dress',
    'School uniform required',
    'Allergic to certain fabrics',
    'Petite fit',
    'Plus size',
    'Tall fit',
    'Wide feet',
    'Orthotics needed',
    'Limited mobility',
    'Pregnancy-friendly',
  ];
}

// ---------------------------------------------------------------------------
// Occasion options
// ---------------------------------------------------------------------------
class OccasionOptions {
  OccasionOptions._();

  static const List<String> all = [
    'Everyday',
    'Work / Office',
    'School',
    'Church / Worship',
    'Wedding',
    'Birthday Party',
    'Beach / Vacation',
    'Formal Event',
    'Date Night',
    'Holiday Photos',
    'Sports / Outdoor',
    'Festival',
    'Funeral',
    'Baby Shower',
    'Reunion',
  ];
}

// ---------------------------------------------------------------------------
// Season options
// ---------------------------------------------------------------------------
class SeasonOptions {
  SeasonOptions._();

  static const List<String> all = [
    'Spring',
    'Summer',
    'Fall',
    'Winter',
    'All-Season',
  ];
}

// ---------------------------------------------------------------------------
// App-level UI constants
// ---------------------------------------------------------------------------
class AppSizes {
  AppSizes._();

  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;

  static const double paddingSm = 8.0;
  static const double paddingMd = 16.0;
  static const double paddingLg = 24.0;

  static const double avatarSmall = 40.0;
  static const double avatarMedium = 64.0;
  static const double avatarLarge = 96.0;

  static const double cardElevation = 2.0;
  static const double modalElevation = 8.0;
}
