import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/dev_config.dart';
import '../../../core/widgets/vault_logo.dart';
import '../../../router/app_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/usage_provider.dart';
import '../wardrobe/wardrobe_screen.dart';
import '../outfit/style_session_screen.dart';
import '../calendar/style_calendar_screen.dart';

// ---------------------------------------------------------------------------
// Bottom navigation index
// ---------------------------------------------------------------------------

final homeTabIndexProvider =
    NotifierProvider<_HomeTabNotifier, int>(_HomeTabNotifier.new);

class _HomeTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int value) => state = value;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = ref.watch(homeTabIndexProvider);

    final tabs = [
      const _WardrobeTab(),
      const StyleSessionScreen(embeddedInHome: true),
      const StyleCalendarScreen(embeddedInHome: true),
      const _MoreTab(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: tabIndex,
        children: tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabIndex,
        onDestinationSelected: (i) =>
            ref.read(homeTabIndexProvider.notifier).set(i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checkroom_outlined),
            selectedIcon: Icon(Icons.checkroom),
            label: 'Wardrobe',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Outfits',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wardrobe tab – shows profile selector and wardrobe
// ---------------------------------------------------------------------------

class _WardrobeTab extends ConsumerWidget {
  const _WardrobeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reset selected profile whenever the logged-in user changes (sign-out/sign-in).
    // This prevents landing on another family member's wardrobe after re-login.
    ref.listen<AsyncValue<AuthState>>(authProvider, (previous, next) {
      final prevUserId = previous?.value?.user?.id;
      final nextUserId = next.value?.user?.id;
      if (prevUserId != nextUserId && nextUserId != null) {
        ref.read(currentProfileIdProvider.notifier).set(null);
      }
    });

    final profilesAsync = ref.watch(profilesProvider);
    final selectedId = ref.watch(currentProfileIdProvider);
    // Prefer the logged-in user's own profile as the default selection.
    final loggedInProfileId = ref.watch(authProvider).value?.profile?.id;

    return profilesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (profiles) {
        if (profiles.isEmpty) {
          return const _EmptyProfiles();
        }

        // Auto-select: prefer logged-in user's profile, then first profile.
        final defaultId = loggedInProfileId != null &&
                profiles.any((p) => p.id == loggedInProfileId)
            ? loggedInProfileId
            : profiles.first.id;
        final effectiveId = selectedId ?? defaultId;

        // Persist the selection.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (selectedId == null) {
            ref.read(currentProfileIdProvider.notifier).set(effectiveId);
          }
        });

        return WardrobeScreen(
          profileId: effectiveId,
          showProfileSwitcher: true,
          profiles: profiles,
          onProfileChanged: (id) =>
              ref.read(currentProfileIdProvider.notifier).set(id),
        );
      },
    );
  }
}

class _EmptyProfiles extends StatelessWidget {
  const _EmptyProfiles();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wardrobe')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.group_add_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No family members yet'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.profiles),
              icon: const Icon(Icons.add),
              label: const Text('Add Members'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// More tab
// ---------------------------------------------------------------------------

class _MoreTab extends ConsumerWidget {
  const _MoreTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider).value;
    final usageAsync = ref.watch(usageNotifierProvider);
    final bypass = ref.watch(devBypassLimitsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const VaultLogo(size: 28, variant: VaultLogoVariant.adaptive),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // Subscription / usage card — always visible, usage fills in when ready
          Builder(builder: (context) {
            final h = authState?.household;
            final label = h?.isPrimeActive == true
                ? 'Prime Plan'
                : h?.isProActive == true
                    ? 'Pro Plan'
                    : 'Free Plan';
            final isSubscribed = h?.isSubscribed ?? false;
            final subtitle = usageAsync.when(
              loading: () => 'Loading usage…',
              error: (e, _) => 'Tap to manage subscription',
              data: (usage) =>
                  '${usage.count} / ${usage.limit} used this month',
            );
            return ListTile(
              leading: Icon(
                Icons.workspace_premium_outlined,
                color: isSubscribed ? colorScheme.primary : null,
              ),
              title: Text(label),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.subscription),
            );
          }),
          const Divider(),

          _MoreTile(
            icon: Icons.people_outline,
            title: 'Family Members',
            subtitle: 'Manage profiles',
            onTap: () => context.push(AppRoutes.profiles),
          ),
          _MoreTile(
            icon: Icons.view_column_outlined,
            title: 'Virtual Lineup',
            subtitle: 'See everyone side by side',
            onTap: () => context.push(AppRoutes.virtualLineup),
          ),
          _MoreTile(
            icon: Icons.shopping_bag_outlined,
            title: 'Gap Filler',
            subtitle: 'AI-recommended purchases',
            onTap: () => context.push(AppRoutes.gapFiller),
          ),
          _MoreTile(
            icon: Icons.contact_support_outlined,
            title: 'Contact Us',
            subtitle: 'Support & feedback',
            onTap: () => context.push(AppRoutes.contactUs),
          ),
          _MoreTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => context.push(AppRoutes.privacyPolicy),
          ),
          const Divider(),
          if (authState?.household != null)
            ListTile(
              leading: const Icon(Icons.vpn_key_outlined),
              title: const Text('Invite Code'),
              subtitle: Text(authState!.household!.inviteCode,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: colorScheme.primary)),
              trailing: IconButton(
                icon: const Icon(Icons.copy_outlined),
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                      text: authState.household!.inviteCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite code copied!')),
                  );
                },
              ),
            ),

          // Dev settings — only visible in debug builds
          if (kDebugMode) ...[
            const Divider(),
            SwitchListTile(
              secondary: const Icon(Icons.bug_report_outlined),
              title: const Text('Dev: Bypass usage limits'),
              subtitle: const Text('Debug builds only'),
              value: bypass,
              onChanged: (v) =>
                  ref.read(devBypassLimitsProvider.notifier).set(v),
            ),
          ],

          const Divider(),
          _MoreTile(
            icon: Icons.logout,
            title: 'Sign Out',
            textColor: colorScheme.error,
            onTap: () async {
              await ref.read(authProvider.notifier).signOut();
            },
          ),
          _MoreTile(
            icon: Icons.delete_forever_outlined,
            title: 'Delete Account',
            subtitle: 'Permanently removes all your data',
            textColor: colorScheme.error,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Account?'),
                  content: const Text(
                    'This permanently deletes all your wardrobe items, '
                    'outfits, calendar events, and your account. '
                    'This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.error,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(authProvider.notifier).deleteAccount();
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.textColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(title, style: TextStyle(color: textColor)),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
