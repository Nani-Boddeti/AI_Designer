import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/calendar_event.dart';
import '../../data/repositories/calendar_repository.dart';
import 'auth_provider.dart';

// ---------------------------------------------------------------------------
// Calendar events notifier (household-scoped)
// ---------------------------------------------------------------------------

class CalendarNotifier extends AsyncNotifier<List<CalendarEvent>> {
  @override
  Future<List<CalendarEvent>> build() async {
    final authState = await ref.watch(authProvider.future);
    final householdId = authState.household?.id;
    if (householdId == null) return [];

    return ref.watch(calendarRepositoryProvider).getEventsForHousehold(householdId);
  }

  Future<void> createEvent(CalendarEvent event) async {
    final previous = state;
    try {
      final repo = ref.read(calendarRepositoryProvider);
      final created = await repo.createEvent(event);
      final existing = <CalendarEvent>[...(state.value ?? <CalendarEvent>[]), created];
      existing.sort((a, b) => a.eventDate.compareTo(b.eventDate));
      state = AsyncData<List<CalendarEvent>>(existing);
    } catch (e, st) {
      state = AsyncError<List<CalendarEvent>>(e, st);
      await Future.delayed(Duration.zero);
      state = previous;
      rethrow;
    }
  }

  Future<void> updateEvent(CalendarEvent event) async {
    final previous = state;
    try {
      final repo = ref.read(calendarRepositoryProvider);
      final updated = await repo.updateEvent(event);
      final events = <CalendarEvent>[...(state.value ?? <CalendarEvent>[])];
      final idx = events.indexWhere((e) => e.id == event.id);
      if (idx >= 0) events[idx] = updated;
      events.sort((a, b) => a.eventDate.compareTo(b.eventDate));
      state = AsyncData<List<CalendarEvent>>(events);
    } catch (e, st) {
      state = AsyncError<List<CalendarEvent>>(e, st);
      await Future.delayed(Duration.zero);
      state = previous;
      rethrow;
    }
  }

  Future<void> deleteEvent(String eventId) async {
    final previous = state;
    try {
      final repo = ref.read(calendarRepositoryProvider);
      await repo.deleteEvent(eventId);
      final events = <CalendarEvent>[...(state.value ?? <CalendarEvent>[])]
        ..removeWhere((e) => e.id == eventId);
      state = AsyncData<List<CalendarEvent>>(events);
    } catch (e, st) {
      state = AsyncError<List<CalendarEvent>>(e, st);
      await Future.delayed(Duration.zero);
      state = previous;
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  /// Returns events for a specific day.
  List<CalendarEvent> eventsForDay(DateTime day) {
    return (state.value ?? []).where((e) {
      return e.eventDate.year == day.year &&
          e.eventDate.month == day.month &&
          e.eventDate.day == day.day;
    }).toList();
  }
}

final calendarProvider =
    AsyncNotifierProvider<CalendarNotifier, List<CalendarEvent>>(
  CalendarNotifier.new,
);

/// A derived provider that converts events to a map for TableCalendar.
final calendarEventsMapProvider =
    Provider<Map<DateTime, List<CalendarEvent>>>((ref) {
  final events = ref.watch(calendarProvider).value ?? [];
  final Map<DateTime, List<CalendarEvent>> map = {};
  for (final event in events) {
    final day = DateTime(
        event.eventDate.year, event.eventDate.month, event.eventDate.day);
    map.putIfAbsent(day, () => []).add(event);
  }
  return map;
});
