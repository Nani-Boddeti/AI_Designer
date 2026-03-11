import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/household.dart';
import '../../providers/auth_provider.dart';
import '../../../router/app_router.dart';

class HouseholdPickerScreen extends ConsumerWidget {
  const HouseholdPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);
    final authState = authAsync.value;
    final allHouseholds = authState?.allHouseholds ?? [];
    final activeId = authState?.household?.id;
    final adminIds = authState?.adminHouseholdIds ?? {};
    final isSwitching = authState?.isLoading ?? false;
    final switchError = authState?.error;

    // Mandatory = user has no household selected yet (post-login flow).
    // Optional = user navigated here from settings to switch.
    final isMandatory = activeId == null;

    return PopScope(
      // Block back navigation in mandatory mode — user must pick a household.
      canPop: !isMandatory,
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(
          title: Text(isMandatory ? 'Select Your Household' : 'Switch Household'),
          backgroundColor: AppTheme.scaffoldBg,
          automaticallyImplyLeading: !isMandatory,
        ),
        body: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isMandatory ? Icons.waving_hand_rounded : Icons.swap_horiz_rounded,
                    color: AppTheme.primary,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isMandatory
                        ? 'Welcome back!'
                        : 'Your Households',
                    style: const TextStyle(
                      color: AppTheme.onBgColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isMandatory
                        ? 'You belong to ${allHouseholds.length} household${allHouseholds.length == 1 ? '' : 's'}. Pick one to continue.'
                        : allHouseholds.length == 1
                            ? 'This is your only household. Create or join another below.'
                            : 'Tap a household to switch to it.',
                    style: const TextStyle(
                      color: AppTheme.onSurfaceVar,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Household list
            Expanded(
              child: allHouseholds.isEmpty
                  ? const Center(
                      child: Text(
                        'No households found.',
                        style: TextStyle(color: AppTheme.onSurfaceVar),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        if (switchError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              switchError,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        for (final h in allHouseholds)
                          _HouseholdCard(
                            household: h,
                            isActive: h.id == activeId,
                            isAdmin: adminIds.contains(h.id),
                            isLoading: isSwitching,
                            onTap: () => _switchTo(context, ref, h, isMandatory),
                          ),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => context.push(AppRoutes.householdSetup),
                          icon: const Icon(Icons.add),
                          label: const Text('Create or Join a Household'),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchTo(
    BuildContext context,
    WidgetRef ref,
    Household h,
    bool isMandatory,
  ) async {
    await ref.read(authProvider.notifier).switchHousehold(h.id);
    if (!context.mounted) return;
    // Always go to home after switching — handles both mandatory (first-time
    // picker) and optional (More > Households) flows. Router no longer
    // auto-redirects away from /household-picker for optional navigation.
    context.go(AppRoutes.home);
  }
}

// ---------------------------------------------------------------------------

class _HouseholdCard extends StatelessWidget {
  const _HouseholdCard({
    required this.household,
    required this.isActive,
    required this.isAdmin,
    required this.isLoading,
    required this.onTap,
  });

  final Household household;
  final bool isActive;
  final bool isAdmin;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isActive
            ? Border.all(color: AppTheme.primary, width: 2)
            : Border.all(color: AppTheme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: (isActive || isLoading) ? null : onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryContainer,
          child: Text(
            household.name.isNotEmpty ? household.name[0].toUpperCase() : 'H',
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                household.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onBgColor,
                ),
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Admin',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          household.tier == 'free' ? 'Free plan' : household.tier.toUpperCase(),
          style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVar),
        ),
        trailing: isActive
            ? const Icon(Icons.check_circle, color: AppTheme.primary)
            : isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right, color: AppTheme.onSurfaceVar),
      ),
    );
  }
}
