import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../dashboard/widgets/hati_sprite_animation.dart';
import '../../onboarding/tutorial_screen.dart';
import '../../dashboard/screen/dashboard_screen.dart';
import '../data/assessment_complete_hati_dialogue.dart';
import 'spin_result_screen.dart';

/// Final confirmation screen after completing the SPIN assessment
/// and optional coping reflection.
class AssessmentCompleteScreen extends StatefulWidget {
  final int score;

  const AssessmentCompleteScreen({
    super.key,
    required this.score,
  });

  @override
  State<AssessmentCompleteScreen> createState() =>
      _AssessmentCompleteScreenState();
}

class _AssessmentCompleteScreenState extends State<AssessmentCompleteScreen> {
  bool _isNavigatingToApp = false;

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
          MaterialPageRoute<void>(
            builder: (_) => const TutorialScreen(),
          ),
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
      MaterialPageRoute<void>(
        builder: (_) => const DashboardScreen(),
      ),
      (route) => false,
    );
  }

  void _handleViewResult() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SpinResultScreen(score: widget.score),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'Assessment Complete',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF007AFF),
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              flex: 1,
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
                      message: AssessmentCompleteHatiDialogue.message,
                      startDelay: Duration.zero,
                      persistBubble: true,
                    ),
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
                      onPressed: _isNavigatingToApp ? null : _handleContinueToApp,
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
                        side: const BorderSide(color: Colors.black, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      onPressed:
                          _isNavigatingToApp ? null : _handleViewResult,
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
    );
  }
}
