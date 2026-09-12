import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/spin_scoring.dart';
import 'assessment_complete_screen.dart';
import 'spin_result_visuals.dart';
import 'triggers_and_coping_screen.dart';
import 'low_score_exit_screen.dart';

// ─────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────
class SpinResultScreen extends StatefulWidget {
  final int score;
  const SpinResultScreen({super.key, required this.score});

  @override
  State<SpinResultScreen> createState() => _SpinResultScreenState();
}

class _SpinResultScreenState extends State<SpinResultScreen>
    with SingleTickerProviderStateMixin {
  static const int _maxScore = 68; // SPIN max

  late AnimationController _animCtrl;
  late Animation<double> _arcAnim;
  late Animation<double> _fadeAnim;

  SpinScoreTier get _tier => spinScoreTierFor(widget.score);

  bool get _qualifies => spinQualifies(widget.score);

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

  Future<void> _onContinue() async {
    final user = FirebaseAuth.instance.currentUser;
    DocumentReference<Map<String, dynamic>>? userRef;

    if (user != null) {
      userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      try {
        await userRef.set({
          if (!_qualifies) 'accessBlocked': true,
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    if (!mounted) return;

    if (!_qualifies) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LowScoreExitScreen(score: widget.score),
        ),
      );
      return;
    }

    // Skip does not save coping — user can return to triggers. Continue with
    // input saves initialCopingMechanism and skips triggers on next visit.
    var hasSavedCoping = false;
    if (userRef != null) {
      try {
        final doc = await userRef.get();
        final data = doc.data() ?? {};
        final coping = data['initialCopingMechanism'];
        hasSavedCoping = coping is String && coping.trim().isNotEmpty;
      } catch (_) {}
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => hasSavedCoping
            ? AssessmentCompleteScreen(score: widget.score)
            : TriggersAndCopingScreen(score: widget.score),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = spinResultThemes[_tier]!;
    final progress = (widget.score / _maxScore).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Hero header ─────────────────────────────────────
          SpinResultHeroHeader(
            theme: theme,
            progress: progress,
            arcAnim: _arcAnim,
            score: widget.score,
          ),

          // ── Body content ────────────────────────────────────
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Badge chip
                    Align(
                      alignment: Alignment.center,
                      child: SpinResultBadgeChip(
                        label: theme.badge,
                        color: theme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Headline
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

                    // Subtitle interpretation
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

                    // Info card
                    SpinResultInfoCard(theme: theme, qualifies: _qualifies),
                    const SizedBox(height: 32),

                    // CTA button
                    SpinResultActionButton(
                      color: theme.primary,
                      onTap: _onContinue,
                      label: _qualifies ? 'Start My Journey' : 'See My Results',
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
