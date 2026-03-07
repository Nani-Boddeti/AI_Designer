import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/tier_calculator.dart';
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

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  late final Razorpay _razorpay;
  bool _processingPayment = false;
  String _targetTier = 'pro'; // which tier the user is trying to subscribe to

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (!mounted) return;

    setState(() => _processingPayment = true);
    try {
      final householdId =
          ref.read(authProvider).value?.household?.id ?? '';

      final client = ref.read(supabaseServiceProvider).client;
      final result = await client.functions.invoke(
        'verify-razorpay-payment',
        body: {
          'payment_id': response.paymentId ?? '',
          'order_id': response.orderId ?? '',
          'signature': response.signature ?? '',
          'tier': _targetTier,
          'household_id': householdId,
        },
      );

      if (result.data?['success'] != true) {
        throw Exception(result.data?['error'] ?? 'Verification failed');
      }

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
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e, stack, reason: 'payment-verification-failed', fatal: false,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment received but activation failed. Contact support.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingPayment = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
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

  Future<void> _openCheckout(
      String targetTier, String userEmail) async {
    final householdId =
        ref.read(authProvider).value?.household?.id ?? '';
    if (householdId.isEmpty) return;

    setState(() {
      _targetTier = targetTier;
      _processingPayment = true;
    });

    try {
      // Create order server-side — amount and key come from the Edge Function.
      final client = ref.read(supabaseServiceProvider).client;
      final result = await client.functions.invoke(
        'create-razorpay-order',
        body: {'tier': targetTier, 'household_id': householdId},
      );

      final data = result.data as Map<String, dynamic>?;
      if (data == null || data['order_id'] == null) {
        throw Exception(data?['error'] ?? 'Failed to create order');
      }

      final tierLabel = targetTier == 'prime' ? 'Prime' : 'Pro';
      final options = {
        'key': data['key_id'] as String,
        'amount': data['amount'] as int,
        'order_id': data['order_id'] as String,
        'currency': data['currency'] as String? ?? 'INR',
        'name': 'VibeVault',
        'description': '$tierLabel Plan — monthly outfit suggestions',
        'prefill': {'email': userEmail},
        'theme': {'color': '#6750A4'},
      };
      _razorpay.open(options);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not initiate payment. Please try again.')),
        );
        setState(() => _processingPayment = false);
      }
    }
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

    final dynamicPricing = household?.dynamicPricing ?? true;

    // Limits and prices respect the household's dynamicPricing setting.
    final proLimit = TierCalculator.monthlyLimit('pro', profiles, dynamicPricing: dynamicPricing);
    final primeLimit = TierCalculator.monthlyLimit('prime', profiles, dynamicPricing: dynamicPricing);
    final proPaisa = TierCalculator.pricePaisa('pro', profiles, dynamicPricing: dynamicPricing);
    final primePaisa = TierCalculator.pricePaisa('prime', profiles, dynamicPricing: dynamicPricing);

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
                  'Household this month: ${usage.count} / ${usage.limit} suggestions used',
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
            '${usage.remaining} suggestions left for your household',
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
              dynamicPricing
                  ? 'Shared across your family · scales with ${profiles.length} member${profiles.length == 1 ? '' : 's'}.'
                  : 'Fixed limits & price shared across your family — doesn\'t change as members join.',
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
            priceSub: '₹5/suggestion · min 50/month',
            benefits: const [
              'Up to 50+ outfit suggestions shared across your whole family/month',
              'Weather-based outfit matching',
              'AI seasonal wardrobe filtering',
              'Full wardrobe gap analysis',
              'Priority support',
            ],
            isActive: isProActive,
            isDisabled: isPrimeActive || _processingPayment,
            colorScheme: colorScheme,
            dynamicPricing: dynamicPricing,
            profileCount: profiles.length,
            onSubscribe: () => _openCheckout('pro', userEmail),
          ),

          const SizedBox(height: AppSizes.paddingMd),

          // Prime card
          _TierCard(
            tierName: 'Prime',
            limit: primeLimit,
            priceLabel: '${fmt(primePaisa)}/month',
            priceSub: '₹5/suggestion · min 200/month',
            benefits: const [
              'Up to 200+ outfit suggestions shared across your whole family/month',
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
            dynamicPricing: dynamicPricing,
            profileCount: profiles.length,
            onSubscribe: () => _openCheckout('prime', userEmail),
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
    required this.dynamicPricing,
    required this.profileCount,
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
  final bool dynamicPricing;
  final int profileCount;
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
            '$limit suggestions/month shared across your family',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              Chip(
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
                label: Text(
                  dynamicPricing ? 'Scales with family size' : 'Fixed price',
                  style: const TextStyle(fontSize: 11),
                ),
                avatar: Icon(
                  dynamicPricing ? Icons.group : Icons.lock_outline,
                  size: 14,
                ),
              ),
              if (dynamicPricing && profileCount > 0)
                Chip(
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    '$profileCount member${profileCount == 1 ? '' : 's'} → $limit/month',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
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
