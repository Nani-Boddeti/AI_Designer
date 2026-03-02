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
      'created_at': createdAt.toIso8601String(),
    };
  }

  Outfit copyWith({
    String? id,
    String? profileId,
    String? name,
    String? occasion,
    List<String>? itemIds,
    String? notes,
    bool? isAiGenerated,
    DateTime? createdAt,
  }) {
    return Outfit(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      occasion: occasion ?? this.occasion,
      itemIds: itemIds ?? this.itemIds,
      notes: notes ?? this.notes,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
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
