// Integration tests — run on a connected device or emulator.
//
// Usage:
//   ANDROID_SDK_ROOT="..." flutter test integration_test/app_test.dart \
//     --dart-define=SUPABASE_URL="..." \
//     --dart-define=SUPABASE_ANON_KEY="..."
//
// These tests use provider overrides to isolate screens from backend services,
// so no Supabase or Firebase calls are made during test execution.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ai_designer_assist/presentation/providers/auth_provider.dart';
import 'package:ai_designer_assist/presentation/providers/version_check_provider.dart';
import 'package:ai_designer_assist/presentation/screens/auth/auth_screen.dart';
import 'package:ai_designer_assist/presentation/screens/force_update/force_update_screen.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState();

  @override
  Future<void> signInWithEmail(
      {required String email, required String password}) async {}

  @override
  Future<void> signUpWithEmail(
      {required String email, required String password}) async {}

  @override
  Future<void> sendMagicLink(String email) async {}

  @override
  Future<void> resendVerificationEmail(String email) async {}
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ForceUpdateScreen — integration', () {
    testWidgets('blocks navigation and shows update UI', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storeUrlProvider
                .overrideWithValue('https://play.google.com/store'),
          ],
          child: const MaterialApp(home: ForceUpdateScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Update Required'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);

      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);
    });

    testWidgets('Update Now button is enabled when store URL is set',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storeUrlProvider
                .overrideWithValue('https://play.google.com/store'),
          ],
          child: const MaterialApp(home: ForceUpdateScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('Update Now button is disabled when store URL is missing',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [storeUrlProvider.overrideWithValue('')],
          child: const MaterialApp(home: ForceUpdateScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNull);
    });
  });

  group('AuthScreen — integration', () {
    Widget buildAuthScreen() {
      return ProviderScope(
        overrides: [authProvider.overrideWith(_FakeAuthNotifier.new)],
        child: const MaterialApp(home: AuthScreen()),
      );
    }

    testWidgets('renders all three auth tabs', (tester) async {
      await tester.pumpWidget(buildAuthScreen());
      await tester.pumpAndSettle();

      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Sign Up'), findsOneWidget);
      expect(find.text('Magic Link'), findsOneWidget);
    });

    testWidgets('Sign In form shows validation errors on empty submit',
        (tester) async {
      await tester.pumpWidget(buildAuthScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsWidgets);
    });

    testWidgets('navigating to Magic Link tab shows its form', (tester) async {
      await tester.pumpWidget(buildAuthScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Magic Link'));
      await tester.pumpAndSettle();

      expect(find.text('Send Magic Link'), findsOneWidget);
    });

    testWidgets('navigating to Sign Up tab shows Create Account button',
        (tester) async {
      await tester.pumpWidget(buildAuthScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
    });
  });
}
