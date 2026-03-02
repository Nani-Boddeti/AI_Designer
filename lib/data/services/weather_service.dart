import 'dart:convert';


import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final weatherServiceProvider = Provider<WeatherService>((ref) {
  final apiKey = const String.fromEnvironment('OPENWEATHER_API_KEY');
  return WeatherService(apiKey);
});

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Fetches weather data from OpenWeatherMap and caches results in Hive.
class WeatherService {
  WeatherService(this._apiKey);

  final String _apiKey;

  static const _boxName = 'weather_cache';
  static const _baseUrl = 'https://api.openweathermap.org/data/2.5';

  Box? _box;

  Future<Box> _getBox() async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  /// Returns weather data for the given coordinates and date.
  ///
  /// Result map keys: temp_c (double), description (String), icon (String),
  /// humidity (int), wind_kph (double).
  ///
  /// Uses Hive to cache results for 6 hours.
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
      if (DateTime.now().difference(fetchedAt).inHours < 6) {
        return Map<String, dynamic>.from(entry['data'] as Map);
      }
    }

    if (_apiKey.isEmpty) {
      return _mockWeather();
    }

    final data = await _fetchFromApi(lat: lat, lon: lon, date: date);
    await box.put(cacheKey, {
      'fetched_at': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    });
    return data;
  }

  Future<Map<String, dynamic>> _fetchFromApi({
    required double lat,
    required double lon,
    required DateTime date,
  }) async {
    final uri = Uri.parse('$_baseUrl/forecast').replace(queryParameters: {
      'lat': lat.toString(),
      'lon': lon.toString(),
      'units': 'metric',
      'appid': _apiKey,
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      return _mockWeather();
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (body['list'] as List?) ?? [];

    // Find the forecast entry closest to noon on the target date.
    Map<String, dynamic>? best;
    int bestDiff = 999999;
    final targetNoon = DateTime(date.year, date.month, date.day, 12);

    for (final entry in list) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
          ((entry['dt'] as num?) ?? 0).toInt() * 1000);
      final diff = (dt.difference(targetNoon).inMinutes).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = entry as Map<String, dynamic>;
      }
    }

    if (best == null) return _mockWeather();

    final main = best['main'] as Map<String, dynamic>? ?? {};
    final weather =
        (best['weather'] as List?)?.firstOrNull as Map<String, dynamic>? ?? {};
    final wind = best['wind'] as Map<String, dynamic>? ?? {};

    return {
      'temp_c': (main['temp'] as num?)?.toDouble() ?? 20.0,
      'feels_like_c': (main['feels_like'] as num?)?.toDouble() ?? 20.0,
      'description': weather['description'] as String? ?? 'Clear sky',
      'icon': weather['icon'] as String? ?? '01d',
      'humidity': (main['humidity'] as num?)?.toInt() ?? 50,
      'wind_kph': ((wind['speed'] as num?)?.toDouble() ?? 0) * 3.6,
    };
  }

  Map<String, dynamic> _mockWeather() => {
        'temp_c': 22.0,
        'feels_like_c': 21.0,
        'description': 'Partly cloudy',
        'icon': '02d',
        'humidity': 55,
        'wind_kph': 12.0,
      };

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Returns the icon URL for a given OpenWeatherMap icon code.
  static String iconUrl(String iconCode) =>
      'https://openweathermap.org/img/wn/$iconCode@2x.png';
}
