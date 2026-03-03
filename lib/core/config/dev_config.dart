import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dev-only usage bypass. Only active in debug builds.
///
/// To remove for production:
///   1. Delete this file.
///   2. Remove the bypass check in style_session_screen.dart.
///   3. Remove the "Dev Settings" section from home_screen.dart (_MoreTab).
class DevConfig {
  DevConfig._();

  static bool get isDebug => kDebugMode;
}

/// When true, all usage limit checks are skipped.
/// Guards in the UI read this only when [kDebugMode] is true so it has
/// zero effect in release builds.
final devBypassLimitsProvider = StateProvider<bool>((ref) => false);
