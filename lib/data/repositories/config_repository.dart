import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

/// Fetched shape of the app_config row.
typedef AppConfig = ({String minVersion, String storeUrl});

class ConfigRepository {
  ConfigRepository(this._svc);
  final SupabaseService _svc;

  /// Reads the 'android' row from the public `app_config` table.
  /// Throws on network / DB errors — callers should catch.
  Future<AppConfig> fetchAndroidConfig() async {
    final data = await _svc.client
        .from('app_config')
        .select('min_version, store_url')
        .eq('id', 'android')
        .single();

    return (
      minVersion: data['min_version'] as String? ?? '1.0.0',
      storeUrl: data['store_url'] as String? ?? '',
    );
  }
}

final configRepositoryProvider = Provider<ConfigRepository>((ref) {
  return ConfigRepository(ref.watch(supabaseServiceProvider));
});
