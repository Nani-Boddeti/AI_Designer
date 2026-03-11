import 'dart:typed_data';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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

  Future<List<WardrobeItem>> getItemsForProfile(
    String profileId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await supabaseService.client
        .from(SupabaseTables.wardrobeItems)
        .select()
        .eq('profile_id', profileId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    final items = (data as List).map((e) => WardrobeItem.fromJson(e)).toList();
    return _signItemListUrls(items);
  }

  Future<WardrobeItem?> getItem(String itemId) async {
    final data = await supabaseService.client
        .from(SupabaseTables.wardrobeItems)
        .select()
        .eq('id', itemId)
        .maybeSingle();

    if (data == null) return null;
    return _signItemUrls(WardrobeItem.fromJson(data));
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
    String? subcategory,
    bool isPrivate = false,
    bool removeBackground = true,
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

    // Step 2: Remove background (optional — user may choose to keep original)
    Uint8List? processedBytes;
    if (removeBackground) {
      onStep?.call('Removing background…');
      try {
        processedBytes = await bgRemovalService.removeBackground(
          Uint8List.fromList(compressed),
        );
      } catch (e, stack) {
        // Background removal is optional; proceed without it.
        FirebaseCrashlytics.instance
            .recordError(e, stack, reason: 'bg-removal-failed', fatal: false);
        onStep?.call('Background removal skipped — saving original');
      }
    } else {
      onStep?.call('Keeping original background…');
    }

    // Step 3: AI tagging
    onStep?.call('AI tagging…');
    Map<String, dynamic> tags = {};
    try {
      tags = await geminiService.tagWardrobeItem(
        Uint8List.fromList(compressed),
      );
    } catch (e, stack) {
      // Tagging failure should not block saving the item.
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'ai-tagging-failed', fatal: false);
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
      'category': (tags['category'] as String?)?.toLowerCase().trim() ??
          WardrobeCategory.top.value,
      'colors': _toStringList(tags['colors']),
      'color_names': _toStringList(tags['color_names']),
      'style_tags': _toStringList(tags['style_tags']),
      'season_tags': _toStringList(tags['season_tags']),
      'image_url': imageUrl,
      // ignore: use_null_aware_elements
      if (processedImageUrl != null) 'processed_image_url': processedImageUrl,
      // ignore: use_null_aware_elements
      if (tags['brand'] != null) 'brand': tags['brand'],
      // ignore: use_null_aware_elements
      if (tags['description'] != null) 'ai_description': tags['description'],
      // ignore: use_null_aware_elements
      if (subcategory != null) 'subcategory': subcategory,
      'is_private': isPrivate,
    };

    final data = await supabaseService.client
        .from(SupabaseTables.wardrobeItems)
        .insert(record)
        .select()
        .single();

    return _signItemUrls(WardrobeItem.fromJson(data));
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<String> _toStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  /// Signs image URLs for a single [item] (buckets are private).
  Future<WardrobeItem> _signItemUrls(WardrobeItem item) async {
    final signedImage = item.imageUrl != null
        ? await supabaseService.createSignedUrl(
            SupabaseBuckets.wardrobeImages, item.imageUrl!)
        : null;
    final signedProcessed = item.processedImageUrl != null
        ? await supabaseService.createSignedUrl(
            SupabaseBuckets.processedImages, item.processedImageUrl!)
        : null;
    if (signedImage == null && signedProcessed == null) return item;
    return item.copyWith(
      imageUrl: signedImage ?? item.imageUrl,
      processedImageUrl: signedProcessed ?? item.processedImageUrl,
    );
  }

  /// Batch-signs image URLs for a list of items using two batch calls.
  Future<List<WardrobeItem>> _signItemListUrls(
      List<WardrobeItem> items) async {
    if (items.isEmpty) return items;

    final imagePaths =
        items.where((i) => i.imageUrl != null).map((i) => i.imageUrl!).toList();
    final processedPaths = items
        .where((i) => i.processedImageUrl != null)
        .map((i) => i.processedImageUrl!)
        .toList();

    final signedImages = await supabaseService.createSignedUrls(
        SupabaseBuckets.wardrobeImages, imagePaths);
    final signedProcessed = await supabaseService.createSignedUrls(
        SupabaseBuckets.processedImages, processedPaths);

    return items.map((item) {
      final img = item.imageUrl != null
          ? (signedImages[item.imageUrl!] ?? item.imageUrl)
          : null;
      final proc = item.processedImageUrl != null
          ? (signedProcessed[item.processedImageUrl!] ?? item.processedImageUrl)
          : null;
      return item.copyWith(imageUrl: img, processedImageUrl: proc);
    }).toList();
  }
}
