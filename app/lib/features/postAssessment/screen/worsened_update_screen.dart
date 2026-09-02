import 'package:flutter/material.dart';

import '../../dashboard/widgets/hati_sprite_animation.dart';
import 'referral_screen.dart';

/// Shown when the reassessment comparison is `worsened`: acknowledges that
/// scores have gone up before moving on to `ReferralScreen`, so the referral
/// doesn't land on the user with zero context about why they're seeing it.
class WorsenedUpdateScreen extends StatelessWidget {
  const WorsenedUpdateScreen({super.key});

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
                'Your Check-in Results',
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
                          "Your scores show things have felt a bit harder "
                          "since your last check-in. That's nothing to be "
                          "ashamed of — let's find some support together.",
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
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const ReferralScreen()),
                    );
                  },
                  child: const Text(
                    'Continue',
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
