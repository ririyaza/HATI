import 'package:flutter/material.dart';

import '../../dashboard/screen/dashboard_screen.dart';
import '../../dashboard/screen/support_resources_screen.dart';

/// Shown when the reassessment comparison is `noChange` (reached directly)
/// or `worsened` (reached after `WorsenedUpdateScreen` acknowledges the
/// result): supportive, non-alarming copy plus a path to the same resource
/// list used elsewhere in the app (`SupportResourcesScreen`), reused as-is
/// here rather than duplicating the hotline/guidance-center list.
class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key});

  static const _blue = Color(0xFF0B28D9);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "You're Not Alone",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _blue,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Your check-in shows things have felt about the same or a '
                'little harder lately. That takes courage to see, and it '
                "doesn't mean you've done anything wrong — social anxiety "
                "can ebb and flow, and that's completely normal.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F3FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      color: _blue,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'HATI is a self-help tool meant to support you — it '
                        "is not a diagnosis and doesn't replace care from a "
                        'mental health professional. If things feel like '
                        'more than you can manage alone, reaching out to '
                        'the resources below is a strong, healthy step.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1A1A2E),
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupportResourcesScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'View Support Resources',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    backgroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const DashboardScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text(
                    'Back to Dashboard',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
