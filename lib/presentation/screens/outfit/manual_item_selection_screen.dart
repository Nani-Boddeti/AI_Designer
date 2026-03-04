import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../data/models/wardrobe_item.dart';
import '../../providers/outfit_provider.dart';

class ManualItemSelectionScreen extends ConsumerStatefulWidget {
  const ManualItemSelectionScreen({super.key});

  @override
  ConsumerState<ManualItemSelectionScreen> createState() =>
      _ManualItemSelectionScreenState();
}

class _ManualItemSelectionScreenState
    extends ConsumerState<ManualItemSelectionScreen> {
  final Map<String, Set<String>> _selectedIds = {};
  bool _generating = false;

  int get _totalSelected =>
      _selectedIds.values.fold(0, (sum, s) => sum + s.length);

  void _toggle(String profileId, String itemId) {
    setState(() {
      final set = _selectedIds.putIfAbsent(profileId, () => {});
      if (set.contains(itemId)) {
        set.remove(itemId);
      } else {
        set.add(itemId);
      }
    });
  }

  void _selectAll(String profileId, List<WardrobeItem> items) {
    setState(() {
      _selectedIds[profileId] = items.map((i) => i.id).toSet();
    });
  }

  void _clearProfile(String profileId) {
    setState(() {
      _selectedIds[profileId] = {};
    });
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final notifier = ref.read(generatedOutfitsProvider.notifier);
      final pinnedMap = <String, List<WardrobeItem>>{};
      for (final p in notifier.lastProfiles) {
        final ids = _selectedIds[p.id] ?? {};
        if (ids.isNotEmpty) {
          final all = ref.read(allWardrobeItemsProvider(p.id)).value ??
              <WardrobeItem>[];
          pinnedMap[p.id] = all.where((i) => ids.contains(i.id)).toList();
        }
      }
      await notifier.generate(
        profiles: notifier.lastProfiles,
        occasion: notifier.lastOccasion,
        eventDate: notifier.lastEventDate,
        pinnedItemsByProfile: pinnedMap.isEmpty ? null : pinnedMap,
      );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(generatedOutfitsProvider.notifier);
    final profiles = notifier.lastProfiles;

    if (profiles.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pick Items to Style')),
        body: const Center(child: Text('No active session.')),
      );
    }

    return DefaultTabController(
      length: profiles.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pick Items to Style'),
          bottom: TabBar(
            isScrollable: profiles.length > 3,
            tabs: profiles.map((p) {
              final count = _selectedIds[p.id]?.length ?? 0;
              return Tab(
                text: count > 0 ? '${p.name} ($count)' : p.name,
              );
            }).toList(),
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                'Profiles with no selection use AI auto-pick',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: TabBarView(
                children: profiles
                    .map(
                      (p) => _ProfileTab(
                        profileId: p.id,
                        selectedIds: _selectedIds[p.id] ?? {},
                        onToggle: (itemId) => _toggle(p.id, itemId),
                        onSelectAll: (items) => _selectAll(p.id, items),
                        onClear: () => _clearProfile(p.id),
                      ),
                    )
                    .toList(),
              ),
            ),
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color:
                          Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '$_totalSelected item${_totalSelected == 1 ? '' : 's'} selected',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _generating ? null : _generate,
                      child: _generating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Text('Generate Outfits'),
                    ),
                  ],
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
// Per-profile tab
// ---------------------------------------------------------------------------

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab({
    required this.profileId,
    required this.selectedIds,
    required this.onToggle,
    required this.onSelectAll,
    required this.onClear,
  });

  final String profileId;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;
  final ValueChanged<List<WardrobeItem>> onSelectAll;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(allWardrobeItemsProvider(profileId));
    return itemsAsync.when(
      loading: () => _ShimmerGrid(),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $e'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  ref.invalidate(allWardrobeItemsProvider(profileId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No items in wardrobe'));
        }
        return Column(
          children: [
            _SelectionHeader(
              count: selectedIds.length,
              total: items.length,
              onSelectAll: () => onSelectAll(items),
              onClear: onClear,
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.75,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) => _SelectableItemCard(
                  item: items[i],
                  isSelected: selectedIds.contains(items[i].id),
                  onTap: () => onToggle(items[i].id),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Selection header
// ---------------------------------------------------------------------------

class _SelectionHeader extends StatelessWidget {
  const _SelectionHeader({
    required this.count,
    required this.total,
    required this.onSelectAll,
    required this.onClear,
  });

  final int count;
  final int total;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Text(
            '$count / $total selected',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          TextButton(onPressed: onSelectAll, child: const Text('Select All')),
          TextButton(onPressed: onClear, child: const Text('Clear')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Selectable item card
// ---------------------------------------------------------------------------

class _SelectableItemCard extends StatelessWidget {
  const _SelectableItemCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final WardrobeItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = item.displayImageUrl;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isSelected
              ? BorderSide(color: colorScheme.primary, width: 2)
              : BorderSide.none,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            color: colorScheme.surfaceContainerHighest,
                          ),
                          errorWidget: (_, _, _) =>
                              const Icon(Icons.broken_image),
                        )
                      : Container(
                          color: colorScheme.surfaceContainerHighest,
                          child:
                              const Icon(Icons.image_outlined, size: 32),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    item.name,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (isSelected) ...[
              Positioned.fill(
                child: Container(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  Icons.check_circle,
                  color: colorScheme.primary,
                  size: 22,
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
// Shimmer placeholder grid
// ---------------------------------------------------------------------------

class _ShimmerGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.75,
        ),
        itemCount: 9,
        itemBuilder: (_, _) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
