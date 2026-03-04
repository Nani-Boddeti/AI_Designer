import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/wardrobe_item.dart';
import '../services/background_removal_service.dart';
import '../services/gemini_service.dart';
import '../services/supabase_service.dart';
import '../../core/constants/app_constants.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final wardrobeRepositoryProvider = Provider<WardrobeRepository>((ref) {
  return WardrobeRepository(
    supabaseService: ref.watch(supabaseServiceProvider),
    geminiService: ref.watch(geminiServiceProvider),
    bgRemovalService: ref.watch(backgroundRemovalServiceProvider),
  );
});

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class WardrobeRepository {
  WardrobeRepository({
    required this.supabaseService,
    required this.geminiService,
    required this.bgRemovalService,
  });

  final SupabaseService supabaseService;
  final GeminiService geminiService;
  final BackgroundRemovalService bgRemovalService;

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  Future<List<WardrobeItem>> getItemsForProfile(String profileId) async {
    final data = await supabaseService.client
        .from(SupabaseTables.wardrobeItems)
        .select()
        .eq('profile_id', profileId)
        .order('created_at', ascending: false);

    return (data as List).map((e) => WardrobeItem.fromJson(e)).toList();
  }

  Future<WardrobeItem?> getItem(String itemId) async {
    final data = await supabaseService.client
        .from(SupabaseTables.wardrobeItems)
        .select()
        .eq('id', itemId)
        .maybeSingle();

    if (data == null) return null;
    return WardrobeItem.fromJson(data);
  }

  Future<WardrobeItem> updateItem(WardrobeItem item) async {
    final json = item.toJson()
      ..remove('id')
      ..remove('created_at');

    final data = await supabaseService.client
        .from(SupabaseTables.wardrobeItems)
        .update(json)
        .eq('id', item.id)
        .select()
        .single();

    return WardrobeItem.fromJson(data);
  }

  Future<void> deleteItem(String itemId) async {
    await supabaseService.client
        .from(SupabaseTables.wardrobeItems)
        .delete()
        .eq('id', itemId);
  }

  // ---------------------------------------------------------------------------
  // Full add-item pipeline
  // ---------------------------------------------------------------------------

  /// Runs the full add-item pipeline:
  ///  1. Compress image
  ///  2. Remove background (optional, continues on failure)
  ///  3. AI tagging via Gemini
  ///  4. Upload original + processed images to Supabase Storage
  ///  5. Insert record into wardrobe_items table
  ///
  /// [onStep] is called with a progress string at each step.
  Future<WardrobeItem> addItem({
    required String profileId,
    required Uint8List imageBytes,
    bool isPrivate = false,
    void Function(String step)? onStep,
  }) async {
    final itemId = const Uuid().v4();

    // Step 1: Compress
    onStep?.call('Compressing image…');
    final compressed = await FlutterImageCompress.compressWithList(
      imageBytes,
      quality: 85,
      minWidth: 800,
      minHeight: 800,
    );

    // Step 2: Remove background
    onStep?.call('Removing background…');
    Uint8List? processedBytes;
    try {
      processedBytes = await bgRemovalService.removeBackground(
        Uint8List.fromList(compressed),
      );
    } catch (_) {
      // Background removal is optional; proceed without it.
    }

    // Step 3: AI tagging
    onStep?.call('AI tagging…');
    Map<String, dynamic> tags = {};
    try {
      tags = await geminiService.tagWardrobeItem(
        Uint8List.fromList(compressed),
      );
    } catch (_) {
      // Tagging failure should not block saving the item.
    }

    // Step 4: Upload images
    onStep?.call('Uploading images…');
    final originalPath = 'wardrobe/$profileId/$itemId/original.jpg';
    final imageUrl = await supabaseService.uploadFile(
      bucket: SupabaseBuckets.wardrobeImages,
      path: originalPath,
      bytes: compressed,
      contentType: 'image/jpeg',
    );

    String? processedImageUrl;
    if (processedBytes != null) {
      final processedPath = 'wardrobe/$profileId/$itemId/processed.png';
      processedImageUrl = await supabaseService.uploadFile(
        bucket: SupabaseBuckets.processedImages,
        path: processedPath,
        bytes: processedBytes,
        contentType: 'image/png',
      );
    }

    // Step 5: Insert record
    onStep?.call('Saving to wardrobe…');
    final record = {
      'id': itemId,
      'profile_id': profileId,
      'name': tags['name'] as String? ?? 'New Item',
      'category': tags['category'] as String? ?? WardrobeCategory.top.value,
      'colors': _toStringList(tags['colors']),
      'color_names': _toStringList(tags['color_names']),
      'style_tags': _toStringList(tags['style_tags']),
      'season_tags': _toStringList(tags['season_tags']),
      'image_url': imageUrl,
      // ignore: use_null_aware_elements
      if (processedImageUrl != null) 'processed_image_url': processedImageUrl,
      if (tags['brand'] != null) 'brand': tags['brand'],
      if (tags['description'] != null) 'ai_description': tags['description'],
      'is_private': isPrivate,
    };

    final data = await supabaseService.client
        .from(SupabaseTables.wardrobeItems)
        .insert(record)
        .select()
        .single();

    return WardrobeItem.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<String> _toStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }
}
