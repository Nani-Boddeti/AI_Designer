import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/utils/version_utils.dart';
import '../../data/repositories/config_repository.dart';

/// Fetched once at startup. Cached for the lifetime of the app.
final _appConfigProvider = FutureProvider<AppConfig>((ref) {
  return ref.watch(configRepositoryProvider).fetchAndroidConfig();
});

/// True when the installed version is below the Supabase-configured minimum.
/// Returns false on any network / DB error so the user is never blocked by
/// a connectivity issue.
final versionCheckProvider = FutureProvider<bool>((ref) async {
  try {
    final config = await ref.watch(_appConfigProvider.future);
    final info = await PackageInfo.fromPlatform();
    return VersionUtils.isLessThan(info.version, config.minVersion);
  } catch (_) {
    return false;
  }
});

/// The Play Store URL for the force-update screen.
/// Empty string if unavailable.
final storeUrlProvider = Provider<String>((ref) {
  return ref.watch(_appConfigProvider).value?.storeUrl ?? '';
});
