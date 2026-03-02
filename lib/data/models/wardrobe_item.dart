import '../../core/constants/app_constants.dart';

/// A single clothing or accessory item in a profile's wardrobe.
class WardrobeItem {
  const WardrobeItem({
    required this.id,
    required this.profileId,
    required this.name,
    required this.category,
    this.colors = const [],
    this.colorNames = const [],
    this.styleTags = const [],
    this.seasonTags = const [],
    this.imageUrl,
    this.processedImageUrl,
    this.brand,
    this.size,
    this.aiDescription,
    required this.createdAt,
  });

  final String id;
  final String profileId;
  final String name;
  final WardrobeCategory category;

  /// Hex color strings (e.g. "#FF5733").
  final List<String> colors;

  /// Human-readable color names (e.g. "Coral Red").
  final List<String> colorNames;

  final List<String> styleTags;
  final List<String> seasonTags;

  /// Original upload URL (with background).
  final String? imageUrl;

  /// Background-removed transparent PNG URL.
  final String? processedImageUrl;

  final String? brand;
  final String? size;

  /// AI-generated description from Gemini tagging.
  final String? aiDescription;

  final DateTime createdAt;

  /// Returns the best available image URL, preferring the processed version.
  String? get displayImageUrl => processedImageUrl ?? imageUrl;

  factory WardrobeItem.fromJson(Map<String, dynamic> json) {
    return WardrobeItem(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      name: json['name'] as String,
      category: WardrobeCategory.fromString(
          json['category'] as String? ?? 'top'),
      colors: (json['colors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      colorNames: (json['color_names'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      styleTags: (json['style_tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      seasonTags: (json['season_tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      imageUrl: json['image_url'] as String?,
      processedImageUrl: json['processed_image_url'] as String?,
      brand: json['brand'] as String?,
      size: json['size'] as String?,
      aiDescription: json['ai_description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'name': name,
      'category': category.value,
      'colors': colors,
      'color_names': colorNames,
      'style_tags': styleTags,
      'season_tags': seasonTags,
      if (imageUrl != null) 'image_url': imageUrl,
      if (processedImageUrl != null) 'processed_image_url': processedImageUrl,
      if (brand != null) 'brand': brand,
      if (size != null) 'size': size,
      if (aiDescription != null) 'ai_description': aiDescription,
      'created_at': createdAt.toIso8601String(),
    };
  }

  WardrobeItem copyWith({
    String? id,
    String? profileId,
    String? name,
    WardrobeCategory? category,
    List<String>? colors,
    List<String>? colorNames,
    List<String>? styleTags,
    List<String>? seasonTags,
    String? imageUrl,
    String? processedImageUrl,
    String? brand,
    String? size,
    String? aiDescription,
    DateTime? createdAt,
  }) {
    return WardrobeItem(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      category: category ?? this.category,
      colors: colors ?? this.colors,
      colorNames: colorNames ?? this.colorNames,
      styleTags: styleTags ?? this.styleTags,
      seasonTags: seasonTags ?? this.seasonTags,
      imageUrl: imageUrl ?? this.imageUrl,
      processedImageUrl: processedImageUrl ?? this.processedImageUrl,
      brand: brand ?? this.brand,
      size: size ?? this.size,
      aiDescription: aiDescription ?? this.aiDescription,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'WardrobeItem(id: $id, name: $name, category: ${category.displayName})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WardrobeItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
