import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'assessment_complete_screen.dart';
import 'triggers_and_coping_screen.dart';
import 'low_score_exit_screen.dart';

// ─────────────────────────────────────────────
// Score Tier — drives every colour / copy decision
// ─────────────────────────────────────────────
enum _ScoreTier {
  flourishing, // ≤ 19
  growing, // ≤ 30
  developing, // ≤ 40   (does NOT qualify for app)
  supported, // ≤ 50   (qualifies)
  guided, // > 50   (qualifies)
}

class _TierTheme {
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color onSurface;
  final String badge;
  final String headline;
  final String subtitle;
  final IconData icon;

  const _TierTheme({
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.onSurface,
    required this.badge,
    required this.headline,
    required this.subtitle,
    required this.icon,
  });
}

// ─────────────────────────────────────────────
// Theme definitions — empathetic, never alarming
// ─────────────────────────────────────────────
const _themes = {
  _ScoreTier.flourishing: _TierTheme(
    primary: Color(0xFF0D9488), // teal-600
    secondary: Color(0xFF5EEAD4), // teal-300
    surface: Color(0xFFCCFBF1), // teal-100
    onSurface: Color(0xFF134E4A), // teal-900
    badge: 'Flourishing',
    headline: 'You\'re doing great!',
    subtitle:
        'You navigate social situations with ease. Keep building on your natural strengths.',
    icon: Icons.auto_awesome_rounded,
  ),
  _ScoreTier.growing: _TierTheme(
    primary: Color(0xFF0284C7), // sky-600
    secondary: Color(0xFF7DD3FC), // sky-300
    surface: Color(0xFFE0F2FE), // sky-100
    onSurface: Color(0xFF0C4A6E), // sky-900
    badge: 'Growing',
    headline: 'You\'re making progress!',
    subtitle:
        'You face some social challenges — that\'s completely human. You\'re already on the right path.',
    icon: Icons.trending_up_rounded,
  ),
  _ScoreTier.developing: _TierTheme(
    primary: Color(0xFF2563EB), // blue-600
    secondary: Color(0xFF93C5FD), // blue-300
    surface: Color(0xFFDBEAFE), // blue-100
    onSurface: Color(0xFF1E3A8A), // blue-900
    badge: 'Building Resilience',
    headline: 'You\'re building resilience',
    subtitle:
        'Moderate social challenges are more common than you think. You\'re not alone in this.',
    icon: Icons.shield_rounded,
  ),
  _ScoreTier.supported: _TierTheme(
    primary: Color(0xFF7C3AED), // violet-600
    secondary: Color(0xFFC4B5FD), // violet-300
    surface: Color(0xFFEDE9FE), // violet-100
    onSurface: Color(0xFF4C1D95), // violet-900
    badge: 'Ready to Grow',
    headline: 'You\'re in the right place',
    subtitle:
        'HATI was built exactly for moments like yours. Let\'s grow together — one step at a time.',
    icon: Icons.favorite_rounded,
  ),
  _ScoreTier.guided: _TierTheme(
    primary: Color(0xFF4F46E5), // indigo-600
    secondary: Color(0xFFA5B4FC), // indigo-300
    surface: Color(0xFFE0E7FF), // indigo-100
    onSurface: Color(0xFF312E81), // indigo-900
    badge: 'Your Journey Starts Here',
    headline: 'HATI is here for you',
    subtitle:
        'Social situations feel overwhelming sometimes — and that takes courage to acknowledge. This app was made with you in mind.',
    icon: Icons.handshake_rounded,
  ),
};

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
  bool _persisted = false;
  static const int _severeThreshold = 40;
  static const int _maxScore = 68; // SPIN max

  late AnimationController _animCtrl;
  late Animation<double> _arcAnim;
  late Animation<double> _fadeAnim;

  _ScoreTier get _tier {
    if (widget.score <= 19) return _ScoreTier.flourishing;
    if (widget.score <= 30) return _ScoreTier.growing;
    if (widget.score <= 40) return _ScoreTier.developing;
    if (widget.score <= 50) return _ScoreTier.supported;
    return _ScoreTier.guided;
  }

  bool get _qualifies => widget.score > _severeThreshold;

  @override
  void initState() {
    super.initState();
    _persistInitialSpinScore();

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

  // ── Firestore persistence (unchanged logic) ──────────────────
  Future<void> _persistInitialSpinScore() async {
    if (_persisted) return;
    _persisted = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    try {
      await userRef.collection('spinAssessments').doc('initial').set({
        'score': widget.score,
        'completedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await userRef.set({
        'initialSpinScore': widget.score,
        'initialSpinCompleted': true,
        'initialSpinCompletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
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
    final theme = _themes[_tier]!;
    final progress = (widget.score / _maxScore).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Hero header ─────────────────────────────────────
          _HeroHeader(
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
                      child: _BadgeChip(
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
                    _InfoCard(theme: theme, qualifies: _qualifies),
                    const SizedBox(height: 32),

                    // CTA button
                    _ContinueButton(
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

// ─────────────────────────────────────────────
// Hero Header with animated arc gauge
// ─────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final _TierTheme theme;
  final double progress;
  final Animation<double> arcAnim;
  final int score;

  const _HeroHeader({
    required this.theme,
    required this.progress,
    required this.arcAnim,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.primary, theme.primary.withOpacity(0.75)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            // App label
            Text(
              'HATI',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Assessment Complete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 28),

            // Arc gauge
            AnimatedBuilder(
              animation: arcAnim,
              builder: (_, __) => _ArcGauge(
                progress: progress * arcAnim.value,
                score: score,
                color: theme.secondary,
                trackColor: Colors.white.withOpacity(0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Arc Gauge painter
// ─────────────────────────────────────────────
class _ArcGauge extends StatelessWidget {
  final double progress;
  final int score;
  final Color color;
  final Color trackColor;

  const _ArcGauge({
    required this.progress,
    required this.score,
    required this.color,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: CustomPaint(
        painter: _ArcPainter(
          progress: progress,
          color: color,
          trackColor: trackColor,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              Text(
                '$score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Text(
                'out of 68',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _ArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const startAngle = math.pi * 0.75; // bottom-left
    const sweepTotal = math.pi * 1.5; // 270 °

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      trackPaint,
    );

    // Filled arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepTotal * progress,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────
// Badge chip
// ─────────────────────────────────────────────
class _BadgeChip extends StatelessWidget {
  final String label;
  final Color color;

  const _BadgeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Info card — qualifies vs does not
// ─────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final _TierTheme theme;
  final bool qualifies;

  const _InfoCard({required this.theme, required this.qualifies});

  @override
  Widget build(BuildContext context) {
    final body = qualifies
        ? 'Based on your results, HATI\'s scenario-based modules are tailored to support your growth in social situations. You\'ll work with Hati at your own pace — no pressure, just progress.'
        : 'Your results show you\'re managing social situations well right now. We\'re glad you checked in! You can revisit HATI anytime your needs change.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.secondary.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(theme.icon, color: theme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              body,
              style: TextStyle(
                color: theme.onSurface.withOpacity(0.85),
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CTA button
// ─────────────────────────────────────────────
class _ContinueButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  final String label;

  const _ContinueButton({
    required this.color,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
