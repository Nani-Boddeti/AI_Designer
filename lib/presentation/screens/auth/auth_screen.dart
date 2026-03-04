import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/vault_logo.dart';
import '../../providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Sign in / Sign up controllers
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  // Magic link controllers
  final _magicEmailCtrl = TextEditingController();
  final _magicFormKey = GlobalKey<FormState>();
  bool _magicLinkSent = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _magicEmailCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _signIn() async {
    if (!_signInFormKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).signInWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
    _checkError();
  }

  Future<void> _signUp() async {
    if (!_signUpFormKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).signUpWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
    _checkError();
  }

  Future<void> _sendMagicLink() async {
    if (!_magicFormKey.currentState!.validate()) return;
    await ref
        .read(authProvider.notifier)
        .sendMagicLink(_magicEmailCtrl.text.trim());

    if (!mounted) return;
    final authState = ref.read(authProvider);
    if (authState.hasError) {
      _showError(authState.error.toString());
    } else {
      setState(() => _magicLinkSent = true);
    }
  }

  void _checkError() {
    if (!mounted) return;
    final authState = ref.read(authProvider);
    if (authState.hasError) _showError(authState.error.toString());
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            height: 200,
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const VaultLogo(size: 72, variant: VaultLogoVariant.hero),
                    const SizedBox(height: 12),
                    const Text(
                      'VibeVault',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your Closet. AI Magic. Perfect for Any Vibe.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tabs
          Material(
            color: colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Sign In'),
                Tab(text: 'Sign Up'),
                Tab(text: 'Magic Link'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPasswordForm(isSignIn: true, isLoading: isLoading),
                _buildPasswordForm(isSignIn: false, isLoading: isLoading),
                _buildMagicLinkForm(isLoading: isLoading),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Password form (Sign In + Sign Up share layout)
  // ---------------------------------------------------------------------------

  Widget _buildPasswordForm({
    required bool isSignIn,
    required bool isLoading,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: isSignIn ? _signInFormKey : _signUpFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) =>
                  v == null || !v.contains('@') ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) =>
                  v == null || v.length < 6 ? 'Minimum 6 characters' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : (isSignIn ? _signIn : _signUp),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isSignIn ? 'Sign In' : 'Create Account'),
            ),
            if (!isSignIn) ...[
              const SizedBox(height: 12),
              Text(
                'After signing up you will receive a confirmation email. '
                'Tap the link to verify your account.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Magic link form
  // ---------------------------------------------------------------------------

  Widget _buildMagicLinkForm({required bool isLoading}) {
    if (_magicLinkSent) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_email_read_outlined,
                size: 72,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'Check your inbox!',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'We sent a sign-in link to\n${_magicEmailCtrl.text.trim()}\n\n'
              'Tap the link in the email to log in instantly — no password needed.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => setState(() => _magicLinkSent = false),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Use a different email'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _magicFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // Explanation card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No password needed. Enter your email and we\'ll send '
                      'a one-tap sign-in link — perfect for the whole family.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _magicEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
                hintText: 'you@example.com',
              ),
              validator: (v) =>
                  v == null || !v.contains('@') ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: isLoading ? null : _sendMagicLink,
              icon: isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: const Text('Send Magic Link'),
            ),
          ],
        ),
      ),
    );
  }
}
