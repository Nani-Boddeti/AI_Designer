import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final backgroundRemovalServiceProvider = Provider<BackgroundRemovalService>(
  (ref) => BackgroundRemovalService(),
);

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Removes the background from a clothing image via the remove-background
/// Edge Function. API keys never reach the client.
class BackgroundRemovalService {
  final _functions = Supabase.instance.client.functions;

  Future<Uint8List> removeBackground(Uint8List imageBytes) async {
    final res = await _functions.invoke(
      'remove-background',
      body: {
        'image_base64': base64Encode(imageBytes),
        'mime_type': 'image/jpeg',
      },
    );
    final data = res.data as Map<String, dynamic>?;
    final encoded = data?['image_base64'] as String?;
    if (encoded == null || encoded.isEmpty) {
      throw const BackgroundRemovalException('No result from server');
    }
    return base64Decode(encoded);
  }
}

class BackgroundRemovalException implements Exception {
  const BackgroundRemovalException(this.message);
  final String message;

  @override
  String toString() => 'BackgroundRemovalException: $message';
}
