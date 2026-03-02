import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
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
    // Keep item in sync.
    final items = ref.watch(wardrobeProvider(widget.profileId)).value ?? [];
    final fresh = items.cast<WardrobeItem?>().firstWhere(
          (i) => i?.id == widget.itemId,
          orElse: () => _item,
        );
    if (fresh != null && fresh.id == widget.itemId && fresh != _item) {
      _item = fresh;
    }

    if (_item == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final item = _item!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        actions: [
          if (_isEditing) ...[
            IconButton(
                onPressed: _saveEdits, icon: const Icon(Icons.check)),
            IconButton(
                onPressed: () => setState(() => _isEditing = false),
                icon: const Icon(Icons.close)),
          ] else ...[
            IconButton(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit_outlined)),
            IconButton(
                onPressed: _deleteItem,
                icon: Icon(Icons.delete_outline,
                    color: colorScheme.error)),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                color: colorScheme.surfaceContainerHighest,
                child: item.displayImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.displayImageUrl!,
                        fit: item.processedImageUrl != null
                            ? BoxFit.contain
                            : BoxFit.cover,
                        placeholder: (_, _) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (_, _, e) =>
                            const Icon(Icons.broken_image, size: 64),
                      )
                    : const Icon(Icons.image_not_supported, size: 64),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name (editable)
                  if (_isEditing)
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    )
                  else
                    Text(item.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),

                  const SizedBox(height: 8),

                  // Category (editable)
                  if (_isEditing)
                    DropdownButtonFormField<WardrobeCategory>(
                      // ignore: deprecated_member_use
                      value: _editCategory,
                      decoration:
                          const InputDecoration(labelText: 'Category'),
                      items: WardrobeCategory.values
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.displayName),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _editCategory = v),
                    )
                  else
                    Chip(
                      label: Text(item.category.displayName),
                      avatar:
                          const Icon(Icons.category_outlined, size: 16),
                    ),

                  const SizedBox(height: 16),

                  // Colors
                  if (item.colors.isNotEmpty) ...[
                    _SectionLabel(label: 'Colors'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: List.generate(item.colors.length, (i) {
                        final hex = item.colors[i];
                        final name = i < item.colorNames.length
                            ? item.colorNames[i]
                            : hex;
                        final color = ColorHarmony.parseHex(hex);
                        return Chip(
                          avatar: CircleAvatar(
                              backgroundColor: color, radius: 10),
                          label: Text(name),
                          visualDensity: VisualDensity.compact,
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Style tags
                  if (item.styleTags.isNotEmpty) ...[
                    _SectionLabel(label: 'Style Tags'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: item.styleTags
                          .map((t) => Chip(
                                label: Text(t),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Season tags
                  if (item.seasonTags.isNotEmpty) ...[
                    _SectionLabel(label: 'Seasons'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: item.seasonTags
                          .map((t) => Chip(
                                avatar: const Icon(Icons.wb_sunny_outlined,
                                    size: 14),
                                label: Text(t),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Brand / Size
                  if (item.brand != null || item.size != null) ...[
                    _SectionLabel(label: 'Details'),
                    const SizedBox(height: 8),
                    if (item.brand != null)
                      _DetailRow(
                          icon: Icons.label_outline,
                          text: 'Brand: ${item.brand}'),
                    if (item.size != null)
                      _DetailRow(
                          icon: Icons.straighten_outlined,
                          text: 'Size: ${item.size}'),
                    const SizedBox(height: 16),
                  ],

                  // AI description
                  if (item.aiDescription != null) ...[
                    _SectionLabel(label: 'AI Description'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.aiDescription!,
                        style: const TextStyle(height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
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
      style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}
