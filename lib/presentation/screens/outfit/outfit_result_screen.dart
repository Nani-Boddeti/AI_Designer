import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/color_harmony.dart';
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
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: generated.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'AI selected items from each person\'s wardrobe that work together for this occasion.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            );
          }
          return _OutfitCard(generated: generated[i - 1]);
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'save_all',
            onPressed: () => _saveAll(context, ref, generated),
            child: const Icon(Icons.save_outlined),
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
// Outfit card per profile
// ---------------------------------------------------------------------------

class _OutfitCard extends ConsumerWidget {
  const _OutfitCard({required this.generated});

  final GeneratedOutfit generated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outfit = generated.outfit;
    final profileId = outfit.profileId;
    final wardrobeAsync = ref.watch(wardrobeProvider(profileId));
    final colorScheme = Theme.of(context).colorScheme;

    final wardrobeItems = wardrobeAsync.value ?? [];
    final outfitItems = wardrobeItems
        .where((item) => outfit.itemIds.contains(item.id))
        .toList();

    final harmonyColors = outfitItems
        .expand((i) => i.colors.map(ColorHarmony.parseHex))
        .toList();
    final harmonyScore = ColorHarmony.scoreOutfitHarmony(harmonyColors);
    final harmonyLabel = ColorHarmony.harmonyLabel(harmonyScore);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                CircleAvatar(
                  child: Text(generated.profileName.isNotEmpty
                      ? generated.profileName[0].toUpperCase()
                      : '?'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(generated.profileName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(outfit.occasion ?? '',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                _HarmonyBadge(score: harmonyScore, label: harmonyLabel),
              ],
            ),
          ),

          // Item images grid
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
          if (generated.stylingNote.isNotEmpty)
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
                      generated.stylingNote,
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

          // Save button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: OutlinedButton.icon(
              onPressed: () => ref
                  .read(outfitProvider(profileId).notifier)
                  .saveOutfit(outfit)
                  .then((_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            '${generated.profileName}\'s outfit saved!')),
                  );
                }
              }),
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

class _HarmonyBadge extends StatelessWidget {
  const _HarmonyBadge({required this.score, required this.label});

  final double score;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = score >= 0.7
        ? Colors.green
        : score >= 0.5
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
