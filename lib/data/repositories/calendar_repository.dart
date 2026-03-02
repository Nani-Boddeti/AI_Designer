import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/calendar_event.dart';
import '../services/supabase_service.dart';
import '../../core/constants/app_constants.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(ref.watch(supabaseServiceProvider));
});

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class CalendarRepository {
  CalendarRepository(this._service);

  final SupabaseService _service;

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  Future<List<CalendarEvent>> getEventsForHousehold(
      String householdId) async {
    final data = await _service.client
        .from(SupabaseTables.calendarEvents)
        .select()
        .eq('household_id', householdId)
        .order('event_date');

    return (data as List).map((e) => CalendarEvent.fromJson(e)).toList();
  }

  Future<CalendarEvent> createEvent(CalendarEvent event) async {
    final json = event.toJson();
    json.remove('created_at');

    final data = await _service.client
        .from(SupabaseTables.calendarEvents)
        .insert(json)
        .select()
        .single();

    return CalendarEvent.fromJson(data);
  }

  Future<CalendarEvent> updateEvent(CalendarEvent event) async {
    final data = await _service.client
        .from(SupabaseTables.calendarEvents)
        .update(event.toJson())
        .eq('id', event.id)
        .select()
        .single();

    return CalendarEvent.fromJson(data);
  }

  Future<void> deleteEvent(String eventId) async {
    await _service.client
        .from(SupabaseTables.calendarEvents)
        .delete()
        .eq('id', eventId);
  }

  /// Returns events for a specific date range.
  Future<List<CalendarEvent>> getEventsBetween({
    required String householdId,
    required DateTime from,
    required DateTime to,
  }) async {
    final data = await _service.client
        .from(SupabaseTables.calendarEvents)
        .select()
        .eq('household_id', householdId)
        .gte('event_date', from.toIso8601String())
        .lte('event_date', to.toIso8601String())
        .order('event_date');

    return (data as List).map((e) => CalendarEvent.fromJson(e)).toList();
  }

  // ---------------------------------------------------------------------------
  // Factory helper
  // ---------------------------------------------------------------------------

  CalendarEvent newEvent({
    required String householdId,
    required String title,
    required DateTime eventDate,
    String? occasion,
    String? notes,
  }) {
    return CalendarEvent(
      id: const Uuid().v4(),
      householdId: householdId,
      title: title,
      eventDate: eventDate,
      occasion: occasion,
      notes: notes,
      createdAt: DateTime.now(),
    );
  }
}
