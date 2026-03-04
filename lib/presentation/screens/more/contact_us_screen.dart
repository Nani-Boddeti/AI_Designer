import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  static const _supportEmail = 'support@vibevault.app';
  static const _feedbackEmail = 'feedback@vibevault.app';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Contact Us')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.paddingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(
                      Icons.support_agent_outlined,
                      size: 40,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'We\'re here to help!',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reach out for support, feedback, or partnership enquiries.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSizes.paddingLg),
            const Divider(),
            const SizedBox(height: AppSizes.paddingMd),

            // Contact tiles
            _ContactTile(
              icon: Icons.email_outlined,
              title: 'Support',
              subtitle: _supportEmail,
              onTap: () => _copyToClipboard(context, _supportEmail),
            ),
            _ContactTile(
              icon: Icons.rate_review_outlined,
              title: 'Feedback',
              subtitle: _feedbackEmail,
              onTap: () => _copyToClipboard(context, _feedbackEmail),
            ),

            const SizedBox(height: AppSizes.paddingMd),
            const Divider(),
            const SizedBox(height: AppSizes.paddingMd),

            // FAQ section
            Text(
              'Frequently Asked Questions',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSizes.paddingMd),
            const _FaqTile(
              question: 'How do I upgrade my plan?',
              answer:
                  'Go to More → tap your current plan tile → choose Pro or Prime.',
            ),
            const _FaqTile(
              question: 'How many outfit suggestions do I get?',
              answer:
                  'Free: 15/month. Pro: 50/month. Prime: 200/month. '
                  'All shared across the household.',
            ),
            const _FaqTile(
              question: 'Can I add family members?',
              answer:
                  'Yes! Go to More → Family Members → Add Member. '
                  'Share your invite code for others to join.',
            ),
            const _FaqTile(
              question: 'Why is my wardrobe item not appearing in suggestions?',
              answer:
                  'Ensure the item has season tags. Items marked as '
                  '"Untagged" are excluded from outfit generation.',
            ),

            const SizedBox(height: AppSizes.paddingLg),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$text copied to clipboard')),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.paddingSm),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.copy_outlined, size: 18),
        onTap: onTap,
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        question,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.paddingMd),
          child: Text(
            answer,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
