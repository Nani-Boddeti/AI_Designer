import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps the in-app review flow with a one-shot guard so the dialog is
/// only ever triggered once per install.
class ReviewService {
  ReviewService._();

  static const _kKey = 'review_requested';

  /// Requests an in-app review if:
  ///  • The review has not been requested before on this install.
  ///  • The platform supports it (Play Store production / TestFlight).
  ///
  /// Silently no-ops on failure — never throws.
  static Future<void> requestIfEligible() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kKey) ?? false) return; // already requested

      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;

      await review.requestReview();
      await prefs.setBool(_kKey, true);
    } catch (_) {
      // Non-fatal — never surface to the user.
    }
  }
}
