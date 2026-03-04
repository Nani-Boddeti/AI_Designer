import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/outfit.dart';
import '../../providers/outfit_provider.dart';
import '../../providers/wardrobe_provider.dart';

class SavedOutfitsScreen extends ConsumerWidget {
  const SavedOutfitsScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outfitsAsync = ref.watch(outfitProvider(profileId));

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Outfits')),
      body: outfitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (outfits) {
          if (outfits.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_outline,
                      size: 72, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('No saved outfits yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text(
                    'Generate outfits and tap Save to keep them here.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSizes.paddingMd),
            itemCount: outfits.length,
            itemBuilder: (context, i) => _SavedOutfitCard(
              outfit: outfits[i],
              profileId: profileId,
              onDelete: () => ref
                  .read(outfitProvider(profileId).notifier)
                  .deleteOutfit(outfits[i].id),
            ),
          );
        },
      ),
    );
  }
}

class _SavedOutfitCard extends ConsumerWidget {
  const _SavedOutfitCard({
    required this.outfit,
    required this.profileId,
    required this.onDelete,
  });

  final Outfit outfit;
  final String profileId;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wardrobeAsync = ref.watch(wardrobeProvider(profileId));
    final wardrobeItems = wardrobeAsync.value ?? [];
    final outfitItems =
        wardrobeItems.where((i) => outfit.itemIds.contains(i.id)).toList();
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(outfit.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (outfit.occasion != null)
                        Text(outfit.occasion!,
                            style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 12)),
                    ],
                  ),
                ),
                if (outfit.isAiGenerated)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.auto_awesome,
                        size: 16, color: colorScheme.primary),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: colorScheme.error,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ),
            if (outfitItems.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: outfitItems.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final url = outfitItems[i].displayImageUrl;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 80,
                        color: colorScheme.surfaceContainerHighest,
                        child: url != null
                            ? CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                                errorWidget: (_, _, _) =>
                                    const Icon(Icons.broken_image),
                              )
                            : const Icon(Icons.image_outlined),
                      ),
                    );
                  },
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${outfit.itemIds.length} items',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            if (outfit.notes != null && outfit.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(outfit.notes!,
                  style: const TextStyle(fontSize: 12, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Outfit'),
        content: Text('Delete "${outfit.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) onDelete();
  }
}
