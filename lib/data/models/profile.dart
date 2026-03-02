import '../../core/constants/app_constants.dart';

/// Represents a family member profile within a household.
class Profile {
  const Profile({
    required this.id,
    required this.householdId,
    this.authUserId,
    required this.name,
    this.avatarUrl,
    required this.ageGroup,
    this.stylePersona = const [],
    this.fitPreferences = const {},
    required this.createdAt,
  });

  final String id;
  final String householdId;

  /// The Supabase auth UID of the owner, null for non-account members.
  final String? authUserId;

  final String name;
  final String? avatarUrl;
  final AgeGroup ageGroup;

  /// List of chosen style persona labels.
  final List<String> stylePersona;

  /// Arbitrary fit preference key-value pairs.
  final Map<String, dynamic> fitPreferences;

  final DateTime createdAt;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      authUserId: json['auth_user_id'] as String?,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      ageGroup: AgeGroup.fromString(json['age_group'] as String? ?? 'adult'),
      stylePersona: (json['style_persona'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      fitPreferences:
          (json['fit_preferences'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'household_id': householdId,
      if (authUserId != null) 'auth_user_id': authUserId,
      'name': name,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'age_group': ageGroup.value,
      'style_persona': stylePersona,
      'fit_preferences': fitPreferences,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Profile copyWith({
    String? id,
    String? householdId,
    String? authUserId,
    String? name,
    String? avatarUrl,
    AgeGroup? ageGroup,
    List<String>? stylePersona,
    Map<String, dynamic>? fitPreferences,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      authUserId: authUserId ?? this.authUserId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      ageGroup: ageGroup ?? this.ageGroup,
      stylePersona: stylePersona ?? this.stylePersona,
      fitPreferences: fitPreferences ?? this.fitPreferences,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Profile(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Profile && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
