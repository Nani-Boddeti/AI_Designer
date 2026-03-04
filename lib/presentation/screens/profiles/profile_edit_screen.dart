import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_constants.dart';
import '../../providers/profile_provider.dart';
import '../../../data/models/profile.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _nameCtrl = TextEditingController();
  AgeGroup _ageGroup = AgeGroup.adult;
  Gender _gender = Gender.other;
  SkinTone? _skinTone;
  List<String> _stylePersona = [];
  List<String> _fitConstraints = [];
  bool _loading = false;
  Uint8List? _pendingAvatarBytes;

  Profile? _profile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  void _loadProfile() {
    final profile = ref.read(profileByIdProvider(widget.profileId));
    if (profile != null) {
      setState(() {
        _profile = profile;
        _nameCtrl.text = profile.name;
        _ageGroup = profile.ageGroup;
        _gender = profile.gender;
        _skinTone = profile.skinTone;
        _stylePersona = List.from(profile.stylePersona);
        _fitConstraints = List.from(
          (profile.fitPreferences['constraints'] as List?)
                  ?.cast<String>() ??
              [],
        );
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final status = await Permission.photos.status;

    // Already have full or partial access — proceed directly.
    if (status.isGranted || status.isLimited) {
      // Fall through to picker below.
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Photo Access Denied'),
            content: const Text(
              'Photo library permission was permanently denied.\n\n'
              'To set a profile photo, open Settings and grant Photos access.',
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
      return;
    }

    if (status.isDenied) {
      final result = await Permission.photos.request();
      // Accept both full and partial (limited) access — picker works with either.
      if (!result.isGranted && !result.isLimited) return;
      if (result.isLimited && mounted) {
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
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _pendingAvatarBytes = bytes);
  }

  Future<void> _save() async {
    if (_profile == null) return;
    setState(() => _loading = true);

    try {
      // Upload new avatar if any.
      if (_pendingAvatarBytes != null) {
        await ref.read(profilesProvider.notifier).updateAvatar(
              profileId: _profile!.id,
              imageBytes: _pendingAvatarBytes!,
            );
      }

      // Update profile data.
      final updated = _profile!.copyWith(
        name: _nameCtrl.text.trim(),
        ageGroup: _ageGroup,
        gender: _gender,
        skinTone: _skinTone,
        stylePersona: _stylePersona,
        fitPreferences: {'constraints': _fitConstraints},
      );
      await ref.read(profilesProvider.notifier).updateProfile(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Profile?'),
        content: Text(
            'Are you sure you want to remove ${_profile?.name}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || _profile == null) return;

    setState(() => _loading = true);
    try {
      await ref
          .read(profilesProvider.notifier)
          .deleteProfile(_profile!.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${_profile!.name}'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: colorScheme.error),
            onPressed: _loading ? null : _deleteProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundImage: _pendingAvatarBytes != null
                          ? MemoryImage(_pendingAvatarBytes!)
                          : (_profile?.avatarUrl != null
                              ? CachedNetworkImageProvider(
                                  _profile!.avatarUrl!)
                              : null) as ImageProvider?,
                      backgroundColor: colorScheme.secondaryContainer,
                      child: _pendingAvatarBytes == null &&
                              _profile?.avatarUrl == null
                          ? Text(
                              _profile!.name.isNotEmpty
                                  ? _profile!.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                  fontSize: 36,
                                  color: colorScheme.onSecondaryContainer),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.camera_alt,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Name
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),

            // Age group
            DropdownButtonFormField<AgeGroup>(
              // ignore: deprecated_member_use
              value: _ageGroup,
              decoration: const InputDecoration(labelText: 'Age Group'),
              items: AgeGroup.values
                  .map((g) => DropdownMenuItem(
                        value: g,
                        child: Text(g.displayName),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _ageGroup = v ?? _ageGroup),
            ),
            const SizedBox(height: 24),

            // Gender
            Text('Gender',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            SegmentedButton<Gender>(
              segments: Gender.values
                  .map((g) => ButtonSegment(
                        value: g,
                        label: Text(g.displayName,
                            style: const TextStyle(fontSize: 11)),
                      ))
                  .toList(),
              selected: {_gender},
              onSelectionChanged: (val) =>
                  setState(() => _gender = val.first),
            ),
            const SizedBox(height: 24),

            // Skin tone
            Text('Skin Tone',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Helps Gemini suggest complementary colours.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: SkinTone.values.map((tone) {
                final selected = _skinTone == tone;
                return GestureDetector(
                  onTap: () => setState(
                      () => _skinTone = selected ? null : tone),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(tone.swatchColor),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade300,
                            width: selected ? 3 : 1,
                          ),
                        ),
                        child: selected
                            ? Icon(Icons.check,
                                size: 18,
                                color: tone == SkinTone.fair ||
                                        tone == SkinTone.light
                                    ? Colors.black54
                                    : Colors.white)
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(tone.displayName,
                          style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Style personas
            Text('Style Personas',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: StylePersonas.all.map((persona) {
                final selected = _stylePersona.contains(persona);
                return FilterChip(
                  label: Text(persona),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _stylePersona.add(persona);
                      } else {
                        _stylePersona.remove(persona);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Fit constraints
            Text('Fit Constraints',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: FitConstraints.all.map((constraint) {
                final selected = _fitConstraints.contains(constraint);
                return FilterChip(
                  label: Text(constraint),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _fitConstraints.add(constraint);
                      } else {
                        _fitConstraints.remove(constraint);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: const Text('Save Changes'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
