import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../dashboard/widgets/hati_sprite_animation.dart';
import '../../onboarding/tutorial_screen.dart';
import '../../dashboard/screen/dashboard_screen.dart';
import '../data/assessment_complete_hati_dialogue.dart';
import 'spin_result_review_screen.dart';

/// Final confirmation screen after completing the SPIN assessment
/// and optional coping reflection.
class AssessmentCompleteScreen extends StatefulWidget {
  final int score;

  const AssessmentCompleteScreen({super.key, required this.score});

  @override
  State<AssessmentCompleteScreen> createState() =>
      _AssessmentCompleteScreenState();
}

class _AssessmentCompleteScreenState extends State<AssessmentCompleteScreen> {
  bool _isNavigatingToApp = false;
  bool _dialogueComplete = false;
  bool _hasReviewedResult = false;

  Future<void> _handleContinueToApp() async {
    if (_isNavigatingToApp) return;
    setState(() => _isNavigatingToApp = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        _goDashboard();
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? {};
      final tutorialDone = data['tutorialCompleted'] == true;

      if (!mounted) return;
      if (tutorialDone) {
        _goDashboard();
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute<void>(builder: (_) => const TutorialScreen()),
          (route) => false,
        );
      }
    } catch (_) {
      if (!mounted) return;
      _goDashboard();
    } finally {
      if (mounted) {
        setState(() => _isNavigatingToApp = false);
      }
    }
  }

  void _goDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  }

  Future<void> _handleViewResult() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SpinResultReviewScreen(score: widget.score),
      ),
    );
    if (!mounted) return;
    // Returning from the review: swap in the follow-up line and make Hati
    // "talk" again (re-gating the buttons until it finishes) instead of
    // silently repeating the same opening dialogue.
    setState(() {
      _hasReviewedResult = true;
      _dialogueComplete = false;
    });
  }

  static const _bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B28D9), Color(0xFF14184F)],
  );

  static Widget _texturedBackground({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(gradient: _bgGradient),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -40,
            child: _BackgroundBlob(size: 220, opacity: 0.14),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: _BackgroundBlob(size: 260, opacity: 0.10),
          ),
          Positioned(
            top: 180,
            left: -30,
            child: _BackgroundBlob(size: 120, opacity: 0.08),
          ),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: _texturedBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Text(
                'Assessment Complete',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                flex: 1,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: HatiSpriteAnimation(
                      // HatiSpeechSequence's bubble uses a hardcoded const
                      // key internally, so a message-only change wouldn't
                      // remount it or restart the typewriter — this key
                      // forces a clean remount when the dialogue should
                      // change (e.g. returning from View Result).
                      key: ValueKey(_hasReviewedResult),
                      size: 220,
                      message: _hasReviewedResult
                          ? AssessmentCompleteHatiDialogue.afterReviewMessage
                          : AssessmentCompleteHatiDialogue.message,
                      startDelay: Duration.zero,
                      persistBubble: true,
                      autoAdvance: true,
                      onTypingComplete: () {
                        if (mounted) setState(() => _dialogueComplete = true);
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        onPressed: (_dialogueComplete && !_isNavigatingToApp)
                            ? _handleContinueToApp
                            : null,
                        child: _isNavigatingToApp
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Continue to App',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
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
                          side: const BorderSide(
                            color: Colors.black,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          backgroundColor: Colors.white,
                        ),
                        onPressed: (_dialogueComplete && !_isNavigatingToApp)
                            ? _handleViewResult
                            : null,
                        child: const Text(
                          'View Result',
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
            ],
          ),
        ),
      ),
    );
  }
}

class _BackgroundBlob extends StatelessWidget {
  const _BackgroundBlob({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withValues(alpha: opacity),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
