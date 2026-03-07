// Widget tests for ForceUpdateScreen.
// Only needs storeUrlProvider override — no Supabase or Firebase required.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_designer_assist/presentation/providers/version_check_provider.dart';
import 'package:ai_designer_assist/presentation/screens/force_update/force_update_screen.dart';

Widget _buildScreen({String storeUrl = 'https://play.google.com/store'}) {
  return ProviderScope(
    overrides: [storeUrlProvider.overrideWithValue(storeUrl)],
    child: const MaterialApp(home: ForceUpdateScreen()),
  );
}

void main() {
  group('ForceUpdateScreen — layout', () {
    testWidgets('renders Update Required title', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('Update Required'), findsOneWidget);
    });

    testWidgets('renders Update Now button', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('Update Now'), findsOneWidget);
    });

    testWidgets('renders system update icon', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.byIcon(Icons.system_update_alt_rounded), findsOneWidget);
    });

    testWidgets('description text mentions VibeVault', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.textContaining('VibeVault'), findsWidgets);
    });

    testWidgets('download icon appears on the button', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    });
  });

  group('ForceUpdateScreen — button state', () {
    testWidgets('Update Now button is enabled when store URL is non-empty',
        (tester) async {
      await tester.pumpWidget(
          _buildScreen(storeUrl: 'https://play.google.com/store'));
      await tester.pump();
      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('Update Now button is disabled when store URL is empty',
        (tester) async {
      await tester.pumpWidget(_buildScreen(storeUrl: ''));
      await tester.pump();
      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNull);
    });

    testWidgets('tapping disabled button does not crash', (tester) async {
      await tester.pumpWidget(_buildScreen(storeUrl: ''));
      await tester.pump();
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pump();
      expect(find.text('Update Required'), findsOneWidget);
    });
  });

  group('ForceUpdateScreen — navigation guard', () {
    testWidgets('PopScope has canPop set to false', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);
    });
  });
}
