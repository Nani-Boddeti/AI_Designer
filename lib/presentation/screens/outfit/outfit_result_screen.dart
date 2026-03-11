import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/review_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/wardrobe_item.dart';
import '../../../router/app_router.dart';
import '../../providers/outfit_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../../data/repositories/outfit_repository.dart';

class OutfitResultScreen extends ConsumerStatefulWidget {
  const OutfitResultScreen({super.key});

  @override
  ConsumerState<OutfitResultScreen> createState() => _OutfitResultScreenState();
}

class _OutfitResultScreenState extends ConsumerState<OutfitResultScreen> {
  bool _savingAll = false;
  final Set<String> _savedIds = {};

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Outfit Results'),
        backgroundColor: AppTheme.scaffoldBg,
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
            onPressed: (_savingAll || _savedIds.length == generated.length)
                ? null
                : () => _saveAll(generated),
            icon: _savingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.bookmark_add_outlined),
            label: Text(_savingAll
                ? 'Saving…'
                : _savedIds.length == generated.length
                    ? 'All Saved'
                    : 'Save All'),
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

  Future<void> _saveAll(List<GeneratedOutfit> generated) async {
    setState(() => _savingAll = true);
    int newlySaved = 0;
    try {
      for (final g in generated) {
        // Skip outfits already saved individually.
        if (_savedIds.contains(g.outfit.id)) continue;
        final outfitWithScore =
            g.outfit.copyWith(harmonyScore: g.harmonyScore);
        await ref
            .read(outfitProvider(g.outfit.profileId).notifier)
            .saveOutfit(outfitWithScore);
        _savedIds.add(g.outfit.id);
        newlySaved++;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newlySaved == 0
                ? 'All outfits already saved!'
                : 'All outfits saved!'),
          ),
        );
        if (newlySaved > 0) ReviewService.requestIfEligible();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Some outfits could not be saved. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingAll = false);
    }
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
            savedIds: _savedIds,
            onSaved: (id) => setState(() => _savedIds.add(id)),
          ),
      ],
    );
  }

}

// ---------------------------------------------------------------------------
// Profile section — header + variant cards
// ---------------------------------------------------------------------------

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.profileName,
    required this.variants,
    required this.savedIds,
    required this.onSaved,
  });

  final String profileName;
  final List<GeneratedOutfit> variants;
  final Set<String> savedIds;
  final void Function(String id) onSaved;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Profile header
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 8),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryContainer,
                child: Text(
                  profileName.isNotEmpty ? profileName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(profileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.onBgColor,
                  )),
            ],
          ),
        ),
        // One card per variant
        for (final g in variants)
          _OutfitCard(
            generated: g,
            variantLabel: g.variantNumber == 1 ? 'Option A' : 'Option B',
            initialSaved: savedIds.contains(g.outfit.id),
            onSaved: () => onSaved(g.outfit.id),
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
    required this.initialSaved,
    required this.onSaved,
  });

  final GeneratedOutfit generated;
  final String variantLabel;
  final bool initialSaved;
  final VoidCallback onSaved;

  @override
  ConsumerState<_OutfitCard> createState() => _OutfitCardState();
}

class _OutfitCardState extends ConsumerState<_OutfitCard> {
  late bool _saved;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _saved = widget.initialSaved;
  }

  @override
  void didUpdateWidget(_OutfitCard old) {
    super.didUpdateWidget(old);
    if (widget.initialSaved && !_saved) {
      _saved = true;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final outfit = widget.generated.outfit
          .copyWith(harmonyScore: widget.generated.harmonyScore);
      await ref
          .read(outfitProvider(outfit.profileId).notifier)
          .saveOutfit(outfit);
      if (mounted) {
        setState(() { _saving = false; _saved = true; });
        widget.onSaved();
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outfit = widget.generated.outfit;
    final profileId = outfit.profileId;
    final wardrobeAsync = ref.watch(wardrobeProvider(profileId));

    final wardrobeItems = wardrobeAsync.value ?? [];
    final outfitItems = wardrobeItems
        .where((item) => outfit.itemIds.contains(item.id))
        .toList();

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header — variant label + match score
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.variantLabel,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                _MatchScorePill(score: widget.generated.harmonyScore),
              ],
            ),

            // Item images
            if (outfitItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: outfitItems.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) =>
                      _ItemThumbnail(item: outfitItems[i]),
                ),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Wardrobe items not loaded yet.',
                    style: TextStyle(color: AppTheme.onSurfaceVar)),
              ),

            // Styling note
            if (widget.generated.stylingNote.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.inputFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 15, color: AppTheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.generated.stylingNote,
                        style: const TextStyle(
                          height: 1.5,
                          fontSize: 13,
                          color: AppTheme.onBgColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Save button — 3 states: default / saving / saved
            const SizedBox(height: 12),
            _saved
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
          ],
        ),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 96,
        decoration: const BoxDecoration(
          gradient: AppTheme.garmentBackground,
        ),
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, _) => const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primary,
                    strokeWidth: 2,
                  ),
                ),
                errorWidget: (_, _, _) => const Center(
                  child: Icon(
                    Icons.checkroom_outlined,
                    color: AppTheme.onSurfaceVar,
                  ),
                ),
              )
            : const Center(
                child: Icon(
                  Icons.checkroom_outlined,
                  color: AppTheme.onSurfaceVar,
                ),
              ),
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
        ? AppTheme.tertiary
        : score >= 0.5
            ? AppTheme.secondary
            : const Color(0xFFB00020);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
