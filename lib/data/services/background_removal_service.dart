import 'dart:typed_data';


import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final backgroundRemovalServiceProvider =
    Provider<BackgroundRemovalService>((ref) {
  final apiKey = const String.fromEnvironment('REMOVE_BG_API_KEY');
  return BackgroundRemovalService(apiKey);
});

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Removes the background from a clothing image using the remove.bg API.
class BackgroundRemovalService {
  BackgroundRemovalService(this._apiKey);

  final String _apiKey;

  static const _endpoint = 'https://api.remove.bg/v1.0/removebg';

  /// Sends [imageBytes] to remove.bg and returns the resulting PNG bytes.
  ///
  /// Throws a [BackgroundRemovalException] on API errors.
  Future<Uint8List> removeBackground(Uint8List imageBytes) async {
    if (_apiKey.isEmpty) {
      throw const BackgroundRemovalException('remove.bg API key not configured');
    }

    final request = http.MultipartRequest('POST', Uri.parse(_endpoint))
      ..headers['X-Api-Key'] = _apiKey
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
