import 'package:flutter/material.dart';

import '../../onboarding/consent_content.dart';

/// Read-only view of the informed consent information the user reviewed
/// and agreed to during onboarding (`onboarding/consent_content.dart`),
/// reachable any time from Profile > Settings > Privacy.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B28D9),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Privacy & Consent',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E6FF), width: 1.2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Scrollbar(
                thumbVisibility: true,
                radius: const Radius.circular(8),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontSize: 14.5,
                        height: 1.65,
                      ),
                      children: [
                        ...kConsentStudyAboutSpans,
                        const TextSpan(text: '\n'),
                        ...kConsentDataCollectedSpans,
                        const TextSpan(text: '\n'),
                        ...kConsentRisksSupportSpans,
                        const TextSpan(text: '\n'),
                        ...kConsentParticipantRightsSpans,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
