import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_menu_button.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';

/// Terms and Conditions & Privacy Policy
/// Winter Intelligence Engine™ — Snow Removal Expert Ltd.
/// Content from official PDF; Effective February 11, 2026.
class TermsAndPrivacyScreen extends StatelessWidget {
  const TermsAndPrivacyScreen({super.key});

  static const String _company = 'Snow Removal Expert Ltd.';
  static const String _address = '1501-1600M Beach Avenue';
  static const String _city = 'Vancouver, BC V6G1Y7 Canada';
  static const String _email = 'info@snowremovalexpert.com';
  static const String _website = 'https://www.snowremovalexpert.com';

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: const AppMenuButton(),
        title: const Text(
          'Terms & Privacy',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms and Conditions & Privacy Policy',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Winter Intelligence Engine™ · $_company',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            Text(
              'Effective: February 11, 2026',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),

            // --- TERMS AND CONDITIONS ---
            _sectionTitle(context, 'Terms and Conditions'),
            _paragraph(context, '1. Agreement to Terms\nThese Terms and Conditions (“Terms”) govern your access to and use of the Winter Intelligence Engine™ mobile application (the “App”), operated by Snow Removal Expert Ltd. (“Company,” “we,” “our,” or “us”). By downloading, installing, accessing, or using the App on iOS or Android devices, you agree to be legally bound by these Terms. If you do not agree, you must not use the App.'),
            _paragraph(context, '2. Description of Services\nThe App provides: predictive snow and ice monitoring; property-specific winter risk forecasting; snow removal scheduling insights; service notifications and operational alerts; account management for Snow Removal Expert clients. The App is a decision-support tool. It does not replace municipal advisories, professional judgment, or emergency services.'),
            _paragraph(context, '3. Eligibility\nYou must: be at least 18 years old or the age of majority in your jurisdiction; have legal capacity to enter into a binding agreement; use the App only for lawful purposes.'),
            _paragraph(context, '4. Account Registration\nIf you create an account, you agree to: provide accurate and complete information; maintain confidentiality of login credentials; notify us of unauthorized access; accept responsibility for all activity under your account. We reserve the right to suspend or terminate accounts that violate these Terms.'),
            _paragraph(context, '5. Acceptable Use\nYou agree not to: use the App for unlawful purposes; interfere with security or functionality; reverse engineer, copy, or exploit the software; use bots, scrapers, or automated systems without authorization; introduce malicious code. Violation may result in immediate termination.'),
            _paragraph(context, '6. App Store Compliance\nApple iOS: These Terms are between you and Snow Removal Expert Ltd., not Apple Inc. Google Play: Google LLC is not responsible for the App or claims related to its use. Your use must comply with Google Play Terms of Service.'),
            _paragraph(context, '7. Service Availability & Accuracy\nThe Winter Intelligence Engine™ uses predictive modeling and third-party weather data. We do not guarantee forecast accuracy, continuous availability, error-free performance, or timeliness of alerts. You agree not to rely solely on the App for safety-critical decisions.'),
            _paragraph(context, '8. Subscription & Payments (If Applicable)\nIf subscriptions are offered: fees are disclosed before purchase; subscriptions may auto-renew unless canceled; payments are processed via Apple App Store or Google Play; refunds are subject to platform policies.'),
            _paragraph(context, '9. Intellectual Property\nAll content including Winter Intelligence Engine™ systems, algorithms, branding, and interface design are the exclusive property of Snow Removal Expert Ltd. You are granted a limited, non-transferable license for authorized use only.'),
            _paragraph(context, '10. Privacy\nYour use of the App is governed by our Privacy Policy below.'),
            _paragraph(context, '11. Limitation of Liability\nTo the maximum extent permitted by law, Snow Removal Expert Ltd. shall not be liable for indirect or consequential damages, loss of profits, property damage due to weather events, or personal injury arising from reliance on App data. Total liability shall not exceed amounts paid by you in the preceding 12 months.'),
            _paragraph(context, '12. Disclaimer of Warranties\nThe App is provided “AS IS” and “AS AVAILABLE.” We disclaim all warranties including merchantability and fitness for a particular purpose. Use at your own risk.'),
            _paragraph(context, '13. Indemnification\nYou agree to indemnify Snow Removal Expert Ltd. against claims arising from misuse of the App, violation of these Terms, or violation of laws or third-party rights.'),
            _paragraph(context, '14. Termination\nWe may suspend or terminate access if you breach these Terms, if required by law, or if we discontinue the App. You may discontinue use at any time by uninstalling the App.'),
            _paragraph(context, '15. Modifications\nWe may update these Terms at any time. Continued use constitutes acceptance of revised Terms.'),
            _paragraph(context, '16. Governing Law\nThese Terms are governed by the laws of the Province of British Columbia and applicable Canadian federal laws. Disputes shall be resolved in the courts of British Columbia.'),

            const SizedBox(height: 24),

            // --- PRIVACY POLICY ---
            _sectionTitle(context, 'Privacy Policy'),
            _paragraph(context, '1. Introduction\nSnow Removal Expert Ltd. respects your privacy. This Policy explains how we collect, use, disclose, and safeguard information when you use the Winter Intelligence Engine™ App. This Policy complies with Canada’s PIPEDA, provincial privacy legislation, and Apple/Google requirements. By using the App, you consent to this Policy.'),
            _paragraph(context, '2. Information We Collect\nA. Personal: full name, email, phone, company name, property addresses, login credentials, billing (if applicable). B. Location: GPS and device-based location with permission. C. Device & technical: device type, OS, app version, IP, usage, crash logs. D. Weather & property data.'),
            _paragraph(context, '3. How We Use Information\nWe use information to provide forecasting and alerts, manage snow removal services, improve accuracy, send notifications, process payments, provide support, maintain security, and comply with legal obligations. We do not sell personal information.'),
            _paragraph(context, '4. Consent (Canada)\nWe collect and use information with your knowledge and consent for reasonable business purposes under PIPEDA. You may withdraw consent subject to legal or contractual limitations.'),
            _paragraph(context, '5. Data Sharing\nWe may share data with service providers (cloud, payments, weather, analytics), legal authorities when required, and in connection with business transfers. Service providers are contractually required to safeguard data.'),
            _paragraph(context, '6. Data Security\nWe use reasonable safeguards: HTTPS, secure cloud infrastructure, access controls, monitoring. No system is completely secure.'),
            _paragraph(context, '7. Data Retention\nWe retain information only as long as necessary for business, contractual, and legal purposes. Data is deleted or anonymized when no longer required.'),
            _paragraph(context, '8. Your Rights\nYou may request access, correction, withdraw consent, or request deletion where permitted. Contact: $_email'),
            _paragraph(context, '9. Children’s Privacy\nThe App is not intended for individuals under 18. We do not knowingly collect data from minors.'),
            _paragraph(context, '10. International Transfers\nData may be processed outside BC or Canada. Appropriate safeguards are implemented.'),
            _paragraph(context, '11. Third-Party Services\nThe App may integrate with Apple, Google, weather providers, and payment processors. Their privacy policies apply separately.'),
            _paragraph(context, '12. Analytics & Notifications\nWe may use analytics and crash reporting. Push notifications may include snow alerts, risk notifications, and service updates. Notifications can be disabled in device settings.'),
            _paragraph(context, '13. Changes\nWe may update this Privacy Policy. Continued use constitutes acceptance of revisions.'),

            const SizedBox(height: 24),

            // --- CONTACT ---
            _sectionTitle(context, 'Contact Information'),
            SelectableText(
              '$_company\n$_address\n$_city',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.4),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _launchUrl('mailto:$_email'),
              child: Text('Email: $_email', style: const TextStyle(fontSize: 14, color: Colors.blue, decoration: TextDecoration.underline)),
            ),
            GestureDetector(
              onTap: () => _launchUrl(_website),
              child: Text('Website: $_website', style: const TextStyle(fontSize: 14, color: Colors.blue, decoration: TextDecoration.underline)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
            ),
      ),
    );
  }

  Widget _paragraph(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SelectableText(
        text,
        style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.45),
      ),
    );
  }
}
