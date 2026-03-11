// Sentinel — lets copyWith distinguish "clear to null" from "keep existing".
const _kSentinel = Object();

/// An outfit – a curated collection of wardrobe items for a profile.
class Outfit {
  const Outfit({
    required this.id,
    required this.profileId,
    required this.name,
    this.occasion,
    this.itemIds = const [],
    this.notes,
    this.isAiGenerated = false,
    this.harmonyScore,
    required this.createdAt,
  });

  final String id;
  final String profileId;
  final String name;
  final String? occasion;

  /// IDs of [WardrobeItem]s that make up this outfit.
  final List<String> itemIds;

  final String? notes;
  final bool isAiGenerated;

  /// AI colour-harmony score (0.0–1.0). Null for manually created outfits.
  final double? harmonyScore;

  final DateTime createdAt;

  factory Outfit.fromJson(Map<String, dynamic> json) {
    return Outfit(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      name: json['name'] as String,
      occasion: json['occasion'] as String?,
      itemIds: (json['item_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      notes: json['notes'] as String?,
      isAiGenerated: json['is_ai_generated'] as bool? ?? false,
      harmonyScore: (json['harmony_score'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'name': name,
      if (occasion != null) 'occasion': occasion,
      'item_ids': itemIds,
      if (notes != null) 'notes': notes,
      'is_ai_generated': isAiGenerated,
      if (harmonyScore != null) 'harmony_score': harmonyScore,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Outfit copyWith({
    String? id,
    String? profileId,
    String? name,
    // Pass null to clear, omit to keep existing value.
    Object? occasion = _kSentinel,
    List<String>? itemIds,
    Object? notes = _kSentinel,
    bool? isAiGenerated,
    double? harmonyScore,
    DateTime? createdAt,
  }) {
    return Outfit(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      occasion: identical(occasion, _kSentinel) ? this.occasion : occasion as String?,
      itemIds: itemIds ?? this.itemIds,
      notes: identical(notes, _kSentinel) ? this.notes : notes as String?,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      harmonyScore: harmonyScore ?? this.harmonyScore,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Outfit(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Outfit && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
