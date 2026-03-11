import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
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
    this.embeddedInHome = false,
    this.profiles = const [],
    this.onProfileChanged,
  });

  final String profileId;
  final bool showProfileSwitcher;
  final bool embeddedInHome;
  final List<Profile> profiles;
  final ValueChanged<String>? onProfileChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileByIdProvider(profileId));
    final wardrobeAsync = ref.watch(wardrobeProvider(profileId));
    final catFilter = ref.watch(wardrobeCategoryFilterProvider(profileId));
    final subFilter = ref.watch(wardrobeSubcategoryFilterProvider(profileId));

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        automaticallyImplyLeading: !embeddedInHome,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile?.name ?? 'Wardrobe',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.onBgColor,
              ),
            ),
            if (profile != null)
              Text(
                profile.ageGroup.displayName,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVar,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outlined),
            tooltip: 'Saved Outfits',
            color: AppTheme.onSurfaceVar,
            onPressed: () =>
                context.push(AppRoutes.savedOutfitsPath(profileId)),
          ),
          if (showProfileSwitcher && profiles.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.swap_horiz, color: AppTheme.onSurfaceVar),
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
            icon: const Icon(Icons.refresh_outlined),
            color: AppTheme.onSurfaceVar,
            onPressed: () =>
                ref.read(wardrobeProvider(profileId).notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Drill-down filter chips ────────────────────────────────────
          _DrillDownFilter(profileId: profileId),

          const Divider(height: 1),

          // ── Grid ──────────────────────────────────────────────────────
          Expanded(
            child: wardrobeAsync.when(
              loading: () => const _ShimmerGrid(),
              error: (e, _) => Center(
                child: Text(
                  userFriendlyError(e),
                  style: const TextStyle(color: AppTheme.onSurfaceVar),
                ),
              ),
              data: (_) {
                final items = ref.watch(filteredWardrobeProvider(profileId));
                if (items.isEmpty) {
                  return _EmptyWardrobe(
                    profileId: profileId,
                    hasFilter: catFilter != null || subFilter != null,
                  );
                }
                final notifier =
                    ref.read(wardrobeProvider(profileId).notifier);
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _WardrobeItemCard(
                            item: items[i],
                            onTap: () => ctx.push(
                              AppRoutes.itemDetailPath(
                                  profileId, items[i].id),
                            ),
                          ),
                          childCount: items.length,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: notifier.hasMore
                          ? _LoadMoreSentinel(
                              onVisible: () => notifier.loadMore())
                          : const SizedBox(height: 96),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: embeddedInHome
          ? null
          : FloatingActionButton(
              onPressed: () =>
                  context.push(AppRoutes.addItemPath(profileId)),
              child: const Icon(Icons.add_a_photo_outlined),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Drill-down filter bar
// ---------------------------------------------------------------------------

class _DrillDownFilter extends ConsumerWidget {
  const _DrillDownFilter({required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catFilter = ref.watch(wardrobeCategoryFilterProvider(profileId));
    final subFilter = ref.watch(wardrobeSubcategoryFilterProvider(profileId));
    final catNotifier =
        ref.read(wardrobeCategoryFilterProvider(profileId).notifier);
    final subNotifier =
        ref.read(wardrobeSubcategoryFilterProvider(profileId).notifier);

    // Show subcategory row when a category is selected
    final showSubcategories = catFilter != null;
    final subcategories = showSubcategories
        ? WardrobeSubcategories.forCategory(catFilter)
        : <String>[];

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: showSubcategories
            // ── Subcategory level ──────────────────────────────────
            ? [
                // Back chip
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    avatar: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 12),
                    label: Text(catFilter.displayName),
                    onPressed: () {
                      catNotifier.set(null);
                      subNotifier.set(null);
                    },
                    backgroundColor: AppTheme.primaryContainer,
                    labelStyle: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                  ),
                ),
                // All subcategories option
                _SubChip(
                  label: 'All ${catFilter.displayName}',
                  selected: subFilter == null,
                  onTap: () => subNotifier.set(null),
                ),
                ...subcategories.map(
                  (sub) => _SubChip(
                    label: sub,
                    selected: subFilter == sub,
                    onTap: () => subNotifier.set(sub),
                  ),
                ),
              ]
            // ── Category level ─────────────────────────────────────
            : [
                _CatChip(
                  label: 'All',
                  selected: catFilter == null,
                  onTap: () {
                    catNotifier.set(null);
                    subNotifier.set(null);
                  },
                ),
                ...WardrobeCategory.values.map(
                  (cat) => _CatChip(
                    label: cat.displayName,
                    selected: catFilter == cat,
                    onTap: () {
                      catNotifier.set(cat);
                      subNotifier.set(null);
                    },
                  ),
                ),
              ],
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
        selectedColor: AppTheme.primaryContainer,
        checkmarkColor: AppTheme.primary,
        labelStyle: TextStyle(
          color: selected ? AppTheme.primary : AppTheme.onSurfaceVar,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _SubChip extends StatelessWidget {
  const _SubChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
        selectedColor: AppTheme.secondaryContainer,
        checkmarkColor: AppTheme.secondary,
        labelStyle: TextStyle(
          color: selected ? AppTheme.secondary : AppTheme.onSurfaceVar,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wardrobe item card — studio lightbox background
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
    final imageUrl = item.displayImageUrl;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image area with studio gradient ───────────────────
            Expanded(
              flex: 5,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.garmentBackground,
                ),
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, _) => const _ShimmerBox(),
                        errorWidget: (_, _, _) => const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppTheme.onSurfaceVar,
                            size: 32,
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.checkroom_outlined,
                          color: AppTheme.onSurfaceVar,
                          size: 36,
                        ),
                      ),
              ),
            ),

            // ── Info area ─────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onBgColor,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.subcategory != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.subcategory!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.onSurfaceVar,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
// Helpers
// ---------------------------------------------------------------------------

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox();
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEDE4D8),
      highlightColor: const Color(0xFFF8F2EC),
      child: Container(color: Colors.white),
    );
  }
}

class _LoadMoreSentinel extends StatefulWidget {
  const _LoadMoreSentinel({required this.onVisible});
  final VoidCallback onVisible;
  @override
  State<_LoadMoreSentinel> createState() => _LoadMoreSentinelState();
}

class _LoadMoreSentinelState extends State<_LoadMoreSentinel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) { if (mounted) widget.onVisible(); });
  }
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}

class _ShimmerGrid extends StatelessWidget {
  const _ShimmerGrid();
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEDE4D8),
      highlightColor: const Color(0xFFF8F2EC),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: 6,
        itemBuilder: (_, _) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _EmptyWardrobe extends StatelessWidget {
  const _EmptyWardrobe({required this.profileId, this.hasFilter = false});
  final String profileId;
  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppTheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.style_outlined,
                  size: 40, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              hasFilter ? 'No items in this category' : 'Wardrobe is empty',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.onBgColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'Try a different filter or add new items'
                  : 'Add your first outfit piece to get started',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.onSurfaceVar,
              ),
              textAlign: TextAlign.center,
            ),
            if (!hasFilter) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () =>
                    context.push(AppRoutes.addItemPath(profileId)),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Item'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
