import 'package:flutter/material.dart';

import '../data/spin_scoring.dart';
import 'spin_result_visuals.dart';

/// Read-only revisit of the SPIN result, reached via "View Result" /
/// "Review Result" from [AssessmentCompleteScreen] or [LowScoreExitScreen].
///
/// Pushed on top of whichever screen opened it (rather than replacing it
/// the way the live [SpinResultScreen] does), so a back button returns the
/// user to that screen instead of re-running the assessment flow's own CTA
/// — which has side effects (saving `accessBlocked`, advancing into coping
/// input or the tutorial) that must never fire again on a mere revisit.
class SpinResultReviewScreen extends StatefulWidget {
  final int score;
  const SpinResultReviewScreen({super.key, required this.score});

  @override
  State<SpinResultReviewScreen> createState() =>
      _SpinResultReviewScreenState();
}

class _SpinResultReviewScreenState extends State<SpinResultReviewScreen>
    with SingleTickerProviderStateMixin {
  static const int _maxScore = 68; // SPIN max

  late final AnimationController _animCtrl;
  late final Animation<double> _arcAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _arcAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = spinScoreTierFor(widget.score);
    final theme = spinResultThemes[tier]!;
    final progress = (widget.score / _maxScore).clamp(0.0, 1.0);
    final qualifies = spinQualifies(widget.score);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Stack(
            children: [
              SpinResultHeroHeader(
                theme: theme,
                progress: progress,
                arcAnim: _arcAnim,
                score: widget.score,
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                child: _BackButton(onTap: () => Navigator.of(context).pop()),
              ),
            ],
          ),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: SpinResultBadgeChip(
                        label: theme.badge,
                        color: theme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      theme.headline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: theme.onSurface,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      theme.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF64748B),
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SpinResultInfoCard(theme: theme, qualifies: qualifies),
                    const SizedBox(height: 32),
                    SpinResultActionButton(
                      color: theme.primary,
                      onTap: () => Navigator.of(context).pop(),
                      label: 'Back',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
