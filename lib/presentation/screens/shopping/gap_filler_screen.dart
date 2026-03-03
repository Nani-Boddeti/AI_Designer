import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/color_harmony.dart';
import '../../../core/utils/shopping_links.dart';
import '../../../data/models/profile.dart';
import '../../../domain/usecases/analyze_gaps_usecase.dart';
import '../../providers/profile_provider.dart';

class GapFillerScreen extends ConsumerStatefulWidget {
  const GapFillerScreen({super.key});

  @override
  ConsumerState<GapFillerScreen> createState() => _GapFillerScreenState();
}

class _GapFillerScreenState extends ConsumerState<GapFillerScreen> {
  Profile? _selectedProfile;
  List<Map<String, dynamic>> _gaps = [];
  bool _analyzing = false;
  String? _error;

  Future<void> _analyze() async {
    if (_selectedProfile == null) return;
    setState(() {
      _analyzing = true;
      _error = null;
      _gaps = [];
    });

    try {
      final results =
          await ref.read(analyzeGapsUseCaseProvider).execute(_selectedProfile!);
      setState(() => _gaps = results);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(profilesProvider);

    // Set initial profile selection reactively without mutating state in build.
    ref.listen<AsyncValue<List<Profile>>>(profilesProvider, (_, next) {
      next.whenData((profiles) {
        if (_selectedProfile == null && profiles.isNotEmpty) {
          setState(() => _selectedProfile = profiles.first);
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Gap Filler')),
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profiles) {
          if (profiles.isEmpty) {
            return const Center(child: Text('Add family members first.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile selector
                DropdownButtonFormField<Profile>(
                  // ignore: deprecated_member_use
                  value: _selectedProfile,
                  decoration: const InputDecoration(
                    labelText: 'Select Family Member',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: profiles
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p.name),
                          ))
                      .toList(),
                  onChanged: (p) {
                    setState(() {
                      _selectedProfile = p;
                      _gaps = [];
                      _error = null;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Analyse button
                FilledButton.icon(
                  onPressed: _analyzing ? null : _analyze,
                  icon: _analyzing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_fix_high),
                  label: Text(
                      _analyzing ? 'Analysing…' : 'Analyse Wardrobe'),
                ),
                const SizedBox(height: 16),

                // Error
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!),
                  ),

                // Gap recommendations
                ..._gaps.map((gap) => _GapCard(gap: gap)),

                if (_gaps.isEmpty && !_analyzing)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Text(
                        'Select a member and tap "Analyse Wardrobe" to find gaps.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual gap recommendation card
// ---------------------------------------------------------------------------

class _GapCard extends StatelessWidget {
  const _GapCard({required this.gap});

  final Map<String, dynamic> gap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final itemName = gap['item_name'] as String? ?? 'Unknown Item';
    final category = gap['category'] as String? ?? '';
    final reason = gap['reason'] as String? ?? '';
    final searchQuery = gap['search_query'] as String? ?? itemName;
    final colors = (gap['colors'] as List?)?.cast<String>() ?? [];
    final colorNames = (gap['color_names'] as List?)?.cast<String>() ?? [];

    final shopLinks = ShoppingLinks.allLinks(searchQuery).take(3).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + category
            Row(
              children: [
                Expanded(
                  child: Text(
                    itemName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                if (category.isNotEmpty)
                  Chip(
                    label: Text(
                        WardrobeCategory.fromString(category).displayName),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Colors
            if (colors.isNotEmpty)
              Wrap(
                spacing: 6,
                children: List.generate(colors.length, (i) {
                  final color = ColorHarmony.parseHex(colors[i]);
                  final name =
                      i < colorNames.length ? colorNames[i] : colors[i];
                  return Chip(
                    avatar: CircleAvatar(
                        backgroundColor: color, radius: 8),
                    label: Text(name),
                    visualDensity: VisualDensity.compact,
                  );
                }),
              ),

            if (colors.isNotEmpty) const SizedBox(height: 8),

            // Reason
            Text(reason, style: const TextStyle(color: Colors.grey, height: 1.4)),
            const SizedBox(height: 12),

            // Shop buttons
            Text(
              'Shop Now',
              style: TextStyle(
                  color: colorScheme.primary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: shopLinks
                  .map((link) => _ShopButton(link: link))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopButton extends StatelessWidget {
  const _ShopButton({required this.link});

  final ShopLink link;

  Future<void> _launch() async {
    final uri = Uri.parse(link.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: _launch,
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: Text('${link.icon} ${link.name}', style: const TextStyle(fontSize: 12)),
    );
  }
}
