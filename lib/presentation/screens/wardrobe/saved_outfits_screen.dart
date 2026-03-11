import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
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
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Saved Outfits'),
        backgroundColor: AppTheme.scaffoldBg,
      ),
      body: outfitsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(child: Text(userFriendlyError(e))),
        data: (outfits) {
          if (outfits.isEmpty) {
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
                      child: const Icon(Icons.bookmark_outline,
                          size: 40, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No saved outfits yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onBgColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Generate outfits and tap Save to keep them here.',
                      style: TextStyle(color: AppTheme.onSurfaceVar),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
    final wardrobeItems =
        ref.watch(wardrobeProvider(profileId)).value ?? [];
    final outfitItems =
        wardrobeItems.where((i) => outfit.itemIds.contains(i.id)).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0CB07050),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ───────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (outfit.isAiGenerated) ...[
                            const Icon(Icons.auto_awesome,
                                size: 14, color: AppTheme.secondary),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              outfit.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppTheme.onBgColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (outfit.occasion != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            outfit.occasion!,
                            style: const TextStyle(
                              color: AppTheme.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (outfit.harmonyScore != null)
                  _ScorePill(score: outfit.harmonyScore!),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: const Color(0xFFB00020),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmDelete(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            // ── Item thumbnails ──────────────────────────────────────
            if (outfitItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: outfitItems.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final url = outfitItems[i].displayImageUrl;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 80,
                        decoration: const BoxDecoration(
                          gradient: AppTheme.garmentBackground,
                        ),
                        child: url != null
                            ? CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.contain,
                                errorWidget: (_, _, _) => const Icon(
                                  Icons.checkroom_outlined,
                                  color: AppTheme.onSurfaceVar,
                                ),
                              )
                            : const Icon(
                                Icons.checkroom_outlined,
                                color: AppTheme.onSurfaceVar,
                              ),
                      ),
                    );
                  },
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${outfit.itemIds.length} item${outfit.itemIds.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppTheme.onSurfaceVar, fontSize: 13),
                ),
              ),

            // ── Notes ───────────────────────────────────────────────
            if (outfit.notes != null && outfit.notes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                outfit.notes!,
                style: const TextStyle(
                    fontSize: 12, height: 1.5, color: AppTheme.onSurfaceVar),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
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
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) onDelete();
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    final pct = (score * 100).round();
    final color = score >= 0.7
        ? AppTheme.tertiary
        : score >= 0.5
            ? AppTheme.secondary
            : const Color(0xFFB00020);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$pct% match',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
