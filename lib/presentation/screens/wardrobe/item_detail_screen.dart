import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/color_harmony.dart';
import '../../../data/models/wardrobe_item.dart';
import '../../providers/wardrobe_provider.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  const ItemDetailScreen({
    super.key,
    required this.profileId,
    required this.itemId,
  });

  final String profileId;
  final String itemId;

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  bool _isEditing = false;
  final _nameCtrl = TextEditingController();
  WardrobeCategory? _editCategory;

  WardrobeItem? _item;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadItem());
  }

  void _loadItem() {
    final items = ref.read(wardrobeProvider(widget.profileId)).value ?? [];
    final item = items.cast<WardrobeItem?>().firstWhere(
          (i) => i?.id == widget.itemId,
          orElse: () => null,
        );
    if (item != null) {
      setState(() {
        _item = item;
        _nameCtrl.text = item.name;
        _editCategory = item.category;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveEdits() async {
    if (_item == null) return;
    final updated = _item!.copyWith(
      name: _nameCtrl.text.trim(),
      category: _editCategory ?? _item!.category,
    );
    await ref.read(wardrobeProvider(widget.profileId).notifier).updateItem(updated);
    setState(() {
      _item = updated;
      _isEditing = false;
    });
  }

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Item?'),
        content: const Text('This item will be permanently removed.'),
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

    if (confirmed != true || _item == null) return;

    await ref
        .read(wardrobeProvider(widget.profileId).notifier)
        .deleteItem(_item!.id);

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    // Keep item in sync with wardrobe provider reactively.
    ref.listen<AsyncValue<List<WardrobeItem>>>(
      wardrobeProvider(widget.profileId),
      (_, next) {
        next.whenData((items) {
          final fresh = items.cast<WardrobeItem?>().firstWhere(
                (i) => i?.id == widget.itemId,
                orElse: () => null,
              );
          if (fresh != null && fresh != _item) {
            setState(() => _item = fresh);
          }
        });
      },
    );

    if (_item == null) {
      return const Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final item = _item!;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(
          item.name,
          style: const TextStyle(color: AppTheme.onBgColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppTheme.scaffoldBg,
        actions: [
          if (_isEditing) ...[
            IconButton(
              onPressed: _saveEdits,
              icon: const Icon(Icons.check, color: AppTheme.primary),
            ),
            IconButton(
              onPressed: () => setState(() => _isEditing = false),
              icon: const Icon(Icons.close, color: AppTheme.onSurfaceVar),
            ),
          ] else ...[
            IconButton(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit_outlined, color: AppTheme.onSurfaceVar),
            ),
            IconButton(
              onPressed: _deleteItem,
              icon: const Icon(Icons.delete_outline, color: Color(0xFFB00020)),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image hero — studio lightbox background ──────────────
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.garmentBackground,
                ),
                child: item.displayImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.displayImageUrl!,
                        fit: BoxFit.contain,
                        placeholder: (_, _) => const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primary,
                          ),
                        ),
                        errorWidget: (_, _, _) => const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 64,
                            color: AppTheme.onSurfaceVar,
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.checkroom_outlined,
                          size: 64,
                          color: AppTheme.onSurfaceVar,
                        ),
                      ),
              ),
            ),

            // ── Info sheet — rounded top ──────────────────────────────
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle visual hint
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.dividerColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Name (editable)
                    if (_isEditing)
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Name'),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700),
                      )
                    else
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onBgColor,
                        ),
                      ),

                    const SizedBox(height: 10),

                    // Category + Subcategory chips
                    if (_isEditing)
                      DropdownButtonFormField<WardrobeCategory>(
                        // ignore: deprecated_member_use
                        value: _editCategory,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: WardrobeCategory.values
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c.displayName),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _editCategory = v),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        children: [
                          _InfoChip(
                            label: item.category.displayName,
                            icon: Icons.category_outlined,
                            bgColor: AppTheme.primaryContainer,
                            textColor: AppTheme.primary,
                          ),
                          if (item.subcategory != null)
                            _InfoChip(
                              label: item.subcategory!,
                              icon: Icons.style_outlined,
                              bgColor: AppTheme.secondaryContainer,
                              textColor: AppTheme.secondary,
                            ),
                        ],
                      ),

                    if (item.colors.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const _SectionLabel(label: 'Colors'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: List.generate(item.colors.length, (i) {
                          final hex = item.colors[i];
                          final name = i < item.colorNames.length
                              ? item.colorNames[i]
                              : hex;
                          final color = ColorHarmony.parseHex(hex);
                          return Chip(
                            avatar: CircleAvatar(
                              backgroundColor: color,
                              radius: 10,
                            ),
                            label: Text(name),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: AppTheme.inputFill,
                            side: BorderSide.none,
                          );
                        }),
                      ),
                    ],

                    if (item.styleTags.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const _SectionLabel(label: 'Style Tags'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: item.styleTags
                            .map((t) => Chip(
                                  label: Text(t),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: AppTheme.secondaryContainer,
                                  side: BorderSide.none,
                                ))
                            .toList(),
                      ),
                    ],

                    if (item.seasonTags.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const _SectionLabel(label: 'Seasons'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: item.seasonTags
                            .map((t) => Chip(
                                  avatar: const Icon(Icons.wb_sunny_outlined,
                                      size: 14),
                                  label: Text(t),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: AppTheme.tertiaryContainer,
                                  side: BorderSide.none,
                                ))
                            .toList(),
                      ),
                    ],

                    if (item.brand != null || item.size != null) ...[
                      const SizedBox(height: 20),
                      const _SectionLabel(label: 'Details'),
                      const SizedBox(height: 8),
                      if (item.brand != null)
                        _DetailRow(
                          icon: Icons.label_outline,
                          text: 'Brand: ${item.brand}',
                        ),
                      if (item.size != null)
                        _DetailRow(
                          icon: Icons.straighten_outlined,
                          text: 'Size: ${item.size}',
                        ),
                    ],

                    if (item.aiDescription != null) ...[
                      const SizedBox(height: 20),
                      const _SectionLabel(label: 'AI Description'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.inputFill,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.auto_awesome,
                                size: 16, color: AppTheme.secondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.aiDescription!,
                                style: const TextStyle(
                                  height: 1.6,
                                  fontSize: 13,
                                  color: AppTheme.onBgColor,
                                ),
                              ),
                            ),
                          ],
                        ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppTheme.primary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.textColor,
  });
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.onSurfaceVar),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.onBgColor,
            ),
          ),
        ],
      ),
    );
  }
}
