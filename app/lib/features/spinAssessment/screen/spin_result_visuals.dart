import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Visual pieces shared between [SpinResultScreen] (the live post-assessment
/// flow, whose CTA drives the user forward with side effects) and
/// [SpinResultReviewScreen] (a read-only revisit reached via "View Result" /
/// "Review Result" from the complete/exit screens) — kept in one place so
/// the two never drift apart in colour, copy, or layout.

// ─────────────────────────────────────────────
// Score Tier — drives every colour / copy decision
// ─────────────────────────────────────────────
enum SpinScoreTier {
  flourishing, // <= 19
  growing, // <= 30
  developing, // <= 40   (does NOT qualify for app)
  supported, // <= 50   (qualifies)
  guided, // > 50   (qualifies)
}

SpinScoreTier spinScoreTierFor(int score) {
  if (score <= 19) return SpinScoreTier.flourishing;
  if (score <= 30) return SpinScoreTier.growing;
  if (score <= 40) return SpinScoreTier.developing;
  if (score <= 50) return SpinScoreTier.supported;
  return SpinScoreTier.guided;
}

class SpinTierTheme {
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color onSurface;
  final String badge;
  final String headline;
  final String subtitle;
  final IconData icon;

  const SpinTierTheme({
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
const spinResultThemes = {
  SpinScoreTier.flourishing: SpinTierTheme(
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
  SpinScoreTier.growing: SpinTierTheme(
    primary: Color(0xFF0284C7), // sky-600
    secondary: Color(0xFF7DD3FC), // sky-300
    surface: Color(0xFFE0F2FE), // sky-100
    onSurface: Color(0xFF0C4A6E), // sky-900
    badge: 'Growing',
    headline: 'You\'re making progress!',
    subtitle:
        'You face some social challenges, and that\'s completely human. You\'re already on the right path.',
    icon: Icons.trending_up_rounded,
  ),
  SpinScoreTier.developing: SpinTierTheme(
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
  SpinScoreTier.supported: SpinTierTheme(
    primary: Color(0xFF7C3AED), // violet-600
    secondary: Color(0xFFC4B5FD), // violet-300
    surface: Color(0xFFEDE9FE), // violet-100
    onSurface: Color(0xFF4C1D95), // violet-900
    badge: 'Ready to Grow',
    headline: 'You\'re in the right place',
    subtitle:
        'HATI was built exactly for moments like yours. Let\'s grow together, one step at a time.',
    icon: Icons.favorite_rounded,
  ),
  SpinScoreTier.guided: SpinTierTheme(
    primary: Color(0xFF4F46E5), // indigo-600
    secondary: Color(0xFFA5B4FC), // indigo-300
    surface: Color(0xFFE0E7FF), // indigo-100
    onSurface: Color(0xFF312E81), // indigo-900
    badge: 'Your Journey Starts Here',
    headline: 'HATI is here for you',
    subtitle:
        'Social situations feel overwhelming sometimes, and admitting that takes courage. This app was made with you in mind.',
    icon: Icons.handshake_rounded,
  ),
};

// ─────────────────────────────────────────────
// Hero Header with animated arc gauge
// ─────────────────────────────────────────────
class SpinResultHeroHeader extends StatelessWidget {
  final SpinTierTheme theme;
  final double progress;
  final Animation<double> arcAnim;
  final int score;

  const SpinResultHeroHeader({
    super.key,
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
              builder: (_, _) => SpinResultArcGauge(
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
class SpinResultArcGauge extends StatelessWidget {
  final double progress;
  final int score;
  final Color color;
  final Color trackColor;

  const SpinResultArcGauge({
    super.key,
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
        painter: _SpinResultArcPainter(
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

class _SpinResultArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _SpinResultArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const startAngle = math.pi * 0.75; // bottom-left
    const sweepTotal = math.pi * 1.5; // 270 deg

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
  bool shouldRepaint(_SpinResultArcPainter old) =>
      old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────
// Badge chip
// ─────────────────────────────────────────────
class SpinResultBadgeChip extends StatelessWidget {
  final String label;
  final Color color;

  const SpinResultBadgeChip({super.key, required this.label, required this.color});

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
class SpinResultInfoCard extends StatelessWidget {
  final SpinTierTheme theme;
  final bool qualifies;

  const SpinResultInfoCard({super.key, required this.theme, required this.qualifies});

  @override
  Widget build(BuildContext context) {
    final body = qualifies
        ? 'Based on your results, HATI\'s scenario-based modules are tailored to support your growth in social situations. You\'ll work with Hati at your own pace, no pressure, just progress.'
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
// Pill action button
// ─────────────────────────────────────────────
class SpinResultActionButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  final String label;

  const SpinResultActionButton({
    super.key,
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
