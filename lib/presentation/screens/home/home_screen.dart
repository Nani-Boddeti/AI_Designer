import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/dev_config.dart';
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

final homeTabIndexProvider = StateProvider<int>((ref) => 0);

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
            ref.read(homeTabIndexProvider.notifier).state = i,
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
            ref.read(currentProfileIdProvider.notifier).state = effectiveId;
          }
        });

        return WardrobeScreen(
          profileId: effectiveId,
          showProfileSwitcher: true,
          profiles: profiles,
          onProfileChanged: (id) =>
              ref.read(currentProfileIdProvider.notifier).state = id,
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
      appBar: AppBar(title: const Text('More')),
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
                  ref.read(devBypassLimitsProvider.notifier).state = v,
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
