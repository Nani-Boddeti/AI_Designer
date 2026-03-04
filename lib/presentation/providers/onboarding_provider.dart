import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);

class OnboardingNotifier extends Notifier<bool> {
  static const _key = 'hasSeenOnboarding';

  @override
  bool build() =>
      Hive.box('app_settings').get(_key, defaultValue: false) as bool;

  void markSeen() {
    Hive.box('app_settings').put(_key, true);
    state = true;
  }
}
