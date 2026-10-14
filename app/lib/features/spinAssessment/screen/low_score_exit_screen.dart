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
import '../../../shared/widgets/textured_blue_background.dart';

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
      final completedAt = (doc.data()?['initialSpinCompletedAt'] as Timestamp?)
          ?.toDate();
      if (!mounted) return;
      setState(() {
        _retakeEligibleAt = completedAt != null
            ? spinRetakeEligibleAt(completedAt)
            : null;
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
      body: TexturedBlueBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  children: [
                    Text(
                      'HATI',
                      style: TextStyle(
                        color: AppColors.cream.withValues(alpha: 0.55),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'About Your Result',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.cream,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
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
                      // Dialogue still auto-advances on its own, but shows
                      // the usual pulsing "tap to continue" cue as a
                      // reminder that tapping anywhere skips ahead instead
                      // of waiting out the auto-advance timer.
                      showAdvanceCue: true,
                      onTypingComplete: () {
                        if (mounted) setState(() => _dialogueComplete = true);
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                    // The action buttons stay out of the tree entirely —
                    // not just disabled — until Hati's dialogue has fully
                    // finished typing, then pop in together. Previously
                    // they were always visible but disabled, which read as
                    // "broken" before the dialogue finished.
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.92, end: 1).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutBack,
                            ),
                          ),
                          child: child,
                        ),
                      ),
                      child: _dialogueComplete
                          ? Column(
                              key: const ValueKey('buttons'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (canRetake) ...[
                                  _PrimaryButton(
                                    label: 'Retake Assessment',
                                    onPressed: _handleRetake,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (canRetake)
                                  _OutlineButton(
                                    label: 'Exit the App',
                                    onPressed: () => SystemNavigator.pop(),
                                  )
                                else
                                  _PrimaryButton(
                                    label: 'Exit the App',
                                    onPressed: () => SystemNavigator.pop(),
                                  ),
                                const SizedBox(height: 12),
                                _OutlineButton(
                                  label: 'Review Result',
                                  onPressed: _handleReviewResult,
                                ),
                              ],
                            )
                          : const SizedBox.shrink(key: ValueKey('hidden')),
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

// Cream button with blue text — same CTA treatment as the consent intro.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cream,
          foregroundColor: AppColors.blue,
          disabledBackgroundColor: AppColors.cream.withValues(alpha: 0.35),
          disabledForegroundColor: AppColors.blue.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.cream,
          disabledForegroundColor: AppColors.cream.withValues(alpha: 0.4),
          side: BorderSide(
            color: AppColors.cream.withValues(
              alpha: onPressed == null ? 0.2 : 0.5,
            ),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
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
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDate(DateTime date) =>
      '${_months[date.month - 1]} ${date.day}, ${date.year}';

  @override
  Widget build(BuildContext context) {
    final String message;
    if (canRetake) {
      message =
          'It\'s been 14 days since your last check-in. You\'re '
          'welcome to retake the assessment whenever you\'re ready.';
    } else if (eligibleAt != null) {
      final daysLeft = eligibleAt!.difference(DateTime.now()).inHours / 24;
      final daysLeftRounded = daysLeft.ceil().clamp(1, 14);
      message =
          'You can retake this assessment in $daysLeftRounded '
          '${daysLeftRounded == 1 ? 'day' : 'days'} '
          '(on ${_formatDate(eligibleAt!)}).';
    } else {
      message = 'Come back later to retake this assessment.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cream.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.schedule_rounded, color: AppColors.cream, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.cream.withValues(alpha: 0.9),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
