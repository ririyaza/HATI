import 'package:flutter/material.dart';

import 'post_gad7_assessment_screen.dart';

/// Transition screen shown between the SPIN and GAD-7 portions of the
/// reassessment flow, so the topic switch (social anxiety -> general
/// anxiety) doesn't come as a surprise mid-quiz. Visually mirrors
/// `PostAssessmentIntroScreen` (same header/card/button styling) for
/// consistency with the rest of the flow.
class PostGad7IntroScreen extends StatelessWidget {
  const PostGad7IntroScreen({super.key, required this.spinTotal});

  final int spinTotal;

  static const _blue = Color(0xFF0B28D9);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              color: _blue,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: const Column(
                children: [
                  Text(
                    'HATI',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Part 2: General Anxiety",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _InfoCard(
                      icon: Icons.checklist_rounded,
                      title: "Nice work — first section done",
                      body:
                          "You've finished the social anxiety questions. "
                          "Next is a short, different set about general "
                          "anxiety — how you've been feeling day-to-day "
                          "over the past two weeks.",
                    ),
                    const SizedBox(height: 20),
                    const _FactRow(
                      icon: Icons.format_list_numbered_rounded,
                      text: 'Just 7 quick questions',
                    ),
                    const SizedBox(height: 12),
                    const _FactRow(
                      icon: Icons.timer_outlined,
                      text: 'Takes about 2 minutes',
                    ),
                    const SizedBox(height: 12),
                    const _FactRow(
                      icon: Icons.insights_rounded,
                      text: 'Continues your progress (18 of 24)',
                    ),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PostGad7AssessmentScreen(
                              spinTotal: spinTotal,
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This is not a diagnostic test. Your responses are used\n'
                      'only for research and personalization.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black38,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0B28D9), size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0B28D9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF333333),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFE8ECFF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF0B28D9), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
