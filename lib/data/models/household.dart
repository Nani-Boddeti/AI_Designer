
// Sentinel for copyWith — lets callers pass null to explicitly clear tierExpiresAt.
const _kSentinel = Object();

/// Represents a household – the top-level unit that groups family members.
class Household {
  const Household({
    required this.id,
    required this.name,
    required this.inviteCode,
    this.hemisphere = 'north',
    this.tier = 'free',
    this.tierExpiresAt,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String inviteCode;

  /// 'north' or 'south' — determines season mapping for outfit filtering.
  final String hemisphere;

  /// 'free', 'pro', or 'prime'.
  final String tier;

  /// When the paid tier expires. null for free-tier households.
  final DateTime? tierExpiresAt;

  final DateTime createdAt;

  /// True when tier is 'pro' and the subscription has not yet expired.
  bool get isProActive =>
      tier == 'pro' && (tierExpiresAt?.isAfter(DateTime.now()) ?? false);

  /// True when tier is 'prime' and the subscription has not yet expired.
  bool get isPrimeActive =>
      tier == 'prime' && (tierExpiresAt?.isAfter(DateTime.now()) ?? false);

  /// True when any paid tier (pro or prime) is active.
  bool get isSubscribed => isProActive || isPrimeActive;

  factory Household.fromJson(Map<String, dynamic> json) {
    return Household(
      id: json['id'] as String,
      name: json['name'] as String,
      inviteCode: json['invite_code'] as String,
      hemisphere: json['hemisphere'] as String? ?? 'north',
      tier: json['tier'] as String? ?? 'free',
      tierExpiresAt: json['tier_expires_at'] != null
          ? DateTime.parse(json['tier_expires_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'invite_code': inviteCode,
      'hemisphere': hemisphere,
      'tier': tier,
      'tier_expires_at': tierExpiresAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  Household copyWith({
    String? id,
    String? name,
    String? inviteCode,
    String? hemisphere,
    String? tier,
    // Pass null explicitly to clear tierExpiresAt; omit to keep existing value.
    Object? tierExpiresAt = _kSentinel,
    DateTime? createdAt,
  }) {
    return Household(
      id: id ?? this.id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      hemisphere: hemisphere ?? this.hemisphere,
      tier: tier ?? this.tier,
      tierExpiresAt: identical(tierExpiresAt, _kSentinel)
          ? this.tierExpiresAt
          : tierExpiresAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Household(id: $id, name: $name, tier: $tier)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Household && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
