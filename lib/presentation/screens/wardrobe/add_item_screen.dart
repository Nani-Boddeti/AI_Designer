import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/wardrobe_item.dart';
import '../../providers/wardrobe_provider.dart';

class AddItemScreen extends ConsumerStatefulWidget {
  const AddItemScreen({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  Uint8List? _imageBytes;
  bool _isProcessing = false;
  bool _isPrivate = false;
  String _step = '';
  String? _errorMessage;
  WardrobeItem? _result;
  Timer? _stepPollTimer;
  List<String> _selectedSeasons = [];

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _result = null;
      _errorMessage = null;
    });
  }

  Future<void> _processAndSave() async {
    if (_imageBytes == null) return;
    setState(() {
      _isProcessing = true;
      _step = 'Starting…';
      _errorMessage = null;
    });

    try {
      // The notifier's addItem handles the pipeline and calls onStep.
      final notifier = ref.read(wardrobeProvider(widget.profileId).notifier);

      // We can't pass onStep into the notifier directly from here in a clean way,
      // so we poll _currentStep or we wire it differently.
      // For simplicity, we trigger the pipeline and update step from the notifier.
      _startStepPolling();

      final item = await notifier.addItem(_imageBytes!, isPrivate: _isPrivate);

      setState(() {
        _result = item;
        _selectedSeasons = [];
        _isProcessing = false;
        _step = 'Done!';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
      });
    }
  }

  void _startStepPolling() {
    _stepPollTimer?.cancel();
    _stepPollTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted || !_isProcessing) {
        _stepPollTimer?.cancel();
        return;
      }
      final notifier = ref.read(wardrobeProvider(widget.profileId).notifier);
      setState(() => _step = notifier.currentStep);
    });
  }

  @override
  void dispose() {
    _stepPollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Clothing Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image preview / picker
            GestureDetector(
              onTap: _isProcessing ? null : () => _showSourceSheet(),
              child: Container(
                height: 280,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: _imageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.memory(
                          _imageBytes!,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 56, color: colorScheme.primary),
                          const SizedBox(height: 12),
                          const Text('Tap to add a photo'),
                          const SizedBox(height: 4),
                          Text(
                            'Camera or Gallery',
                            style: TextStyle(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            if (!_isProcessing && _result == null) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
              if (_imageBytes != null) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.lock_outline),
                  title: const Text('Private item'),
                  subtitle: const Text('Hide from other household members'),
                  value: _isPrivate,
                  onChanged: (v) => setState(() => _isPrivate = v),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _processAndSave,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('AI Process & Save'),
                ),
              ],
            ],

            // Progress steps
            if (_isProcessing) ...[
              const SizedBox(height: 24),
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              _StepIndicator(step: _step),
              const SizedBox(height: 8),
              const _StepList(),
            ],

            // Error
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _processAndSave,
                child: const Text('Retry'),
              ),
            ],

            // Result
            if (_result != null) ...[
              const SizedBox(height: 16),
              _ResultCard(item: _result!),
              if (_result!.seasonTags.isEmpty) ...[
                const SizedBox(height: 16),
                _SeasonFallbackPicker(
                  selected: _selectedSeasons,
                  onToggle: (season) => setState(() {
                    _selectedSeasons.contains(season)
                        ? _selectedSeasons.remove(season)
                        : _selectedSeasons.add(season);
                  }),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _doneOrSaveSeasons,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  _result!.seasonTags.isEmpty
                      ? (_selectedSeasons.isNotEmpty ? 'Save & Done' : 'Skip')
                      : 'Done',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _imageBytes = null;
                    _result = null;
                    _selectedSeasons = [];
                    _step = '';
                  });
                },
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add Another'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _doneOrSaveSeasons() async {
    if (_result != null && _result!.seasonTags.isEmpty) {
      final seasons =
          _selectedSeasons.isNotEmpty ? _selectedSeasons : ['Untagged'];
      final notifier =
          ref.read(wardrobeProvider(widget.profileId).notifier);
      try {
        await notifier.updateItem(_result!.copyWith(seasonTags: seasons));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save season tag: $e')),
          );
        }
        return;
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting widgets
// ---------------------------------------------------------------------------

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final String step;

  @override
  Widget build(BuildContext context) {
    return Text(
      step,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _StepList extends StatelessWidget {
  const _StepList();

  static const steps = [
    'Compressing image',
    'Removing background',
    'AI tagging',
    'Uploading images',
    'Saving to wardrobe',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: steps.map((s) => _StepRow(label: s)).toList(),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.item});

  final WardrobeItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Item Added!',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(item.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Category: ${item.category.displayName}'),
          if (item.aiDescription != null) ...[
            const SizedBox(height: 8),
            Text(item.aiDescription!,
                style: const TextStyle(color: Colors.grey)),
          ],
          if (item.colorNames.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: item.colorNames
                  .map((c) => Chip(
                        label: Text(c),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Season fallback picker
// ---------------------------------------------------------------------------

class _SeasonFallbackPicker extends StatelessWidget {
  const _SeasonFallbackPicker({
    required this.selected,
    required this.onToggle,
  });

  final List<String> selected;
  final void Function(String season) onToggle;

  static const _seasons = SeasonOptions.all;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.info_outline, size: 16, color: Colors.orange),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'AI couldn\'t detect the season. Tag it now — untagged items won\'t appear in outfit suggestions.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.orange),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _seasons
              .map((s) => FilterChip(
                    label: Text(s),
                    selected: selected.contains(s),
                    onSelected: (_) => onToggle(s),
                    visualDensity: VisualDensity.compact,
                  ))
              .toList(),
        ),
      ],
    );
  }
}
