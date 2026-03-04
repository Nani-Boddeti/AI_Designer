import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/wardrobe_item.dart';

import '../../../router/app_router.dart';
import '../../providers/wardrobe_provider.dart';
import '../../providers/profile_provider.dart';

class WardrobeScreen extends ConsumerWidget {
  const WardrobeScreen({
    super.key,
    required this.profileId,
    this.showProfileSwitcher = false,
    this.profiles = const [],
    this.onProfileChanged,
  });

  final String profileId;
  final bool showProfileSwitcher;
  final List<Profile> profiles;
  final ValueChanged<String>? onProfileChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileByIdProvider(profileId));
    final wardrobeAsync = ref.watch(wardrobeProvider(profileId));
    final filter = ref.watch(wardrobeCategoryFilterProvider(profileId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(profile?.name ?? 'Wardrobe',
                style: const TextStyle(fontSize: 18)),
            if (profile != null)
              Text(profile.ageGroup.displayName,
                  style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outlined),
            tooltip: 'Saved Outfits',
            onPressed: () =>
                context.push(AppRoutes.savedOutfitsPath(profileId)),
          ),
          if (showProfileSwitcher && profiles.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Switch profile',
              onSelected: onProfileChanged,
              itemBuilder: (_) => profiles
                  .map((p) => PopupMenuItem(
                        value: p.id,
                        child: Text(p.name),
                      ))
                  .toList(),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(wardrobeProvider(profileId).notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter chips
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _FilterChip(
                  label: 'All',
                  selected: filter == null,
                  onSelected: (_) => ref
                      .read(wardrobeCategoryFilterProvider(profileId).notifier)
                      .state = null,
                ),
                ...WardrobeCategory.values.map(
                  (cat) => _FilterChip(
                    label: cat.displayName,
                    selected: filter == cat,
                    onSelected: (_) => ref
                        .read(wardrobeCategoryFilterProvider(profileId)
                            .notifier)
                        .state = cat,
                  ),
                ),
              ],
            ),
          ),

          // Grid
          Expanded(
            child: wardrobeAsync.when(
              loading: () => _ShimmerGrid(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (_) {
                final items =
                    ref.watch(filteredWardrobeProvider(profileId));
                if (items.isEmpty) {
                  return _EmptyWardrobe(profileId: profileId);
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) => _WardrobeItemCard(
                    item: items[i],
                    onTap: () => ctx.push(
                      AppRoutes.itemDetailPath(profileId, items[i].id),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            context.push(AppRoutes.addItemPath(profileId)),
        child: const Icon(Icons.add_a_photo_outlined),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chip
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wardrobe item card
// ---------------------------------------------------------------------------

class _WardrobeItemCard extends StatelessWidget {
  const _WardrobeItemCard({
    required this.item,
    required this.onTap,
  });

  final WardrobeItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = item.displayImageUrl;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
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
                      errorWidget: (_, _, e) =>
                          const Icon(Icons.broken_image),
                    )
                  : Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.image_outlined, size: 32),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                item.name,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyWardrobe extends StatelessWidget {
  const _EmptyWardrobe({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.style_outlined, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No items yet',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Add your first clothing item',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () =>
                context.push(AppRoutes.addItemPath(profileId)),
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
          ),
        ],
      ),
    );
  }
}
