import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/models/calendar_event.dart';
import '../../../data/models/outfit.dart';
import '../../../data/models/profile.dart';
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
          rowHeight: 72,
          calendarStyle: const CalendarStyle(
            outsideDaysVisible: true,
            outsideTextStyle: TextStyle(color: AppTheme.onSurfaceVar, fontSize: 13),
            defaultTextStyle: TextStyle(color: AppTheme.onBgColor, fontSize: 13),
            weekendTextStyle: TextStyle(color: AppTheme.onBgColor, fontSize: 13),
            weekNumberTextStyle: TextStyle(color: AppTheme.onSurfaceVar, fontSize: 11),
            todayDecoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            selectedDecoration: BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            // Default markers hidden — replaced by calendarBuilders.markerBuilder
            markersMaxCount: 0,
          ),
          headerStyle: HeaderStyle(
            titleCentered: true,
            formatButtonVisible: true,
            titleTextStyle: const TextStyle(
              color: AppTheme.onBgColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            leftChevronIcon: const Icon(Icons.chevron_left, color: AppTheme.onSurfaceVar),
            rightChevronIcon: const Icon(Icons.chevron_right, color: AppTheme.onSurfaceVar),
            formatButtonDecoration: BoxDecoration(
              border: Border.all(color: AppTheme.dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            formatButtonTextStyle: const TextStyle(
              color: AppTheme.onSurfaceVar,
              fontSize: 12,
            ),
          ),
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(
              color: AppTheme.onSurfaceVar,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            weekendStyle: TextStyle(
              color: AppTheme.onSurfaceVar,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          calendarBuilders: CalendarBuilders<CalendarEvent>(
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return null;
              return _DayOutfitMarker(events: events);
            },
          ),
        ),

        // Loading/error strip — only shown while data is fetching.
        eventsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(12),
            child: Text(userFriendlyError(e),
                style: const TextStyle(color: AppTheme.onSurfaceVar)),
          ),
          data: (_) => const SizedBox.shrink(),
        ),

        // Selected day panel — replaces the static hint.
        Expanded(
          child: _SelectedDayPanel(
            selectedDay: _selectedDay,
            events: _selectedDay != null ? _getEventsForDay(_selectedDay!) : [],
            onAddEvent: () => _showAddEventDialog(_selectedDay ?? DateTime.now()),
            onEditEvent: _showEventDetailFromPanel,
          ),
        ),
      ],
    );

    // When embedded in HomeScreen, the FAB lives on HomeScreen's Scaffold.
    // Listen to the signal provider so HomeScreen can trigger the dialog.
    if (widget.embeddedInHome) {
      ref.listen(calendarAddEventSignalProvider, (prev, next) {
        if (mounted) _showAddEventDialog(_selectedDay ?? DateTime.now());
      });
      return Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(title: const Text('Style Calendar'), backgroundColor: AppTheme.scaffoldBg),
        body: body,
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

  /// Always shows a list of events for [date].
  /// Tapping an event opens its detail sheet on top.
  /// Opens the event detail sheet directly from the inline panel.
  /// Only one sheet is open so onDelete doesn't need to double-pop.
  void _showEventDetailFromPanel(CalendarEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EventDetailSheet(
        event: event,
        onDelete: () {
          ref.read(calendarProvider.notifier).deleteEvent(event.id);
        },
      ),
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

class _OutfitPickerSheet extends ConsumerStatefulWidget {
  const _OutfitPickerSheet({
    required this.eventId,
    required this.profileId,
    required this.profileName,
  });

  final String eventId;
  final String profileId;
  final String profileName;

  @override
  ConsumerState<_OutfitPickerSheet> createState() =>
      _OutfitPickerSheetState();
}

class _OutfitPickerSheetState extends ConsumerState<_OutfitPickerSheet> {
  String? _assigningId;

  Future<void> _assign(String outfitId) async {
    setState(() => _assigningId = outfitId);
    try {
      await ref
          .read(calendarProvider.notifier)
          .assignOutfit(widget.eventId, widget.profileId, outfitId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _assigningId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final outfitsAsync = ref.watch(outfitProvider(widget.profileId));

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
            child: Text('Pick outfit for ${widget.profileName}',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: outfitsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text(userFriendlyError(e))),
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
                  itemBuilder: (_, i) => _OutfitPickerTile(
                    outfit: outfits[i],
                    profileId: widget.profileId,
                    isAssigning: _assigningId == outfits[i].id,
                    isDisabled: _assigningId != null,
                    onTap: _assigningId == null
                        ? () => _assign(outfits[i].id)
                        : null,
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

class _OutfitPickerTile extends ConsumerWidget {
  const _OutfitPickerTile({
    required this.outfit,
    required this.profileId,
    required this.isAssigning,
    required this.isDisabled,
    required this.onTap,
  });

  final Outfit outfit;
  final String profileId;
  final bool isAssigning;
  final bool isDisabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final coverAsync = ref.watch(
      outfitCoverUrlProvider((profileId: profileId, outfitId: outfit.id)),
    );

    return ListTile(
      enabled: !isDisabled,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 52,
          height: 52,
          child: coverAsync.when(
            loading: () => Container(
              color: colorScheme.surfaceContainerHighest,
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
            ),
            error: (_, _) => Container(
              color: colorScheme.surfaceContainerHighest,
              child: Icon(Icons.checkroom,
                  size: 24, color: colorScheme.onSurfaceVariant),
            ),
            data: (url) => url != null
                ? CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.checkroom,
                          size: 24, color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.checkroom,
                        size: 24, color: colorScheme.onSurfaceVariant),
                  ),
          ),
        ),
      ),
      title: Text(outfit.name),
      subtitle: Text(
        [
          if (outfit.occasion != null) outfit.occasion!,
          '${outfit.itemIds.length} item${outfit.itemIds.length == 1 ? '' : 's'}',
        ].join(' · '),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: isAssigning
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: colorScheme.primary),
            )
          : Icon(Icons.chevron_right,
              color: isDisabled ? colorScheme.onSurface.withValues(alpha: 0.3) : null),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Selected-day inline panel — replaces "Tap an event date to view details"
// ---------------------------------------------------------------------------

class _SelectedDayPanel extends ConsumerWidget {
  const _SelectedDayPanel({
    required this.selectedDay,
    required this.events,
    required this.onAddEvent,
    required this.onEditEvent,
  });

  final DateTime? selectedDay;
  final List<CalendarEvent> events;
  final VoidCallback onAddEvent;
  final void Function(CalendarEvent) onEditEvent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedDay == null || events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined,
                size: 36, color: AppTheme.onSurfaceVar.withValues(alpha: 0.5)),
            const SizedBox(height: 10),
            Text(
              selectedDay == null
                  ? 'Tap a date to view outfit assignments'
                  : 'No events on this day',
              style: const TextStyle(color: AppTheme.onSurfaceVar),
            ),
            if (selectedDay != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Event'),
                onPressed: onAddEvent,
              ),
            ],
          ],
        ),
      );
    }

    final profilesAsync = ref.watch(profilesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _formatDate(selectedDay!),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.onBgColor,
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Event'),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: onAddEvent,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _EventSummaryCard(
              event: events[i],
              profilesAsync: profilesAsync,
              onEdit: () => onEditEvent(events[i]),
            ),
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return '${days[d.weekday % 7]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ---------------------------------------------------------------------------
// Single event summary card shown in the inline panel
// ---------------------------------------------------------------------------

