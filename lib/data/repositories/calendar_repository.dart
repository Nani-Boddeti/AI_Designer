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
    final json = event.toJson()
      ..remove('id')
      ..remove('created_at');

    final data = await _service.client
        .from(SupabaseTables.calendarEvents)
        .update(json)
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

  Future<CalendarEvent> assignOutfit(
      String eventId, String profileId, String outfitId) async {
    final row = await _service.client
        .from(SupabaseTables.calendarEvents)
        .select()
        .eq('id', eventId)
        .single();
    final event = CalendarEvent.fromJson(row);
    final updated = Map<String, String>.from(event.outfitAssignments)
      ..[profileId] = outfitId;
    final data = await _service.client
        .from(SupabaseTables.calendarEvents)
        .update({'outfit_assignments': updated})
        .eq('id', eventId)
        .select()
        .single();
    return CalendarEvent.fromJson(data);
  }

  Future<CalendarEvent> removeOutfitAssignment(
      String eventId, String profileId) async {
    final row = await _service.client
        .from(SupabaseTables.calendarEvents)
        .select()
        .eq('id', eventId)
        .single();
    final event = CalendarEvent.fromJson(row);
    final updated = Map<String, String>.from(event.outfitAssignments)
      ..remove(profileId);
    final data = await _service.client
        .from(SupabaseTables.calendarEvents)
        .update({'outfit_assignments': updated})
        .eq('id', eventId)
        .select()
        .single();
    return CalendarEvent.fromJson(data);
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
        .gte('event_date', from.toIso8601String().split('T').first)
        .lte('event_date', to.toIso8601String().split('T').first)
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
