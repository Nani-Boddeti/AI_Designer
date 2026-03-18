import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final weatherServiceProvider = Provider<WeatherService>((ref) {
  final service = WeatherService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Fetches weather data via the weather-proxy Edge Function and caches
/// results locally in Hive (one fetch per day per location).
class WeatherService {
  final _functions = Supabase.instance.client.functions;

  static const _boxName = 'weather_cache';

  Box? _box;

  Future<Box> _getBox() async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  /// Returns weather data for the given coordinates and date.
  ///
  /// Result map keys: temp_c, feels_like_c, description, icon, humidity, wind_kph.
  Future<Map<String, dynamic>> getWeather({
    required double lat,
    required double lon,
    required DateTime date,
  }) async {
    final cacheKey =
        '${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)},${_dateKey(date)}';

    final box = await _getBox();
    final cached = box.get(cacheKey);
    if (cached != null) {
      final entry = cached as Map;
      final fetchedAt = DateTime.fromMillisecondsSinceEpoch(
          entry['fetched_at'] as int? ?? 0);
      final cachedDay =
          DateTime(fetchedAt.year, fetchedAt.month, fetchedAt.day);
      final requestDay = DateTime(date.year, date.month, date.day);
      if (cachedDay == requestDay) {
        return Map<String, dynamic>.from(entry['data'] as Map);
      }
    }

    final res = await _functions.invoke(
      'weather-proxy',
      body: {
        'lat': lat,
        'lon': lon,
        'date': _dateKey(date),
      },
    );
    final data = Map<String, dynamic>.from(res.data as Map? ?? {});

    await box.put(cacheKey, {
      'fetched_at': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    });
    return data;
  }

  /// Returns the icon URL for a given OpenWeatherMap icon code.
  static String iconUrl(String iconCode) =>
      'https://openweathermap.org/img/wn/$iconCode@2x.png';

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  void dispose() {
    _box?.close();
  }
}
