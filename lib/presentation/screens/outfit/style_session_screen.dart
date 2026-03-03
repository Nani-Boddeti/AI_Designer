import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/profile.dart';
import '../../../data/services/weather_service.dart';
import '../../../router/app_router.dart';
import '../../providers/outfit_provider.dart';
import '../../providers/profile_provider.dart';

class StyleSessionScreen extends ConsumerStatefulWidget {
  const StyleSessionScreen({super.key, this.embeddedInHome = false});

  final bool embeddedInHome;

  @override
  ConsumerState<StyleSessionScreen> createState() =>
      _StyleSessionScreenState();
}

class _StyleSessionScreenState extends ConsumerState<StyleSessionScreen> {
  final _occasionCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final Set<String> _selectedProfileIds = {};
  Map<String, dynamic> _weather = {};
  bool _loadingWeather = false;
  bool _generating = false;

  @override
  void dispose() {
    _occasionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _weather = {};
    });
    await _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    setState(() => _loadingWeather = true);
    try {
      final permission = await Geolocator.checkPermission();
      LocationPermission effectivePermission = permission;
      if (permission == LocationPermission.denied) {
        effectivePermission = await Geolocator.requestPermission();
      }
      if (effectivePermission == LocationPermission.deniedForever ||
          effectivePermission == LocationPermission.denied) {
        // Use mock weather.
        final svc = ref.read(weatherServiceProvider);
        final w = await svc.getWeather(lat: 40.7128, lon: -74.0060, date: _selectedDate);
        if (mounted) setState(() => _weather = w);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.low));
      final svc = ref.read(weatherServiceProvider);
      final w = await svc.getWeather(
          lat: pos.latitude, lon: pos.longitude, date: _selectedDate);
      if (mounted) setState(() => _weather = w);
    } catch (_) {
      // Non-fatal.
    } finally {
      if (mounted) setState(() => _loadingWeather = false);
    }
  }

  Future<void> _generateOutfits(List<Profile> allProfiles) async {
    if (_selectedProfileIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one family member')),
      );
      return;
    }
    if (_occasionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an occasion')),
      );
      return;
    }

    setState(() => _generating = true);

    try {
      final selectedProfiles = allProfiles
          .where((p) => _selectedProfileIds.contains(p.id))
          .toList();

      await ref.read(generatedOutfitsProvider.notifier).generate(
            profiles: selectedProfiles,
            occasion: _occasionCtrl.text.trim(),
            eventDate: _selectedDate,
          );

      if (mounted) context.push(AppRoutes.outfitResult);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(profilesProvider);

    final body = profilesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (profiles) => _buildContent(profiles),
    );

    if (widget.embeddedInHome) {
      return Scaffold(
        appBar: AppBar(title: const Text('Style Session')),
        body: body,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Style Session')),
      body: body,
    );
  }

  Widget _buildContent(List<Profile> profiles) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Occasion
          TextField(
            controller: _occasionCtrl,
            decoration: const InputDecoration(
              labelText: 'Occasion',
              hintText: 'e.g. Church Sunday, Birthday Party, Beach Day',
              prefixIcon: Icon(Icons.celebration_outlined),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: OccasionOptions.all
                .take(6)
                .map((o) => ActionChip(
                      label: Text(o),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(
                          () => _occasionCtrl.text = o),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),

          // Date picker
          _SectionTitle(label: 'Event Date'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
            ),
          ),
          const SizedBox(height: 12),

          // Weather display
          if (_loadingWeather)
            const Center(child: CircularProgressIndicator())
          else if (_weather.isNotEmpty)
            _WeatherCard(weather: _weather),

          const SizedBox(height: 20),

          // Family member selection
          _SectionTitle(label: 'Family Members'),
          const SizedBox(height: 8),
          if (profiles.isEmpty)
            const Text('No profiles found. Add family members first.',
                style: TextStyle(color: Colors.grey))
          else
            ...profiles.map((p) => CheckboxListTile(
                  title: Text(p.name),
                  subtitle: Text(p.ageGroup.displayName),
                  value: _selectedProfileIds.contains(p.id),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedProfileIds.add(p.id);
                      } else {
                        _selectedProfileIds.remove(p.id);
                      }
                    });
                  },
                  secondary: CircleAvatar(
                    child: Text(p.name[0].toUpperCase()),
                  ),
                )),

          const SizedBox(height: 24),

          // Generate button
          FilledButton.icon(
            onPressed: _generating
                ? null
                : () => _generateOutfits(profiles),
            icon: _generating
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome),
            label: Text(_generating ? 'Generating…' : 'Generate Outfits'),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.weather});

  final Map<String, dynamic> weather;

  @override
  Widget build(BuildContext context) {
    final tempC = weather['temp_c'] as double? ?? 0;
    final description = weather['description'] as String? ?? '';
    final humidity = weather['humidity'] as int? ?? 0;
    final windKph = weather['wind_kph'] as double? ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.wb_sunny_outlined, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${tempC.toStringAsFixed(1)}°C  •  $description',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('Humidity: $humidity%  •  Wind: ${windKph.toStringAsFixed(1)} km/h',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
