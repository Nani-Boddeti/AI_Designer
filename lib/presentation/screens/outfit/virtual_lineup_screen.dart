import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/error_utils.dart';
import '../../../data/models/wardrobe_item.dart';
import '../../providers/outfit_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../../data/repositories/outfit_repository.dart';

class VirtualLineupScreen extends ConsumerStatefulWidget {
  const VirtualLineupScreen({super.key});

  @override
  ConsumerState<VirtualLineupScreen> createState() =>
      _VirtualLineupScreenState();
}

class _VirtualLineupScreenState extends ConsumerState<VirtualLineupScreen> {
  final _screenshotController = ScreenshotController();
  bool _capturing = false;

  Future<void> _captureAndShare() async {
    setState(() => _capturing = true);
    try {
      final bytes = await _screenshotController.capture();
      if (bytes == null || !mounted) return;

      // Write bytes to a temp file then share.
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/lineup_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Family Outfit Lineup',
        ),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final generated = ref.watch(generatedOutfitsProvider);
    final profilesAsync = ref.watch(profilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Virtual Lineup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: _capturing ? null : _captureAndShare,
            tooltip: 'Share',
          ),
        ],
      ),
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(userFriendlyError(e))),
        data: (profiles) {
          if (generated.isEmpty) {
            return const Center(
              child: Text(
                  'Run a style session first to see the lineup.'),
            );
          }

          // One column per profile — take the lowest variantNumber for each.
          final perProfile = <String, GeneratedOutfit>{};
          for (final g in generated) {
            final existing = perProfile[g.outfit.profileId];
            if (existing == null ||
                g.variantNumber < existing.variantNumber) {
              perProfile[g.outfit.profileId] = g;
            }
          }
          final lineupItems = perProfile.values.toList();

          // All columns share the same number of item slots — the max across
          // all members — so a member with 1 item gets the same column height
          // as one with 3, keeping the lineup visually aligned.
          final maxItemCount = lineupItems
              .map((g) => g.outfit.itemIds.length)
              .fold(1, (a, b) => a > b ? a : b);

          return Screenshot(
            controller: _screenshotController,
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                children: [
                  // Title banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      'Family Outfit Lineup',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),

                  // One column per family member
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(16),
                      itemCount: lineupItems.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => _ProfileColumn(
                        generatedOutfit: lineupItems[i],
                        maxItemCount: maxItemCount,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _capturing ? null : _captureAndShare,
        icon: _capturing
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.camera_alt_outlined),
        label: const Text('Screenshot'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// A single profile's outfit column
// ---------------------------------------------------------------------------

class _ProfileColumn extends ConsumerWidget {
  const _ProfileColumn({
    required this.generatedOutfit,
    required this.maxItemCount,
  });

  final GeneratedOutfit generatedOutfit;
  final int maxItemCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outfit = generatedOutfit.outfit;
    final wardrobeAsync = ref.watch(wardrobeProvider(outfit.profileId));
    final wardrobeItems = wardrobeAsync.value ?? [];
    final outfitItems = wardrobeItems
        .where((item) => outfit.itemIds.contains(item.id))
        .toList();

    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 140,
      child: Column(
        children: [
          // Profile header
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 20,
                  child: Text(
                    generatedOutfit.profileName.isNotEmpty
                        ? generatedOutfit.profileName[0].toUpperCase()
                        : '?',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  generatedOutfit.profileName,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Stacked item images
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: outfitItems.isEmpty
                  ? const Center(
                      child: Text('No items', style: TextStyle(color: Colors.grey)),
                    )
                  : _StackedItems(items: outfitItems, maxItemCount: maxItemCount),
            ),
          ),
        ],
      ),
    );
  }
}

class _StackedItems extends StatelessWidget {
  const _StackedItems({required this.items, required this.maxItemCount});

  final List<WardrobeItem> items;
  final int maxItemCount;

  @override
  Widget build(BuildContext context) {
    // Available height is divided equally into maxItemCount slots.
    // Members with fewer items get empty slots — keeping all columns aligned.
    return Column(
      children: List.generate(maxItemCount, (i) {
        final hasItem = i < items.length;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: hasItem
                ? _ItemTile(item: items[i])
                : Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
          ),
        );
      }),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});

  final WardrobeItem item;

  @override
  Widget build(BuildContext context) {
    final url = item.displayImageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url,
              fit: item.processedImageUrl != null
                  ? BoxFit.contain
                  : BoxFit.cover,
              placeholder: (_, _) => Container(color: Colors.grey[200]),
              errorWidget: (_, _, _) => const Icon(Icons.broken_image),
            )
          : Container(
              color: Colors.grey[200],
              child: const Icon(Icons.image_outlined),
            ),
    );
  }
}
