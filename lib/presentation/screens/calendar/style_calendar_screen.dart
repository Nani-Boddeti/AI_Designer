import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/models/calendar_event.dart';
import '../../../data/models/outfit.dart';
import '../../../data/repositories/calendar_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/outfit_provider.dart';
import '../../providers/profile_provider.dart';

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
            error: (e, _) => Center(child: Text(userFriendlyError(e))),
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
      builder: (ctx) => _AddEventDialog(date: date),
    );
  }
}

// ---------------------------------------------------------------------------
// Event tile
// ---------------------------------------------------------------------------

class _EventTile extends ConsumerWidget {
  const _EventTile({required this.event, required this.onDelete});

  final CalendarEvent event;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            if (event.outfitAssignments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: event.outfitAssignments.entries
                      .map((e) => _OutfitMiniThumb(
                            profileId: e.key,
                            outfitId: e.value,
                          ))
                      .toList(),
                ),
              ),
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
        onTap: () => _showEventDetail(context, ref),
        isThreeLine: event.occasion != null && event.notes != null,
      ),
    );
  }

  void _showEventDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EventDetailSheet(event: event, onDelete: onDelete),
    );
  }
}

// ---------------------------------------------------------------------------
// Event detail bottom sheet
// ---------------------------------------------------------------------------

class _EventDetailSheet extends ConsumerWidget {
  const _EventDetailSheet({required this.event, required this.onDelete});

  final CalendarEvent event;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollController) => Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                // Header
                Text(event.title,
                    style: Theme.of(context).textTheme.headlineSmall),
                if (event.occasion != null) ...[
                  const SizedBox(height: 4),
                  Chip(
                    label: Text(event.occasion!),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                if (event.notes != null) ...[
                  const SizedBox(height: 8),
                  Text(event.notes!,
                      style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.7))),
                ],
                const SizedBox(height: 20),

                // Assigned outfits section
                Text('Assigned Outfits',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                profilesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text(userFriendlyError(e)),
                  data: (profiles) => Column(
                    children: profiles
                        .map((profile) => _ProfileOutfitRow(
                              event: event,
                              profile: profile,
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Delete button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Event'),
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
                    if (confirmed == true) {
                      onDelete();
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-profile outfit assignment row (inside detail sheet)
// ---------------------------------------------------------------------------

class _ProfileOutfitRow extends ConsumerWidget {
  const _ProfileOutfitRow({required this.event, required this.profile});

  final CalendarEvent event;
  final dynamic profile; // Profile

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignedOutfitId = event.outfitAssignments[profile.id as String];
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.secondaryContainer,
            backgroundImage: (profile.avatarUrl as String?) != null
                ? NetworkImage(profile.avatarUrl as String)
                : null,
            child: (profile.avatarUrl as String?) == null
                ? Text(
                    (profile.name as String).isNotEmpty
                        ? (profile.name as String)[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name as String,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                if (assignedOutfitId != null)
                  _AssignedOutfitLabel(
                      profileId: profile.id as String,
                      outfitId: assignedOutfitId),
              ],
            ),
          ),
          if (assignedOutfitId != null)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remove outfit',
              onPressed: () async {
                await ref
                    .read(calendarProvider.notifier)
                    .removeOutfitAssignment(event.id, profile.id as String);
              },
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Assign'),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => _OutfitPickerSheet(
                  eventId: event.id,
                  profileId: profile.id as String,
                  profileName: profile.name as String,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Shows the name of the assigned outfit.
class _AssignedOutfitLabel extends ConsumerWidget {
  const _AssignedOutfitLabel(
      {required this.profileId, required this.outfitId});

  final String profileId;
  final String outfitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outfitsAsync = ref.watch(outfitProvider(profileId));
    return outfitsAsync.when(
      loading: () => const SizedBox(
          height: 14,
          width: 14,
          child: CircularProgressIndicator(strokeWidth: 1.5)),
      error: (e, st) => const SizedBox.shrink(),
      data: (outfits) {
        final outfit = outfits.where((o) => o.id == outfitId).firstOrNull;
        if (outfit == null) return const SizedBox.shrink();
        return Text(outfit.name,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary));
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Outfit picker bottom sheet
// ---------------------------------------------------------------------------

class _OutfitPickerSheet extends ConsumerWidget {
  const _OutfitPickerSheet({
    required this.eventId,
    required this.profileId,
    required this.profileName,
  });

  final String eventId;
  final String profileId;
  final String profileName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outfitsAsync = ref.watch(outfitProvider(profileId));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (_, scrollController) => Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text('Pick outfit for $profileName',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: outfitsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(userFriendlyError(e))),
              data: (outfits) {
                if (outfits.isEmpty) {
                  return const Center(
                    child: Text('No saved outfits for this member.',
                        style: TextStyle(color: Colors.grey)),
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: outfits.length,
                  itemBuilder: (_, i) =>
                      _OutfitPickerTile(
                        outfit: outfits[i],
                        onTap: () async {
                          await ref
                              .read(calendarProvider.notifier)
                              .assignOutfit(
                                  eventId, profileId, outfits[i].id);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OutfitPickerTile extends StatelessWidget {
  const _OutfitPickerTile({required this.outfit, required this.onTap});

  final Outfit outfit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.checkroom)),
      title: Text(outfit.name),
      subtitle: Text(
        [
          if (outfit.occasion != null) outfit.occasion!,
          '${outfit.itemIds.length} item${outfit.itemIds.length == 1 ? '' : 's'}',
        ].join(' · '),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Outfit mini thumbnail — 32px circle shown on the event tile
// ---------------------------------------------------------------------------

class _OutfitMiniThumb extends ConsumerWidget {
  const _OutfitMiniThumb({required this.profileId, required this.outfitId});

  final String profileId;
  final String outfitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(
      outfitCoverUrlProvider((profileId: profileId, outfitId: outfitId)),
    );
    final colorScheme = Theme.of(context).colorScheme;

    Widget child = urlAsync.when(
      data: (url) => url != null
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (ctx, url, err) =>
                  Icon(Icons.checkroom, size: 16, color: colorScheme.primary),
            )
          : Icon(Icons.checkroom, size: 16, color: colorScheme.primary),
      loading: () => const SizedBox.shrink(),
      error: (err, st) =>
          Icon(Icons.checkroom, size: 16, color: colorScheme.primary),
    );

    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(right: 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.primary, width: 1.5),
        color: colorScheme.surfaceContainerHighest,
      ),
      child: Center(child: child),
    );
  }
}

// ---------------------------------------------------------------------------
// Add event dialog
// ---------------------------------------------------------------------------

class _AddEventDialog extends ConsumerStatefulWidget {
  const _AddEventDialog({required this.date});

  final DateTime date;

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
          SnackBar(content: Text(userFriendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
