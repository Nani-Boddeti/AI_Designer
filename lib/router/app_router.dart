import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../presentation/providers/auth_provider.dart';
import '../presentation/screens/auth/auth_screen.dart';
import '../presentation/screens/auth/household_setup_screen.dart';
import '../presentation/screens/calendar/style_calendar_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/outfit/outfit_result_screen.dart';
import '../presentation/screens/outfit/style_session_screen.dart';
import '../presentation/screens/outfit/virtual_lineup_screen.dart';
import '../presentation/screens/profiles/profile_edit_screen.dart';
import '../presentation/screens/profiles/profile_list_screen.dart';
import '../presentation/screens/shopping/gap_filler_screen.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/wardrobe/add_item_screen.dart';
import '../presentation/screens/wardrobe/item_detail_screen.dart';
import '../presentation/screens/wardrobe/wardrobe_screen.dart';

// ---------------------------------------------------------------------------
// Named route constants
// ---------------------------------------------------------------------------

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String auth = '/auth';
  static const String householdSetup = '/household-setup';
  static const String home = '/home';
  static const String profiles = '/profiles';
  static const String profileEdit = '/profiles/:id/edit';
  static const String wardrobe = '/wardrobe/:profileId';
  static const String addItem = '/wardrobe/:profileId/add';
  static const String itemDetail = '/wardrobe/:profileId/item/:itemId';
  static const String styleSession = '/style-session';
  static const String outfitResult = '/outfit-result';
  static const String virtualLineup = '/virtual-lineup';
  static const String gapFiller = '/gap-filler';
  static const String calendar = '/calendar';

  // Helper to build concrete paths.
  static String wardrobePath(String profileId) => '/wardrobe/$profileId';
  static String addItemPath(String profileId) =>
      '/wardrobe/$profileId/add';
  static String itemDetailPath(String profileId, String itemId) =>
      '/wardrobe/$profileId/item/$itemId';
  static String profileEditPath(String profileId) =>
      '/profiles/$profileId/edit';
}

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------

final appRouterProvider = Provider<GoRouter>((ref) {
  final authStateListenable = _AuthStateListenable(ref);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: authStateListenable,
    redirect: (context, state) async {
      final authAsync = ref.read(authProvider);
      final authValue = authAsync.valueOrNull;
      final isLoading = authAsync.isLoading;

      // Never redirect while loading.
      if (isLoading) return null;

      final isOnSplash = state.matchedLocation == AppRoutes.splash;
      final isOnAuth = state.matchedLocation == AppRoutes.auth;
      final isOnSetup = state.matchedLocation == AppRoutes.householdSetup;

      if (authValue == null || !authValue.isAuthenticated) {
        if (isOnSplash || isOnAuth) return null;
        return AppRoutes.auth;
      }

      // Authenticated but no household yet.
      if (!authValue.hasHousehold) {
        if (isOnSetup) return null;
        return AppRoutes.householdSetup;
      }

      // Authenticated and has household — push off splash/auth.
      if (isOnSplash || isOnAuth || isOnSetup) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (_, _) => const AuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.householdSetup,
        builder: (_, _) => const HouseholdSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'profiles',
            builder: (_, _) => const ProfileListScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.profiles,
        builder: (_, _) => const ProfileListScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (context, state) {
          final profileId = state.pathParameters['id'] ?? '';
          return ProfileEditScreen(profileId: profileId);
        },
      ),
      GoRoute(
        path: AppRoutes.wardrobe,
        builder: (context, state) {
          final profileId = state.pathParameters['profileId'] ?? '';
          return WardrobeScreen(profileId: profileId);
        },
      ),
      GoRoute(
        path: AppRoutes.addItem,
        builder: (context, state) {
          final profileId = state.pathParameters['profileId'] ?? '';
          return AddItemScreen(profileId: profileId);
        },
      ),
      GoRoute(
        path: AppRoutes.itemDetail,
        builder: (context, state) {
          final profileId = state.pathParameters['profileId'] ?? '';
          final itemId = state.pathParameters['itemId'] ?? '';
          return ItemDetailScreen(
              profileId: profileId, itemId: itemId);
        },
      ),
      GoRoute(
        path: AppRoutes.styleSession,
        builder: (_, _) => const StyleSessionScreen(),
      ),
      GoRoute(
        path: AppRoutes.outfitResult,
        builder: (_, _) => const OutfitResultScreen(),
      ),
      GoRoute(
        path: AppRoutes.virtualLineup,
        builder: (_, _) => const VirtualLineupScreen(),
      ),
      GoRoute(
        path: AppRoutes.gapFiller,
        builder: (_, _) => const GapFillerScreen(),
      ),
      GoRoute(
        path: AppRoutes.calendar,
        builder: (_, _) => const StyleCalendarScreen(),
      ),
    ],
  );
});

// ---------------------------------------------------------------------------
// ChangeNotifier bridge so GoRouter can listen to Riverpod auth changes.
// ---------------------------------------------------------------------------

class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(this._ref) {
    _ref.listen<AsyncValue<AuthState>>(authProvider, (_, next) {
      notifyListeners();
    });
  }

  final Ref _ref;
}
