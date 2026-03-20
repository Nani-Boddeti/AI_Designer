import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/models/wardrobe_item.dart';
import '../../providers/wardrobe_provider.dart';

const _kAiDisclosureKey = 'ai_image_disclosure_accepted';

class AddItemScreen extends ConsumerStatefulWidget {
  const AddItemScreen({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  static const _maxImageBytes = 10 * 1024 * 1024; // 10 MB
  Uint8List? _imageBytes;
  bool _isProcessing = false;
  bool _isPrivate = false;
  bool _removeBackground = true;
  String _step = '';
  String? _errorMessage;
  WardrobeItem? _result;
  Timer? _stepPollTimer;
  List<String> _selectedSeasons = [];

  /// Shows the AI processing disclosure dialog on the first use.
  /// Returns false if the user declines, true if already accepted or just accepted.
  Future<bool> _ensureDisclosure() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kAiDisclosureKey) == true) return true;

    if (!mounted) return false;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('AI Image Processing'),
        content: const SingleChildScrollView(
          child: Text(
            'When you add a clothing item, your photo is processed by two '
            'third-party AI services:\n\n'
            '• Google Gemini — automatically tags the item\'s category, '
            'colors, and style.\n\n'
            '• rembg — removes the background for a cleaner wardrobe view.\n\n'
            'Photos are sent securely and are not stored by these services '
            'after processing. By continuing you agree to this use.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    if (accepted == true) {
      await prefs.setBool(_kAiDisclosureKey, true);
      return true;
    }
    return false;
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!await _ensureDisclosure()) return;
    final granted = await _ensurePermission(source);
    if (!granted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.lengthInBytes > _maxImageBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image too large (max 10 MB).')),
        );
      }
      return;
    }
    setState(() {
      _imageBytes = bytes;
      _result = null;
      _errorMessage = null;
    });
  }

  /// Gallery multi-select: if 1 image → existing single flow; if >1 → batch.
  Future<void> _pickMultipleImages() async {
    if (!await _ensureDisclosure()) return;
    final granted = await _ensurePermission(ImageSource.gallery);
    if (!granted) return;

    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 90);
    if (picked.isEmpty) return;

    if (picked.length == 1) {
      final bytes = await picked.first.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _result = null;
        _errorMessage = null;
      });
      return;
    }

    // Show batch options before processing.
    if (!mounted) return;
    final options = await _showBatchOptionsDialog(picked.length);
    if (options == null) return; // user cancelled

    await _processBatch(
      picked,
      isPrivate: options.$1,
      removeBackground: options.$2,
    );
  }

  /// Returns (isPrivate, removeBackground) or null if cancelled.
  Future<(bool, bool)?> _showBatchOptionsDialog(int count) async {
    bool isPrivate = false;
    bool removeBg = true;
    return showDialog<(bool, bool)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Add $count Items'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.lock_outline),
                title: const Text('Private items'),
                subtitle: const Text('Hide from household members'),
                value: isPrivate,
                onChanged: (v) => setS(() => isPrivate = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.auto_fix_high_outlined),
                title: const Text('Remove background'),
                subtitle: const Text('Cleaner wardrobe view'),
                value: removeBg,
                onChanged: (v) => setS(() => removeBg = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, (isPrivate, removeBg)),
              child: const Text('Add All'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processBatch(
    List<XFile> files, {
    bool isPrivate = false,
    bool removeBackground = true,
  }) async {
    final notifier = ref.read(wardrobeProvider(widget.profileId).notifier);
    final currentNotifier = ValueNotifier<int>(0);
    int succeeded = 0;

    if (!mounted) return;
    // Show non-dismissable progress sheet. Not awaited — driven by ValueNotifier.
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _BatchProgressSheet(
        total: files.length,
        currentNotifier: currentNotifier,
      ),
    );

    try {
      for (int i = 0; i < files.length; i++) {
        currentNotifier.value = i + 1;
        try {
          final bytes = await files[i].readAsBytes();
          await notifier.addItem(
            bytes,
            isPrivate: isPrivate,
            removeBackground: removeBackground,
          );
          succeeded++;
        } catch (_) {
          // Continue with remaining items.
        }
      }

      if (mounted) Navigator.of(context).pop();
    } finally {
      currentNotifier.dispose();
    }

    if (mounted) {
      final failed = files.length - succeeded;
      final msg = failed == 0
          ? '$succeeded item${succeeded == 1 ? '' : 's'} added'
          : '$succeeded added, $failed failed';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  /// Returns true if the required permission is granted or limited (partial).
  /// On Android 14+, "limited" means the user selected specific photos —
  /// image_picker still works; picker shows only their selected photos.
  /// Shows a Settings dialog only when permanently denied.
  Future<bool> _ensurePermission(ImageSource source) async {
    final permission =
        source == ImageSource.camera ? Permission.camera : Permission.photos;
    final status = await permission.status;

    // Both full and partial (limited) access allow image picking.
    if (status.isGranted || status.isLimited) return true;

    if (status.isPermanentlyDenied) {
      if (mounted) _showPermissionDeniedDialog(source);
      return false;
    }

    // System shows the dialog — on Android 14+ this includes
    // "All photos" / "Select photos" / "Don't allow".
    final result = await permission.request();
    if ((result.isGranted || result.isLimited) && result.isLimited && mounted) {
      // User chose partial access — let them know they can change it later.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Access granted to selected photos only.'),
          action: SnackBarAction(
            label: 'Change',
            onPressed: openAppSettings,
          ),
        ),
      );
    }
    return result.isGranted || result.isLimited;
  }

  void _showPermissionDeniedDialog(ImageSource source) {
    final isCamera = source == ImageSource.camera;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCamera ? 'Camera Access Denied' : 'Photo Access Denied'),
        content: Text(
          isCamera
              ? 'Camera permission was permanently denied.\n\n'
                  'You can still add wardrobe items using Gallery.\n\n'
                  'To enable Camera, open Settings and grant Camera access.'
              : 'Photo library permission was permanently denied.\n\n'
                  'You can still add wardrobe items using Camera.\n\n'
                  'To enable Photos, open Settings and grant Photos access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
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

      final item = await notifier.addItem(
        _imageBytes!,
        isPrivate: _isPrivate,
        removeBackground: _removeBackground,
      );

      setState(() {
        _result = item;
        _selectedSeasons = [];
        _isProcessing = false;
        _step = 'Done!';
      });
    } catch (e) {
      setState(() {
        _errorMessage = userFriendlyError(e);
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
                      onPressed: () => _pickMultipleImages(),
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
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.auto_fix_high_outlined),
                  title: const Text('Remove background'),
                  subtitle: const Text('Cleaner wardrobe view'),
                  value: _removeBackground,
                  onChanged: (v) => setState(() => _removeBackground = v),
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
            SnackBar(content: Text(userFriendlyError(e))),
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
                _pickMultipleImages();
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
// Batch progress bottom sheet
// ---------------------------------------------------------------------------

class _BatchProgressSheet extends StatelessWidget {
  const _BatchProgressSheet({
    required this.total,
    required this.currentNotifier,
  });

  final int total;
  final ValueNotifier<int> currentNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: currentNotifier,
      builder: (context, current, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Adding to Wardrobe',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: total > 0 ? current / total : 0,
              ),
              const SizedBox(height: 12),
              Text('Processing $current of $total…'),
            ],
          ),
        );
      },
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
