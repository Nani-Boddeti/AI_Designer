import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final backgroundRemovalServiceProvider =
    Provider<BackgroundRemovalService>((ref) {
  final rembgKey = const String.fromEnvironment('REMBG_API_KEY');
  final removeBgKey = const String.fromEnvironment('REMOVE_BG_API_KEY');
  return BackgroundRemovalService(
    rembgApiKey: rembgKey,
    removeBgApiKey: removeBgKey,
  );
});

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Removes the background from a clothing image.
///
/// Tries the rembg API (PhotoRoom-compatible) first when [rembgApiKey] is set,
/// then falls back to remove.bg if [removeBgApiKey] is set.
class BackgroundRemovalService {
  BackgroundRemovalService({
    required this.rembgApiKey,
    required this.removeBgApiKey,
  });

  final String rembgApiKey;
  final String removeBgApiKey;

  static const _rembgEndpoint = 'https://api.rembg.com/rmbg';
  static const _removeBgEndpoint = 'https://api.remove.bg/v1.0/removebg';

  /// Sends [imageBytes] to the configured API and returns the resulting PNG.
  ///
  /// Throws a [BackgroundRemovalException] on API errors.
  Future<Uint8List> removeBackground(Uint8List imageBytes) async {
    if (rembgApiKey.isNotEmpty) {
      return _removeWithRembg(imageBytes);
    }
    if (removeBgApiKey.isNotEmpty) {
      return _removeWithRemoveBg(imageBytes);
    }
    throw const BackgroundRemovalException('No background removal API key configured');
  }

  Future<Uint8List> _removeWithRembg(Uint8List imageBytes) async {
    final request = http.MultipartRequest('POST', Uri.parse(_rembgEndpoint))
      ..headers['x-api-key'] = rembgApiKey
      ..fields['format'] = 'png'
      ..fields['expand'] = 'true'
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'upload.jpg',
        ),
      );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }

    throw BackgroundRemovalException(
      'rembg API error ${response.statusCode}: ${response.body}',
    );
  }

  Future<Uint8List> _removeWithRemoveBg(Uint8List imageBytes) async {
    final request = http.MultipartRequest('POST', Uri.parse(_removeBgEndpoint))
      ..headers['X-Api-Key'] = removeBgApiKey
      ..fields['size'] = 'auto'
      ..files.add(
        http.MultipartFile.fromBytes(
          'image_file',
          imageBytes,
          filename: 'upload.jpg',
        ),
      );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }

    throw BackgroundRemovalException(
      'remove.bg API error ${response.statusCode}: ${response.body}',
    );
  }
}

class BackgroundRemovalException implements Exception {
  const BackgroundRemovalException(this.message);
  final String message;

  @override
  String toString() => 'BackgroundRemovalException: $message';
}
