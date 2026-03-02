/// A scheduled family style event on the calendar.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.householdId,
    required this.title,
    required this.eventDate,
    this.occasion,
    this.outfitAssignments = const {},
    this.weatherSnapshot = const {},
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String householdId;
  final String title;
  final DateTime eventDate;
  final String? occasion;

  /// Maps profileId → outfitId for the event.
  final Map<String, String> outfitAssignments;

  /// Cached weather data snapshot at event creation/update time.
  final Map<String, dynamic> weatherSnapshot;

  final String? notes;
  final DateTime createdAt;

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      title: json['title'] as String,
      eventDate: DateTime.parse(json['event_date'] as String),
      occasion: json['occasion'] as String?,
      outfitAssignments:
          (json['outfit_assignments'] as Map<String, dynamic>?)?.map(
                (k, v) => MapEntry(k, v.toString()),
              ) ??
              {},
      weatherSnapshot:
          (json['weather_snapshot'] as Map<String, dynamic>?) ?? {},
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'household_id': householdId,
      'title': title,
      'event_date': eventDate.toIso8601String(),
      if (occasion != null) 'occasion': occasion,
      'outfit_assignments': outfitAssignments,
      'weather_snapshot': weatherSnapshot,
      if (notes != null) 'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  CalendarEvent copyWith({
    String? id,
    String? householdId,
    String? title,
    DateTime? eventDate,
    String? occasion,
    Map<String, String>? outfitAssignments,
    Map<String, dynamic>? weatherSnapshot,
    String? notes,
    DateTime? createdAt,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      title: title ?? this.title,
      eventDate: eventDate ?? this.eventDate,
      occasion: occasion ?? this.occasion,
      outfitAssignments: outfitAssignments ?? this.outfitAssignments,
      weatherSnapshot: weatherSnapshot ?? this.weatherSnapshot,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'CalendarEvent(id: $id, title: $title, date: $eventDate)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEvent &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
