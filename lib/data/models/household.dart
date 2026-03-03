/// Represents a household – the top-level unit that groups family members.
class Household {
  const Household({
    required this.id,
    required this.name,
    required this.inviteCode,
    this.hemisphere = 'north',
    required this.createdAt,
  });

  final String id;
  final String name;
  final String inviteCode;

  /// 'north' or 'south' — determines season mapping for outfit filtering.
  final String hemisphere;

  final DateTime createdAt;

  factory Household.fromJson(Map<String, dynamic> json) {
    return Household(
      id: json['id'] as String,
      name: json['name'] as String,
      inviteCode: json['invite_code'] as String,
      hemisphere: json['hemisphere'] as String? ?? 'north',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'invite_code': inviteCode,
      'hemisphere': hemisphere,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Household copyWith({
    String? id,
    String? name,
    String? inviteCode,
    String? hemisphere,
    DateTime? createdAt,
  }) {
    return Household(
      id: id ?? this.id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      hemisphere: hemisphere ?? this.hemisphere,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Household(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Household && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
