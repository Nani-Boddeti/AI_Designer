import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class HouseholdSetupScreen extends ConsumerStatefulWidget {
  const HouseholdSetupScreen({super.key});

  @override
  ConsumerState<HouseholdSetupScreen> createState() =>
      _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends ConsumerState<HouseholdSetupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Create household
  final _householdNameCtrl = TextEditingController();
  final _createProfileNameCtrl = TextEditingController();
  final _createFormKey = GlobalKey<FormState>();

  // Join household
  final _inviteCodeCtrl = TextEditingController();
  final _joinProfileNameCtrl = TextEditingController();
  final _joinFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _householdNameCtrl.dispose();
    _createProfileNameCtrl.dispose();
    _inviteCodeCtrl.dispose();
    _joinProfileNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _createHousehold() async {
    if (!_createFormKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).createHousehold(
          householdName: _householdNameCtrl.text.trim(),
          profileName: _createProfileNameCtrl.text.trim(),
        );
    _showErrorIfNeeded();
  }

  Future<void> _joinHousehold() async {
    if (!_joinFormKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).joinHousehold(
          inviteCode: _inviteCodeCtrl.text.trim().toUpperCase(),
          profileName: _joinProfileNameCtrl.text.trim(),
        );
    _showErrorIfNeeded();
  }

  void _showErrorIfNeeded() {
    if (!mounted) return;
    final err = ref.read(authProvider).error;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            height: 180,
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.home_rounded,
                        size: 44, color: Colors.white),
                    const SizedBox(height: 10),
                    const Text(
                      'Set Up Your Household',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create or join a family group',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Material(
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Create New'),
                Tab(text: 'Join Existing'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCreateForm(isLoading: isLoading),
                _buildJoinForm(isLoading: isLoading),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm({required bool isLoading}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _createFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'Start fresh with a new household for your family.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _householdNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Household Name',
                hintText: 'e.g. The Smith Family',
                prefixIcon: Icon(Icons.house_outlined),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter a household name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _createProfileNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                hintText: 'e.g. Sarah',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter your name' : null,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: isLoading ? null : _createHousehold,
              icon: const Icon(Icons.add_home_outlined),
              label: isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create Household'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinForm({required bool isLoading}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _joinFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'Enter the invite code shared by a household member.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _inviteCodeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Invite Code',
                hintText: 'e.g. ABC12345',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
              validator: (v) =>
                  v == null || v.length < 6 ? 'Enter the 8-character code' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _joinProfileNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                hintText: 'e.g. Mike',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter your name' : null,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: isLoading ? null : _joinHousehold,
              icon: const Icon(Icons.login_rounded),
              label: isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Join Household'),
            ),
          ],
        ),
      ),
    );
  }
}
