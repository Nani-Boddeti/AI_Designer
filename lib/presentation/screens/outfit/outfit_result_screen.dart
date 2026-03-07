import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/wardrobe_item.dart';
import '../../../router/app_router.dart';
import '../../providers/outfit_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../../data/repositories/outfit_repository.dart';

class OutfitResultScreen extends ConsumerWidget {
  const OutfitResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final generated = ref.watch(generatedOutfitsProvider);

    if (generated.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Outfit Results')),
        body: const Center(
          child: Text('No outfits generated yet. Run a style session first.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Outfit Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Pick items manually',
            onPressed: () => context.push(AppRoutes.manualItemSelection),
          ),
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.virtualLineup),
            icon: const Icon(Icons.view_column_outlined),
            label: const Text('Lineup'),
          ),
        ],
      ),
      body: _buildGroupedBody(context, generated),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'save_all',
            onPressed: () => _saveAll(context, ref, generated),
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('Save All'),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'regenerate',
            onPressed: () {
              ref.read(generatedOutfitsProvider.notifier).clear();
              context.pop();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Regenerate'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedBody(
      BuildContext context, List<GeneratedOutfit> generated) {
    // Group by profileId preserving insertion order.
    final grouped = <String, List<GeneratedOutfit>>{};
    for (final g in generated) {
      grouped.putIfAbsent(g.outfit.profileId, () => []).add(g);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info banner
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  size: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Two outfit options per person — pick the one you love.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ),
        // Profile sections
        for (final entry in grouped.entries)
          _ProfileSection(
            profileName: entry.value.first.profileName,
            variants: entry.value
              ..sort((a, b) => a.variantNumber.compareTo(b.variantNumber)),
          ),
      ],
    );
  }

  Future<void> _saveAll(
    BuildContext context,
    WidgetRef ref,
    List<GeneratedOutfit> generated,
  ) async {
    for (final g in generated) {
      await ref
          .read(outfitProvider(g.outfit.profileId).notifier)
          .saveOutfit(g.outfit);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All outfits saved!')),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Profile section — header + variant cards
// ---------------------------------------------------------------------------

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.profileName,
    required this.variants,
  });

  final String profileName;
  final List<GeneratedOutfit> variants;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Profile header
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Row(
            children: [
              CircleAvatar(
                child: Text(profileName.isNotEmpty
                    ? profileName[0].toUpperCase()
                    : '?'),
              ),
              const SizedBox(width: 10),
              Text(profileName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
        // One card per variant
        for (final g in variants)
          _OutfitCard(
            generated: g,
            variantLabel: g.variantNumber == 1 ? 'Option A' : 'Option B',
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Outfit card — one variant
// ---------------------------------------------------------------------------

class _OutfitCard extends ConsumerStatefulWidget {
  const _OutfitCard({
    required this.generated,
    required this.variantLabel,
  });

  final GeneratedOutfit generated;
  final String variantLabel;

  @override
  ConsumerState<_OutfitCard> createState() => _OutfitCardState();
}

class _OutfitCardState extends ConsumerState<_OutfitCard> {
  bool _saved = false;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final outfit = widget.generated.outfit;
    await ref
        .read(outfitProvider(outfit.profileId).notifier)
        .saveOutfit(outfit);
    if (mounted) {
      setState(() {
        _saving = false;
        _saved = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final outfit = widget.generated.outfit;
    final profileId = outfit.profileId;
    final wardrobeAsync = ref.watch(wardrobeProvider(profileId));
    final colorScheme = Theme.of(context).colorScheme;

    final wardrobeItems = wardrobeAsync.value ?? [];
    final outfitItems = wardrobeItems
        .where((item) => outfit.itemIds.contains(item.id))
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header — variant label + match score
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(widget.variantLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                _MatchScorePill(score: widget.generated.harmonyScore),
              ],
            ),
          ),

          // Item images
          if (outfitItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: outfitItems.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) =>
                      _ItemThumbnail(item: outfitItems[i]),
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Wardrobe items not loaded yet.',
                  style: TextStyle(color: Colors.grey)),
            ),

          // Styling note
          if (widget.generated.stylingNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome,
                      size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.generated.stylingNote,
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

          // Save button — 3 states: default / saving / saved
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _saved
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.bookmark_added),
                    label: const Text('Saved'),
                  )
                : _saving
                    ? const OutlinedButton(
                        onPressed: null,
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: const Text('Save Outfit'),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ItemThumbnail extends StatelessWidget {
  const _ItemThumbnail({required this.item});

  final WardrobeItem item;

  @override
  Widget build(BuildContext context) {
    final url = item.displayImageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 100,
        color: Colors.grey[200],
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (_, _, e) =>
                    const Icon(Icons.broken_image),
              )
            : const Icon(Icons.image_outlined),
      ),
    );
  }
}

class _MatchScorePill extends StatelessWidget {
  const _MatchScorePill({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final pct = (score * 100).round();
    final color = score >= 0.7
        ? Colors.green
        : score >= 0.5
            ? Colors.amber
            : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$pct% Match',
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
