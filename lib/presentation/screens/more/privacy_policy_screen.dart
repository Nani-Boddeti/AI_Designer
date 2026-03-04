import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: SelectableText.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Privacy Policy\n\n',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: 'Effective date: January 1, 2025\n\n',
                style: TextStyle(color: Colors.grey),
              ),

              // --- Data we collect ---
              TextSpan(
                text: '1. Data We Collect\n\n',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    'We collect the following information when you use VibeVault:\n\n'
                    '• Account information: email address and authentication tokens.\n'
                    '• Profile information: name, age group, gender, and style preferences you enter.\n'
                    '• Wardrobe photos: images you upload, which are stored in Supabase Storage.\n'
                    '• Calendar events: outfit plans and dates you create.\n'
                    '• Usage data: feature usage counts for plan enforcement (e.g. outfit generations per month).\n\n',
              ),

              // --- How we use it ---
              TextSpan(
                text: '2. How We Use Your Data\n\n',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    'Your data is used solely to provide the VibeVault service:\n\n'
                    '• Wardrobe photos are sent to Google Gemini for AI clothing tagging and outfit generation.\n'
                    '• Photos may be sent to remove.bg for background removal processing.\n'
                    '• Your city or coordinates may be sent to OpenWeatherMap to provide weather-aware outfit suggestions.\n'
                    '• We do not sell, rent, or share your personal data with advertisers or third parties beyond the service providers listed below.\n\n',
              ),

              // --- Third-party services ---
              TextSpan(
                text: '3. Third-Party Services\n\n',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    '• Supabase (supabase.com) — database and file storage. Data is stored in secure cloud infrastructure.\n'
                    '• Google Gemini (google.com) — AI model for clothing analysis and outfit generation. Images are sent for inference and are subject to Google\'s privacy policy.\n'
                    '• remove.bg — background removal for wardrobe photos. Images are subject to remove.bg\'s privacy policy.\n'
                    '• OpenWeatherMap — weather data by location. Your approximate location may be sent to fetch forecasts.\n'
                    '• Razorpay — payment processing for Pro/Prime subscriptions. Payment data is handled entirely by Razorpay and never stored by VibeVault.\n\n',
              ),

              // --- Data deletion ---
              TextSpan(
                text: '4. Data Deletion\n\n',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    'You can permanently delete your account and all associated data at any time from the More tab → Delete Account. This removes all wardrobe items, outfits, calendar events, and your account from our servers.\n\n',
              ),

              // --- Data retention ---
              TextSpan(
                text: '5. Data Retention\n\n',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    'We retain your data only as long as your account is active. Upon account deletion, all personal data is permanently erased from our systems within 30 days.\n\n',
              ),

              // --- Security ---
              TextSpan(
                text: '6. Security\n\n',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    'All data is transmitted over HTTPS. Database access is protected by Row Level Security (RLS) policies that restrict each user to their own household\'s data.\n\n',
              ),

              // --- Contact ---
              TextSpan(
                text: '7. Contact\n\n',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    'For privacy-related questions or data requests, contact us at:\n'
                    'support@vibevault.app\n',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
