import 'package:flutter/material.dart';

import '../../dashboard/screen/dashboard_screen.dart';
import '../../dashboard/widgets/hati_sprite_animation.dart';

/// Shown when the reassessment comparison is `improved`: positive
/// reinforcement, then back to the dashboard (whose Progress tab already
/// reflects the new SPIN pre/post scores via `spinAssessments/post`).
class ProgressUpdateScreen extends StatelessWidget {
  const ProgressUpdateScreen({super.key});

  static const _blue = Color(0xFF0B28D9);

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
                "You're Making Progress!",
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
                      message:
                          "Your scores show real improvement since your "
                          "last check-in — that's your effort paying off. "
                          "Keep going, one scenario at a time!",
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
