import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../dashboard/widgets/hati_sprite_animation.dart';
import '../data/low_score_exit_hati_dialogue.dart';
import '../data/spin_retake_policy.dart';
import 'spin_assessment_screen.dart';
import 'spin_result_review_screen.dart';
import '../../../shared/theme/app_colors.dart';

class LowScoreExitScreen extends StatefulWidget {
  final int score;

  const LowScoreExitScreen({super.key, required this.score});

  @override
  State<LowScoreExitScreen> createState() => _LowScoreExitScreenState();
}

class _LowScoreExitScreenState extends State<LowScoreExitScreen> {
  bool _loadingEligibility = true;
  DateTime? _retakeEligibleAt;
  bool _dialogueComplete = false;
  bool _hasReviewedResult = false;

  @override
  void initState() {
    super.initState();
    _loadRetakeEligibility();
  }

  Future<void> _loadRetakeEligibility() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingEligibility = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final completedAt =
          (doc.data()?['initialSpinCompletedAt'] as Timestamp?)?.toDate();
      if (!mounted) return;
      setState(() {
        _retakeEligibleAt =
            completedAt != null ? spinRetakeEligibleAt(completedAt) : null;
        _loadingEligibility = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingEligibility = false);
    }
  }

  void _handleRetake() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const SpinAssessmentScreen(isRetake: true),
      ),
    );
  }

  Future<void> _handleReviewResult() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final canRetake =
        _retakeEligibleAt != null && !now.isBefore(_retakeEligibleAt!);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Same blue header band as the assessment screens.
            Container(
              width: double.infinity,
              color: AppColors.blue,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  Text(
                    'HATI',
                    style: TextStyle(
                      color: AppColors.cream.withValues(alpha: 0.60),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'About Your Result',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.cream,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: AppColors.cream,
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
                      // change (e.g. returning from Review Result).
                      key: ValueKey(_hasReviewedResult),
                      size: 220,
                      message: _hasReviewedResult
                          ? LowScoreExitHatiDialogue.afterReviewMessage
                          : LowScoreExitHatiDialogue.message,
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_loadingEligibility) ...[
                    _RetakeStatusCard(
                      canRetake: canRetake,
                      eligibleAt: _retakeEligibleAt,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (canRetake) ...[
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        onPressed: _dialogueComplete ? _handleRetake : null,
                        child: const Text(
                          'Retake Assessment',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.cream,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    height: 52,
                    child: canRetake
                        ? OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.black12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                              backgroundColor: AppColors.cream,
                            ),
                            onPressed: _dialogueComplete
                                ? () => SystemNavigator.pop()
                                : null,
                            child: const Text(
                              'Exit the App',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          )
                        : FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            onPressed: _dialogueComplete
                                ? () => SystemNavigator.pop()
                                : null,
                            child: const Text(
                              'Exit the App',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: AppColors.cream,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        backgroundColor: AppColors.cream,
                      ),
                      onPressed:
                          _dialogueComplete ? _handleReviewResult : null,
                      child: const Text(
                        'Review Result',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
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

class _RetakeStatusCard extends StatelessWidget {
  final bool canRetake;
  final DateTime? eligibleAt;

  const _RetakeStatusCard({required this.canRetake, required this.eligibleAt});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(DateTime date) =>
      '${_months[date.month - 1]} ${date.day}, ${date.year}';

  @override
  Widget build(BuildContext context) {
    final String message;
    if (canRetake) {
      message = 'It\'s been 14 days since your last check-in. You\'re '
          'welcome to retake the assessment whenever you\'re ready.';
    } else if (eligibleAt != null) {
      final daysLeft = eligibleAt!.difference(DateTime.now()).inHours / 24;
      final daysLeftRounded = daysLeft.ceil().clamp(1, 14);
      message = 'You can retake this assessment in $daysLeftRounded '
          '${daysLeftRounded == 1 ? 'day' : 'days'} '
          '(on ${_formatDate(eligibleAt!)}).';
    } else {
      message = 'Come back later to retake this assessment.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.creamSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.creamLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.schedule_rounded, color: AppColors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.ink,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
