import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/household.dart';
import '../../../data/models/profile.dart';
import '../../../data/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/usage_provider.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() =>
      _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen>
    with WidgetsBindingObserver {
  late final Razorpay _razorpay;
  bool _processingPayment = false;
  String _targetTier = 'pro'; // which tier the user is trying to subscribe to
  // Sentinel: true from _openCheckout until ANY Razorpay callback fires.
  // If the app resumes while this is still true, the user dismissed the sheet
  // without completing (or erroring) the payment — safe to unlock buttons.
  bool _awaitingCallback = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _razorpay.clear();
    super.dispose();
  }

  /// Called by the OS when the Flutter activity returns to the foreground.
  /// If Razorpay's sheet was dismissed via the Android back button it fires
  /// no event, leaving _awaitingCallback = true. Detect that here and unlock.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingCallback) {
      if (mounted) {
        setState(() {
          _awaitingCallback = false;
          _processingPayment = false;
        });
      }
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    _awaitingCallback = false;
    if (!mounted) return;

    setState(() => _processingPayment = true);
    try {
      // Use RPC (SECURITY DEFINER) to update tier — more reliable than
      // direct UPDATE which can be silently blocked by RLS edge cases.
      final client = ref.read(supabaseServiceProvider).client;
      await client.rpc('update_household_tier', params: {
        'p_tier': _targetTier,
        'p_expires_at': DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String(),
      });

      // Re-fetch auth + usage so UI reflects the new tier immediately.
      ref.invalidate(authProvider);
      ref.invalidate(usageNotifierProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_targetTier == 'prime' ? 'Prime' : 'Pro'} plan activated!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to activate subscription: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingPayment = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _awaitingCallback = false;
    if (!mounted) return;
    // Reset processing flag so buttons re-enable.
    setState(() => _processingPayment = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response.message?.isNotEmpty == true
              ? response.message!
              : 'Payment failed. Please try again.',
        ),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _awaitingCallback = false;
    if (!mounted) return;
    // External wallet selection closes Razorpay sheet — treat as cancelled.
    setState(() => _processingPayment = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('External wallet selected: ${response.walletName ?? ''}'),
      ),
    );
  }

  void _openCheckout(String targetTier, int amountPaisa, String userEmail) {
    const razorpayKey = String.fromEnvironment('RAZORPAY_KEY_ID');
    if (razorpayKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment not configured. Build with --dart-define=RAZORPAY_KEY_ID.'),
        ),
      );
      return;
    }

    // Lock buttons and arm the dismiss-guard sentinel.
    setState(() {
      _targetTier = targetTier;
      _processingPayment = true;
      _awaitingCallback = true;
    });
    final tierLabel = targetTier == 'prime' ? 'Prime' : 'Pro';
    final options = {
      'key': razorpayKey,
      'amount': amountPaisa,
      'name': 'AI Designer Assist',
      'description': '$tierLabel Plan — monthly outfit suggestions',
      'prefill': {'email': userEmail},
      'theme': {'color': '#6750A4'},
    };
    _razorpay.open(options);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).value;
    final profiles = ref.watch(profilesProvider).value ?? <Profile>[];
    final usageAsync = ref.watch(usageNotifierProvider);
    final household = authState?.household;
    final colorScheme = Theme.of(context).colorScheme;

    // Build content regardless of usageAsync loading state so buttons stay
    // visible while usage refreshes after a payment. Fallback to empty usage.
    final usage = usageAsync.value ?? const UsageState();

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: _buildContent(
        context,
        usage: usage,
        usageLoading: usageAsync.isLoading,
        household: household,
        profiles: profiles,
        userEmail: authState?.user?.email ?? '',
        colorScheme: colorScheme,
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required UsageState usage,
    required bool usageLoading,
    required Household? household,
    required List<Profile> profiles,
    required String userEmail,
    required ColorScheme colorScheme,
  }) {
    final isProActive = household?.isProActive ?? false;
    final isPrimeActive = household?.isPrimeActive ?? false;
    final tierLabel = isPrimeActive
        ? 'Prime Plan — Active'
        : isProActive
            ? 'Pro Plan — Active'
            : 'Free Plan';

    // Flat limits and fixed prices.
    const proLimit = TierLimits.proHouseholdLimit;
    const primeLimit = TierLimits.primeHouseholdLimit;
    const proPaisa = TierLimits.proPricePaisa;
    const primePaisa = TierLimits.primePricePaisa;

    // Format price as ₹X
    String fmt(int paisa) => '₹${paisa ~/ 100}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.paddingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Plan badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingMd,
                vertical: AppSizes.paddingSm,
              ),
              decoration: BoxDecoration(
                color: (isProActive || isPrimeActive)
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppSizes.radiusXl),
              ),
              child: Text(
                tierLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: (isProActive || isPrimeActive)
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSizes.paddingLg),

          // Usage bar
          Row(
            children: [
              Expanded(
                child: Text(
                  'This Month: ${usage.count} / ${usage.limit} suggestions used',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (usageLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingSm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            child: LinearProgressIndicator(
              value: usage.limit > 0 ? usage.count / usage.limit : 0,
              minHeight: 12,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                usage.canGenerate ? colorScheme.primary : colorScheme.error,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.paddingSm),
          Text(
            '${usage.remaining} suggestions remaining',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),

          const SizedBox(height: AppSizes.paddingLg),
          const Divider(),
          const SizedBox(height: AppSizes.paddingMd),

          Text(
            'Choose Your Plan',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (profiles.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${profiles.length} member${profiles.length == 1 ? '' : 's'} in your household.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: AppSizes.paddingMd),

          // Pro card
          _TierCard(
            tierName: 'Pro',
            limit: proLimit,
            priceLabel: '${fmt(proPaisa)}/month',
            priceSub: '$proLimit suggestions/month',
            benefits: const [
              'Weather-based outfit matching',
              'AI seasonal wardrobe filtering',
              'Full wardrobe gap analysis',
              'Priority support',
            ],
            isActive: isProActive,
            isDisabled: isPrimeActive || _processingPayment,
            colorScheme: colorScheme,
            onSubscribe: () => _openCheckout('pro', proPaisa, userEmail),
          ),

          const SizedBox(height: AppSizes.paddingMd),

          // Prime card
          _TierCard(
            tierName: 'Prime',
            limit: primeLimit,
            priceLabel: '${fmt(primePaisa)}/month',
            priceSub: '$primeLimit suggestions/month',
            benefits: const [
              'Everything in Pro',
              '5× more suggestions per member',
              'Weather-based outfit matching',
              'AI seasonal wardrobe filtering',
              'Priority support',
            ],
            isActive: isPrimeActive,
            // Disabled when already on Prime (prevent duplicate payment)
            // or while a payment is in flight.
            isDisabled: isPrimeActive || _processingPayment,
            colorScheme: colorScheme,
            onSubscribe: () => _openCheckout('prime', primePaisa, userEmail),
            highlight: true,
          ),

          if (_processingPayment) ...[
            const SizedBox(height: AppSizes.paddingMd),
            const Center(child: CircularProgressIndicator()),
          ],

          const SizedBox(height: AppSizes.paddingLg),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tier card widget
// ---------------------------------------------------------------------------

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.tierName,
    required this.limit,
    required this.priceLabel,
    required this.priceSub,
    required this.benefits,
    required this.isActive,
    required this.isDisabled,
    required this.colorScheme,
    required this.onSubscribe,
    this.highlight = false,
  });

  final String tierName;
  final int limit;
  final String priceLabel;
  final String priceSub;
  final List<String> benefits;
  final bool isActive;
  final bool isDisabled;
  final ColorScheme colorScheme;
  final VoidCallback onSubscribe;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isActive ? colorScheme.primary : colorScheme.outlineVariant;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: isActive ? 2 : 1),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        color: highlight && !isActive
            ? colorScheme.secondaryContainer.withValues(alpha: 0.3)
            : null,
      ),
      padding: const EdgeInsets.all(AppSizes.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                tierName,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: Text(
                    'Active',
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    priceLabel,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    priceSub,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$limit suggestions/month',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          ...benefits.map(
            (b) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: colorScheme.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(b, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (isActive || isDisabled) ? null : onSubscribe,
            icon: const Icon(Icons.payment_outlined),
            label: Text(isActive ? 'Subscribed' : 'Subscribe'),
          ),
        ],
      ),
    );
  }
}
