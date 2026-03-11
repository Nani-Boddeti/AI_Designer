class HouseholdMembership {
  const HouseholdMembership({
    required this.id,
    required this.userId,
    required this.householdId,
    required this.isAdmin,
    required this.joinedAt,
  });

  final String id;
  final String userId;
  final String householdId;
  final bool isAdmin;
  final DateTime joinedAt;

  factory HouseholdMembership.fromJson(Map<String, dynamic> json) {
    return HouseholdMembership(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      householdId: json['household_id'] as String,
      isAdmin: json['is_admin'] as bool,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}
