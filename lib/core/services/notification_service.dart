import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles FCM initialisation, permission, token storage, and
/// foreground message display.
class NotificationService {
  NotificationService._();

  // Holds the single active token-refresh subscription so we can cancel
  // before re-subscribing. Without this, each syncToken() call stacks a new
  // listener and every token rotation triggers N upserts.
  static StreamSubscription<String>? _tokenRefreshSub;

  /// Call once from main() after Firebase.initializeApp().
  static Future<void> initialize() async {
    // Request permission (Android 13+ shows a dialog; older versions auto-grant).
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Show heads-up notifications while app is in the foreground (Android).
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Log foreground messages in debug.
    if (kDebugMode) {
      FirebaseMessaging.onMessage.listen((msg) {
        debugPrint(
          '[FCM] Foreground message: ${msg.notification?.title} — ${msg.notification?.body}',
        );
      });
    }
  }

  /// Upserts the current device FCM token for [userId] into Supabase.
  /// Uses `(user_id, platform)` conflict target so each user has one
  /// token per platform — reinstalls simply overwrite the old token.
  ///
  /// Fire-and-forget — caller should not await on the critical path.
  static Future<void> syncToken(SupabaseClient client, String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await client.from('device_tokens').upsert(
        {
          'user_id': userId,
          'token': token,
          'platform': 'android',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,platform',
      );

      // Keep the token fresh if Firebase rotates it.
      // Cancel any previous subscription before creating a new one — prevents
      // stacking N listeners across multiple syncToken() calls.
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          await client.from('device_tokens').upsert(
            {
              'user_id': userId,
              'token': newToken,
              'platform': 'android',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
            onConflict: 'user_id,platform',
          );
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[FCM] Token sync failed: $e');
    }
  }

  /// Deletes the device token from Supabase on sign-out so the user
  /// stops receiving notifications after logging out.
  static Future<void> removeToken(SupabaseClient client, String userId) async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    try {
      await client
          .from('device_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('platform', 'android');
    } catch (_) {}
  }
}
