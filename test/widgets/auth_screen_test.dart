// Widget tests for AuthScreen.
// Uses a FakeAuthNotifier that returns an empty AuthState immediately —
// no Supabase networking or Firebase initialization required.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_designer_assist/presentation/providers/auth_provider.dart';
import 'package:ai_designer_assist/presentation/screens/auth/auth_screen.dart';

// ---------------------------------------------------------------------------
// Fake notifier — overrides build() so Supabase is never touched in tests.
// All action methods are no-ops.
// ---------------------------------------------------------------------------

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState();

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> sendMagicLink(String email) async {}

  @override
  Future<void> resendVerificationEmail(String email) async {}
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _buildScreen() {
  return ProviderScope(
    overrides: [authProvider.overrideWith(_FakeAuthNotifier.new)],
    child: const MaterialApp(home: AuthScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AuthScreen — structure', () {
    testWidgets('renders VibeVault brand name', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();
      expect(find.text('VibeVault'), findsOneWidget);
    });

    testWidgets('renders Sign In tab label', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();
      expect(find.text('Sign In'), findsWidgets);
    });

    testWidgets('renders Sign Up tab label', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();
      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('renders Magic Link tab label', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();
      expect(find.text('Magic Link'), findsOneWidget);
    });

    testWidgets('email and password TextFormFields are visible on Sign In tab',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();
      // At least 2 TextFormFields visible (email + password on Sign In tab).
      expect(find.byType(TextFormField).evaluate().length,
          greaterThanOrEqualTo(2));
    });
  });

  group('AuthScreen — Sign In form validation', () {
    testWidgets('shows email error when email is empty on Sign In submit',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      // Tap Sign In FilledButton without entering anything.
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsWidgets);
    });

    testWidgets('shows email error for malformed email on Sign In submit',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'bad-email');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsWidgets);
    });

    testWidgets('accepts valid email format (no email error shown)',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).first, 'test@example.com');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pump();

      // Email error gone, but password error appears since field is empty.
      expect(find.text('Enter a valid email'), findsNothing);
      expect(find.text('Minimum 6 characters'), findsWidgets);
    });

    testWidgets('shows password error when password is too short',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).first, 'user@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'abc');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Minimum 6 characters'), findsWidgets);
    });

    testWidgets('no validation errors for valid email + password combination',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).first, 'user@example.com');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsNothing);
      expect(find.text('Minimum 6 characters'), findsNothing);
    });
  });

  group('AuthScreen — tab navigation', () {
    testWidgets('tapping Magic Link tab shows Send Magic Link button',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Magic Link'));
      await tester.pumpAndSettle();

      expect(find.text('Send Magic Link'), findsOneWidget);
    });

    testWidgets('tapping Sign Up tab shows Create Account button',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('Magic Link tab shows email address TextFormField',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Magic Link'));
      await tester.pumpAndSettle();

      // Magic link form has a separate email controller with label 'Email address'.
      expect(find.text('Send Magic Link'), findsOneWidget);
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('Magic Link email field validates on empty submit', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Magic Link'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Send Magic Link'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsWidgets);
    });
  });
}
