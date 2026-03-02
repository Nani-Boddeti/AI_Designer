import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/calendar_event.dart';
import '../../../data/repositories/calendar_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';

class StyleCalendarScreen extends ConsumerStatefulWidget {
  const StyleCalendarScreen({super.key, this.embeddedInHome = false});

  final bool embeddedInHome;

  @override
  ConsumerState<StyleCalendarScreen> createState() =>
      _StyleCalendarScreenState();
}

class _StyleCalendarScreenState
    extends ConsumerState<StyleCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final map = ref.read(calendarEventsMapProvider);
    return map[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(calendarProvider);
    final eventsMap = ref.watch(calendarEventsMapProvider);

    final body = Column(
      children: [
        // Calendar widget
        TableCalendar<CalendarEvent>(
          firstDay: DateTime.utc(2020),
          lastDay: DateTime.utc(2030),
          focusedDay: _focusedDay,
          selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
          calendarFormat: _calendarFormat,
          onFormatChanged: (f) => setState(() => _calendarFormat = f),
          eventLoader: (d) => eventsMap[DateTime(d.year, d.month, d.day)] ?? [],
          onDaySelected: (selected, focused) {
            setState(() {
              _selectedDay = selected;
              _focusedDay = focused;
            });
          },
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            markerDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              shape: BoxShape.circle,
            ),
          ),
        ),

        const Divider(height: 1),

        // Events list for selected day
        Expanded(
          child: eventsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (_) {
              if (_selectedDay == null) {
                return const Center(
                  child: Text('Tap a day to view events',
                      style: TextStyle(color: Colors.grey)),
                );
              }
              final dayEvents = _getEventsForDay(_selectedDay!);
              if (dayEvents.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No events on this day',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _showAddEventDialog(_selectedDay!),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Event'),
                      ),
                    ],
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  ...dayEvents.map((e) => _EventTile(
                        event: e,
                        onDelete: () => ref
                            .read(calendarProvider.notifier)
                            .deleteEvent(e.id),
                      )),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showAddEventDialog(_selectedDay!),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Another Event'),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );

    if (widget.embeddedInHome) {
      return Scaffold(
        appBar: AppBar(title: const Text('Style Calendar')),
        body: body,
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddEventDialog(_selectedDay ?? DateTime.now()),
          child: const Icon(Icons.add),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Style Calendar')),
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventDialog(_selectedDay ?? DateTime.now()),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddEventDialog(DateTime date) {
    showDialog(
      context: context,
      builder: (ctx) => _AddEventDialog(date: date, ref: ref),
    );
  }
}

// ---------------------------------------------------------------------------
// Event tile
// ---------------------------------------------------------------------------

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.onDelete});

  final CalendarEvent event;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.event_outlined),
        title: Text(event.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.occasion != null) Text('Occasion: ${event.occasion}'),
            if (event.notes != null)
              Text(event.notes!,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Delete Event?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete')),
                ],
              ),
            );
            if (confirmed == true) onDelete();
          },
        ),
        isThreeLine: event.occasion != null && event.notes != null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add event dialog
// ---------------------------------------------------------------------------

class _AddEventDialog extends ConsumerStatefulWidget {
  const _AddEventDialog({required this.date, required this.ref});

  final DateTime date;
  final WidgetRef ref;

  @override
  ConsumerState<_AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends ConsumerState<_AddEventDialog> {
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _occasion;
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Style Event'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Event Title'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _occasion,
              decoration: const InputDecoration(labelText: 'Occasion'),
              hint: const Text('Select occasion'),
              items: OccasionOptions.all
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) => setState(() => _occasion = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _addEvent,
          child: _loading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Add'),
        ),
      ],
    );
  }

  Future<void> _addEvent() async {
    if (_titleCtrl.text.trim().isEmpty) return;

    setState(() => _loading = true);

    try {
      final authState = await ref.read(authProvider.future);
      final householdId = authState.household?.id;
      if (householdId == null) return;

      final repo = ref.read(calendarRepositoryProvider);
      final event = repo.newEvent(
        householdId: householdId,
        title: _titleCtrl.text.trim(),
        eventDate: widget.date,
        occasion: _occasion,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      await ref.read(calendarProvider.notifier).createEvent(event);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