class _EventSummaryCard extends StatelessWidget {
  const _EventSummaryCard({
    required this.event,
    required this.profilesAsync,
    required this.onEdit,
  });

  final CalendarEvent event;
  final AsyncValue<List<Profile>> profilesAsync;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final assignments = event.outfitAssignments; // Map<profileId, outfitId>
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event header row
            Row(
              children: [
                const Icon(Icons.celebration_outlined,
                    size: 16, color: AppTheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.onBgColor,
                        ),
                      ),
                      if (event.occasion != null)
                        Text(
                          event.occasion!,
                          style: TextStyle(
                              fontSize: 11, color: colorScheme.primary),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('Edit'),
                ),
              ],
            ),

            // Assigned members
            if (assignments.isNotEmpty) ...[
              const Divider(height: 14),
              profilesAsync.when(
                loading: () => const SizedBox(
                  height: 20,
                  child: LinearProgressIndicator(),
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (profiles) {
                  final assigned = profiles
                      .where((p) => assignments.containsKey(p.id))
                      .toList();
                  if (assigned.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: assigned
                        .map((p) => _AssignedProfileRow(
                              profile: p,
                              outfitId: assignments[p.id]!,
                            ))
                        .toList(),
                  );
                },
              ),
            ] else ...[
              const SizedBox(height: 6),
              Text(
                'No outfits assigned yet — tap Edit to assign',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-profile row inside the event summary card
// ---------------------------------------------------------------------------

class _AssignedProfileRow extends ConsumerWidget {
  const _AssignedProfileRow({
    required this.profile,
    required this.outfitId,
  });

  final Profile profile;
  final String outfitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final coverAsync = ref.watch(
      outfitCoverUrlProvider((profileId: profile.id, outfitId: outfitId)),
    );
    final outfitsAsync = ref.watch(outfitProvider(profile.id));
    final outfitName = outfitsAsync.whenOrNull(
      data: (outfits) =>
          outfits.where((o) => o.id == outfitId).firstOrNull?.name,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          // Profile avatar
          CircleAvatar(
            radius: 14,
            backgroundColor: colorScheme.secondaryContainer,
            backgroundImage: profile.avatarUrl != null
                ? NetworkImage(profile.avatarUrl!)
                : null,
            child: profile.avatarUrl == null
                ? Text(
                    profile.name.isNotEmpty
                        ? profile.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            profile.name,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
          const SizedBox(width: 6),
          Icon(Icons.arrow_forward_ios,
              size: 10, color: AppTheme.onSurfaceVar.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          // Outfit thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 36,
              height: 36,
              child: coverAsync.when(
                data: (url) => url != null
                    ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
                    : Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.checkroom,
                            size: 16, color: colorScheme.onSurfaceVariant),
                      ),
                loading: () => Container(
                    color: colorScheme.surfaceContainerHighest),
                error: (_, _) => Container(
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.checkroom,
                      size: 16, color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              outfitName ?? '',
              style: TextStyle(fontSize: 12, color: colorScheme.primary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day outfit thumbnail — shown inside calendar date cells
// ---------------------------------------------------------------------------

class _DayOutfitMarker extends ConsumerWidget {
  const _DayOutfitMarker({required this.events});
  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Collect all assignments across all events for this day
    final assignments = <({String profileId, String outfitId})>[];
    for (final event in events) {
      for (final entry in event.outfitAssignments.entries) {
        assignments.add((profileId: entry.key, outfitId: entry.value));
      }
    }
    if (assignments.isEmpty) {
      // Event exists but no outfit assigned — show a soft indicator dot
      return Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.only(top: 3),
        decoration: const BoxDecoration(
          color: AppTheme.secondary,
          shape: BoxShape.circle,
        ),
      );
    }

    final first = assignments.first;
    final coverAsync = ref.watch(
      outfitCoverUrlProvider((profileId: first.profileId, outfitId: first.outfitId)),
    );
    final extraCount = assignments.length - 1;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Thumbnail
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: AppTheme.garmentBackground,
              ),
              clipBehavior: Clip.antiAlias,
              child: coverAsync.when(
                data: (url) => url != null
                    ? CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        errorWidget: (_, _, _) => const Icon(
                          Icons.checkroom_outlined,
                          size: 18,
                          color: AppTheme.onSurfaceVar,
                        ),
                      )
                    : const Icon(
                        Icons.checkroom_outlined,
                        size: 18,
                        color: AppTheme.onSurfaceVar,
                      ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const Icon(
                  Icons.checkroom_outlined,
                  size: 18,
                  color: AppTheme.onSurfaceVar,
                ),
              ),
            ),
            // +N badge
            if (extraCount > 0)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    '+$extraCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
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
