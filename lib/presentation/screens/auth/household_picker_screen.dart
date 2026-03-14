import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/household.dart';
import '../../providers/auth_provider.dart';
import '../../../router/app_router.dart';

class HouseholdPickerScreen extends ConsumerStatefulWidget {
  const HouseholdPickerScreen({super.key});

  @override
  ConsumerState<HouseholdPickerScreen> createState() =>
      _HouseholdPickerScreenState();
}

class _HouseholdPickerScreenState extends ConsumerState<HouseholdPickerScreen> {
  /// ID of the household currently being switched to (null = not switching).
  String? _switchingToId;

  /// ID of the household currently being left (null = not leaving).
  String? _leavingHouseholdId;

  bool get _isBusy => _switchingToId != null || _leavingHouseholdId != null;

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    final authState = authAsync.value;
    final allHouseholds = authState?.allHouseholds ?? [];
    final activeId = authState?.household?.id;
    final adminIds = authState?.adminHouseholdIds ?? {};
    final switchError = authState?.error;

    // Clear local loading flags if the provider finished (success or error).
    // Use the same condition as the original: only clear once isLoading has
    // gone true (operation started) and come back false (operation finished).
    if (_switchingToId != null && authState?.isLoading == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _switchingToId = null);
      });
    }
    if (_leavingHouseholdId != null && authState?.isLoading == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _leavingHouseholdId = null);
      });
    }

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
                            isLoading: _switchingToId == h.id || _leavingHouseholdId == h.id,
                            isDisabled: _isBusy,
                            onTap: () => _switchTo(h),
                            onLeave: _isBusy ? null : () => _leaveHousehold(h, adminIds.contains(h.id)),
                          ),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _switchingToId != null
                              ? null
                              : () => context.push(AppRoutes.householdSetup),
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

  Future<void> _switchTo(Household h) async {
    setState(() => _switchingToId = h.id);
    await ref.read(authProvider.notifier).switchHousehold(h.id);
    if (!mounted) return;

    final error = ref.read(authProvider).value?.error;
    if (error == null) {
      // Switch succeeded — navigate home.
      context.go(AppRoutes.home);
    } else {
      // Switch failed — stay on picker, error is shown in the UI.
      setState(() => _switchingToId = null);
    }
  }

  Future<void> _leaveHousehold(Household h, bool isAdmin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _LeaveConfirmDialog(household: h, isAdmin: isAdmin),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _leavingHouseholdId = h.id);
    await ref.read(authProvider.notifier).leaveHousehold(h.id);
    if (!mounted) return;
    setState(() => _leavingHouseholdId = null);
    // leaveHousehold() updates AuthState directly:
    //   - No households left  → needsHouseholdSetup=true → router → /household-setup
    //   - Households remain   → auto-selects first remaining, stays on picker
  }
}

// ---------------------------------------------------------------------------

class _LeaveConfirmDialog extends StatelessWidget {
  const _LeaveConfirmDialog({
    required this.household,
    required this.isAdmin,
  });

  final Household household;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Leave Household?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('You are about to leave "${household.name}".'),
          const SizedBox(height: 12),
          if (isAdmin)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.admin_panel_settings,
                      color: colorScheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You are the admin. The next longest-standing member will be promoted automatically.',
                      style: TextStyle(
                          fontSize: 13, color: colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          if (!isAdmin) ...[
            Text(
              'You will lose access to this household and its wardrobe data.',
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Leave'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _HouseholdCard extends StatelessWidget {
  const _HouseholdCard({
    required this.household,
    required this.isActive,
    required this.isAdmin,
    required this.isLoading,
    required this.isDisabled,
    required this.onTap,
    required this.onLeave,
  });

  final Household household;
  final bool isActive;
  final bool isAdmin;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onTap;
  final VoidCallback? onLeave;

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
        onTap: (isActive || isDisabled) ? null : onTap,
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
        trailing: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'leave') onLeave?.call();
                },
                enabled: onLeave != null,
                itemBuilder: (ctx) => [
                  PopupMenuItem<String>(
                    value: 'leave',
                    child: Row(
                      children: [
                        Icon(Icons.exit_to_app,
                            color: Theme.of(ctx).colorScheme.error, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Leave Household',
                          style: TextStyle(
                              color: Theme.of(ctx).colorScheme.error),
                        ),
                      ],
                    ),
                  ),
                ],
                icon: isActive
                    ? const Icon(Icons.check_circle, color: AppTheme.primary)
                    : const Icon(Icons.more_vert, color: AppTheme.onSurfaceVar),
              ),
      ),
    );
  }
}
