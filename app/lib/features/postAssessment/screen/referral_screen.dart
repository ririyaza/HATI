import 'package:flutter/material.dart';

import '../../dashboard/screen/dashboard_screen.dart';
import '../../dashboard/screen/support_resources_screen.dart';
import '../../dashboard/widgets/hati_sprite_animation.dart';
import '../data/assessment_comparison.dart';

/// Shown for any [PostAssessmentCategory] whose suggested action encourages
/// professional support (`category.isReferral`): categories 2, 4, 5, and 6
/// of the thesis's post-assessment action table. Hati's dialogue reflects
/// the specific category (SPIN worsened vs. GAD-7 elevated read very
/// differently), followed by supportive, non-alarming copy and a path to
/// the same resource list used elsewhere in the app
/// (`SupportResourcesScreen`), reused as-is here rather than duplicating
/// the hotline/guidance-center list.
class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key, required this.category});

  final PostAssessmentCategory category;

  static const _blue = Color(0xFF0B28D9);

  String get _hatiMessage {
    switch (category) {
      case PostAssessmentCategory.improvedGad7Elevated:
        return "Your SPIN score has improved, and that's real progress. "
            "Your GAD-7 result today points to another area worth "
            'attention, though — reaching out to a mental health '
            'professional could help.';
      case PostAssessmentCategory.noChangeGad7Elevated:
        return "Your SPIN score hasn't changed much since last time, and "
            'your GAD-7 result today is elevated. That takes courage to '
            'see, and talking to a mental health professional could help.';
      case PostAssessmentCategory.worsenedNotElevated:
        return 'Your latest SPIN score has gone up since last time. '
            "That's nothing to be ashamed of — reaching out to a mental "
            "health professional could help, and I'm still here with you.";
      case PostAssessmentCategory.worsenedGad7Elevated:
        return 'Your SPIN score has gone up, and your GAD-7 result today '
            "is elevated too. I'd strongly encourage reaching out to a "
            'qualified mental health professional for support.';
      case PostAssessmentCategory.improvedNoConcerns:
      case PostAssessmentCategory.improvedStillSignificant:
      case PostAssessmentCategory.noChangeNotElevated:
        // Not reachable via `category.isReferral` — kept for exhaustiveness.
        return 'Your check-in shows things have felt about the same or a '
            "little harder lately. That's nothing to be ashamed of, and "
            'support is available whenever you need it.';
    }
  }

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
              const SizedBox(height: 16),
              HatiSpriteAnimation(
                size: 200,
                message: _hatiMessage,
                startDelay: Duration.zero,
                persistBubble: true,
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
                        'HATI is a self-help tool meant to support you. It '
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
