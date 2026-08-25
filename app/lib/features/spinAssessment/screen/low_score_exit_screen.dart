import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../dashboard/widgets/hati_sprite_animation.dart';
import '../data/low_score_exit_hati_dialogue.dart';
import '../data/spin_retake_policy.dart';
import 'spin_assessment_screen.dart';
import 'spin_result_screen.dart';

class LowScoreExitScreen extends StatefulWidget {
  final int score;

  const LowScoreExitScreen({super.key, required this.score});

  @override
  State<LowScoreExitScreen> createState() => _LowScoreExitScreenState();
}

class _LowScoreExitScreenState extends State<LowScoreExitScreen> {
  bool _loadingEligibility = true;
  DateTime? _retakeEligibleAt;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final canRetake =
        _retakeEligibleAt != null && !now.isBefore(_retakeEligibleAt!);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Center(
                child: Text(
                  'About Your Result',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0056FF),
                    fontSize: 24,
                  ),
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
                      message: LowScoreExitHatiDialogue.message,
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
                          backgroundColor: const Color(0xFF0056FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        onPressed: _handleRetake,
                        child: const Text(
                          'Retake Assessment',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
                              side: const BorderSide(
                                color: Colors.black,
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                              backgroundColor: Colors.white,
                            ),
                            onPressed: () => SystemNavigator.pop(),
                            child: const Text(
                              'Exit the App',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          )
                        : FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0056FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            onPressed: () => SystemNavigator.pop(),
                            child: const Text(
                              'Exit the App',
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
                        side: const BorderSide(color: Colors.black, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SpinResultScreen(score: widget.score),
                          ),
                        );
                      },
                      child: const Text(
                        'Review Result',
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
      message = 'It\'s been 14 days since your last check-in — you\'re '
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
        color: const Color(0xFFF0F3FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.schedule_rounded, color: Color(0xFF0056FF), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1A1A2E),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
