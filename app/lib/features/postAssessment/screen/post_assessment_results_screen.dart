import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/assessment_comparison.dart';
import '../data/post_assessment_repository.dart';
import '../data/post_assessment_scoring.dart';
import '../data/reassessment_notification_service.dart';
import 'progress_update_screen.dart';
import 'referral_screen.dart';

class PostAssessmentResultsScreen extends StatefulWidget {
  const PostAssessmentResultsScreen({
    super.key,
    required this.spinTotal,
    required this.gad7Total,
  });

  final int spinTotal;
  final int gad7Total;

  @override
  State<PostAssessmentResultsScreen> createState() =>
      _PostAssessmentResultsScreenState();
}

class _PostAssessmentResultsScreenState
    extends State<PostAssessmentResultsScreen> {
  static const _blue = Color(0xFF0B28D9);

  bool _loading = true;
  String? _error;
  PriorAssessment? _baseline;
  AssessmentComparisonResult? _comparison;
  late final InstrumentSnapshot _currentSpin;
  late final InstrumentSnapshot _currentGad7;

  @override
  void initState() {
    super.initState();
    _currentSpin = InstrumentSnapshot(
      total: widget.spinTotal,
      severity: spinSeverity(widget.spinTotal),
    );
    _currentGad7 = InstrumentSnapshot(
      total: widget.gad7Total,
      severity: gad7Severity(widget.gad7Total),
    );
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'You need to be signed in to see your results.';
      });
      return;
    }

    try {
      final baseline = await PostAssessmentRepository.getBaseline(user.uid);
      final comparison = compareAssessments(
        // Falls back to comparing the new score against itself (=> noChange
        // => referral) in the never-expected case where no baseline exists
        // at all, rather than crashing.
        previousSpin: baseline?.spin ?? _currentSpin,
        currentSpin: _currentSpin,
        currentGad7: _currentGad7,
        previousGad7: baseline?.gad7,
      );

      await PostAssessmentRepository.saveResult(
        uid: user.uid,
        spin: _currentSpin,
        gad7: _currentGad7,
        comparison: comparison,
      );

      // Reschedule the on-device reminder for the new due date. Best-effort
      // — a failure here shouldn't turn a successfully-saved result into an
      // error screen.
      try {
        await ReassessmentNotificationService.sync(user.uid);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _baseline = baseline;
        _comparison = comparison;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong saving your results. Please try again.';
      });
    }
  }

  void _continue() {
    final comparison = _comparison;
    if (comparison == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextScreenForComparison(comparison)),
    );
  }

  static Color _severityColor(String severity) {
    switch (severity) {
      case 'None':
      case 'Minimal':
        return const Color(0xFF0D9488);
      case 'Mild':
        return const Color(0xFF0284C7);
      case 'Moderate':
        return const Color(0xFF2563EB);
      case 'Severe':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFFDC2626);
    }
  }

  String get _summarySentence {
    switch (_comparison!.category) {
      case PostAssessmentCategory.improvedNoConcerns:
        return "Great news, your scores show real improvement since your "
            'last check-in. Keep up the practice!';
      case PostAssessmentCategory.improvedStillSignificant:
        return 'Your SPIN score has improved. Your results still show '
            'significant symptoms though, so keep at it.';
      case PostAssessmentCategory.improvedGad7Elevated:
        return 'Your SPIN score has improved, which is great progress. '
            "Your GAD-7 result today points to another area worth "
            'attention, though — reaching out to a mental health '
            'professional could help.';
      case PostAssessmentCategory.noChangeNotElevated:
        return "Your scores are about the same as last time. That's "
            "completely okay. Progress isn't always a straight line.";
      case PostAssessmentCategory.noChangeGad7Elevated:
        return "Your SPIN score hasn't changed much since last time, and "
            'your GAD-7 result today is elevated. It may help to talk to '
            'a mental health professional.';
      case PostAssessmentCategory.worsenedNotElevated:
        return 'Your SPIN score has gone up since your last check-in. '
            "That's nothing to be ashamed of, and reaching out to a "
            'mental health professional could help.';
      case PostAssessmentCategory.worsenedGad7Elevated:
        return 'Your SPIN score has gone up, and your GAD-7 result today '
            "is elevated too. We'd strongly encourage reaching out to a "
            'qualified mental health professional for support.';
    }
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
    if (_loading) {
      return Scaffold(
        body: _texturedBackground(
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    if (_error != null || _comparison == null) {
      return Scaffold(
        body: _texturedBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _error ?? 'Unable to load results.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
        ),
      );
    }

    final comparison = _comparison!;

    return Scaffold(
      body: _texturedBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: _blue.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Check-in Complete',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(child: _OverallBadge(category: comparison.category)),
                      const SizedBox(height: 18),
                      Text(
                        _summarySentence,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _ComparisonChartCard(
                  title: 'SPIN — Social Anxiety',
                  maxScore: 68,
                  current: _currentSpin,
                  previous: _baseline?.spin,
                  result: comparison.spinResult,
                  color: _severityColor(_currentSpin.severity),
                ),
                const SizedBox(height: 16),
                _ComparisonChartCard(
                  title: 'GAD-7 — General Anxiety',
                  maxScore: 21,
                  current: _currentGad7,
                  previous: _baseline?.gad7,
                  result: comparison.gad7Result,
                  color: _severityColor(_currentGad7.severity),
                  noBaselineNote:
                      _baseline?.gad7 == null
                          ? "This is your first GAD-7 check-in, so there's "
                              'nothing to compare it to yet.'
                          : null,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    onPressed: _continue,
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _blue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft blurred circle used to give the blue page background some depth and
/// texture instead of a flat fill.
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

class _OverallBadge extends StatelessWidget {
  const _OverallBadge({required this.category});

  final PostAssessmentCategory category;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    switch (category) {
      case PostAssessmentCategory.improvedNoConcerns:
      case PostAssessmentCategory.improvedStillSignificant:
        label = 'Improved';
        color = const Color(0xFF0D9488);
        break;
      case PostAssessmentCategory.improvedGad7Elevated:
      case PostAssessmentCategory.noChangeGad7Elevated:
        label = 'Needs Attention';
        color = const Color(0xFFFF9500);
        break;
      case PostAssessmentCategory.noChangeNotElevated:
        label = 'No Change';
        color = const Color(0xFF2563EB);
        break;
      case PostAssessmentCategory.worsenedNotElevated:
        label = 'Needs Extra Support';
        color = const Color(0xFF7C3AED);
        break;
      case PostAssessmentCategory.worsenedGad7Elevated:
        label = 'Needs Extra Support';
        color = const Color(0xFFDC2626);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

/// A card comparing the previous and current score for one instrument as a
/// grouped bar chart, so the size of the change is visible at a glance
/// rather than only readable as two numbers in a sentence.
class _ComparisonChartCard extends StatelessWidget {
  const _ComparisonChartCard({
    required this.title,
    required this.maxScore,
    required this.current,
    required this.previous,
    required this.result,
    required this.color,
    this.noBaselineNote,
  });

  final String title;
  final int maxScore;
  final InstrumentSnapshot current;
  final InstrumentSnapshot? previous;
  final InstrumentComparisonResult result;
  final Color color;
  final String? noBaselineNote;

  static const _barAreaHeight = 110.0;
  static const _previousColor = Color(0xFFC7CCE3);

  double _barHeight(int value) {
    final fraction = (value / maxScore).clamp(0.0, 1.0);
    return (_barAreaHeight * fraction).clamp(6.0, _barAreaHeight);
  }

  @override
  Widget build(BuildContext context) {
    final previous = this.previous;
    final delta = previous == null ? null : current.total - previous.total;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              if (delta != null) _DeltaChip(delta: delta, result: result),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'out of $maxScore',
            style: const TextStyle(fontSize: 11.5, color: Colors.black38),
          ),
          const SizedBox(height: 18),
          if (previous == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  _Bar(
                    label: 'Now',
                    value: current.total,
                    severity: current.severity,
                    barColor: color,
                    barHeight: _barHeight(current.total),
                    areaHeight: _barAreaHeight,
                  ),
                  const SizedBox(width: 20),
                  if (noBaselineNote != null)
                    Expanded(
                      child: Text(
                        noBaselineNote!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.black45,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Bar(
                  label: 'Previous',
                  value: previous.total,
                  severity: previous.severity,
                  barColor: _previousColor,
                  barHeight: _barHeight(previous.total),
                  areaHeight: _barAreaHeight,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 34),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: color.withValues(alpha: 0.45),
                    size: 22,
                  ),
                ),
                _Bar(
                  label: 'Now',
                  value: current.total,
                  severity: current.severity,
                  barColor: color,
                  barHeight: _barHeight(current.total),
                  areaHeight: _barAreaHeight,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// One labeled bar within a [_ComparisonChartCard].
class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.severity,
    required this.barColor,
    required this.barHeight,
    required this.areaHeight,
  });

  final String label;
  final int value;
  final String severity;
  final Color barColor;
  final double barHeight;
  final double areaHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: areaHeight,
          width: 52,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: barHeight,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                  bottom: Radius.circular(4),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [barColor, barColor.withValues(alpha: 0.7)],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: barColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            severity,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: barColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Small "+N" / "-N" pill summarizing the point change, colored by whether
/// that change counts as improved / no change / worsened.
class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.delta, required this.result});

  final int delta;
  final InstrumentComparisonResult result;

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (result) {
      case InstrumentComparisonResult.improved:
        color = const Color(0xFF0D9488);
        break;
      case InstrumentComparisonResult.noChange:
        color = const Color(0xFF2563EB);
        break;
      case InstrumentComparisonResult.worsened:
        color = const Color(0xFF7C3AED);
        break;
    }

    final sign = delta > 0 ? '+' : '';
    final icon = delta > 0
        ? Icons.arrow_upward_rounded
        : delta < 0
        ? Icons.arrow_downward_rounded
        : Icons.remove_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            '$sign$delta',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pure branch-routing decision, pulled out of the screen's build/navigation
/// code so it can be unit-tested directly without needing to pump a full
/// widget tree or mock Firebase.
Widget nextScreenForComparison(AssessmentComparisonResult comparison) {
  return comparison.isReferral
      ? ReferralScreen(category: comparison.category)
      : ProgressUpdateScreen(category: comparison.category);
}
