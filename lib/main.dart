import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';

// Public Supabase credentials — not secrets; data is protected by RLS policies.
const _supabaseUrl = 'https://vrtwsapfzmywfauqbrtg.supabase.co';
const _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZydHdzYXBmem15d2ZhdXFicnRnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI0NzQ1NDcsImV4cCI6MjA4ODA1MDU0N30.BVOzGk64fV3FwwOCtmDu0pLEaJmL_C0IKUAAZtKzYG0';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Forward Flutter framework errors to Crashlytics.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Forward async errors thrown outside the Flutter framework.
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  await NotificationService.initialize();

  await Hive.initFlutter();
  await Hive.openBox('app_settings');

  runApp(const ProviderScope(child: VibeVaultApp()));
}

class VibeVaultApp extends ConsumerWidget {
  const VibeVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'VibeVault',
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
