import 'package:flutter/material.dart';

import '../../dashboard/screen/dashboard_screen.dart';
import '../../dashboard/widgets/hati_sprite_animation.dart';
import '../data/assessment_comparison.dart';

/// Shown for any [PostAssessmentCategory] whose suggested action doesn't
/// encourage professional support (`!category.isReferral`): categories
/// 1.1, 1.2, and 3 of the thesis's post-assessment action table. Positive
/// reinforcement tailored to the specific category, then back to the
/// dashboard (whose Progress tab already reflects the new SPIN pre/post
/// scores via `spinAssessments/post`).
class ProgressUpdateScreen extends StatelessWidget {
  const ProgressUpdateScreen({super.key, required this.category});

  final PostAssessmentCategory category;

  static const _blue = Color(0xFF0B28D9);

  String get _title {
    switch (category) {
      case PostAssessmentCategory.noChangeNotElevated:
        return "You're Keeping At It";
      case PostAssessmentCategory.improvedNoConcerns:
      case PostAssessmentCategory.improvedStillSignificant:
      case PostAssessmentCategory.improvedGad7Elevated:
      case PostAssessmentCategory.noChangeGad7Elevated:
      case PostAssessmentCategory.worsenedNotElevated:
      case PostAssessmentCategory.worsenedGad7Elevated:
        // Only the three non-referral cases above actually reach this
        // screen — kept exhaustive for compile safety.
        return "You're Making Progress!";
    }
  }

  String get _hatiMessage {
    switch (category) {
      case PostAssessmentCategory.improvedStillSignificant:
        return "Your SPIN score has improved — that's real progress. Your "
            'results still show significant symptoms, so let\'s keep '
            'going together, one scenario at a time.';
      case PostAssessmentCategory.noChangeNotElevated:
        return "Your SPIN score is about the same as last time. That's "
            "completely okay — progress isn't always a straight line, "
            "and I'm here whenever you want to keep practicing.";
      case PostAssessmentCategory.improvedNoConcerns:
      case PostAssessmentCategory.improvedGad7Elevated:
      case PostAssessmentCategory.noChangeGad7Elevated:
      case PostAssessmentCategory.worsenedNotElevated:
      case PostAssessmentCategory.worsenedGad7Elevated:
        return "Your scores show real improvement since your last "
            "check-in. That's your effort paying off. Keep going, one "
            'scenario at a time!';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Text(
                _title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _blue,
                  fontSize: 24,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ColoredBox(
                color: const Color(0xFFF2F2F7),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: HatiSpriteAnimation(
                      size: 220,
                      message: _hatiMessage,
                      startDelay: Duration.zero,
                      persistBubble: true,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
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
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
