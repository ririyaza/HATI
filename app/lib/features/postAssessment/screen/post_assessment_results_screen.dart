import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/assessment_comparison.dart';
import '../data/post_assessment_repository.dart';
import '../data/post_assessment_scoring.dart';
import 'progress_update_screen.dart';
import 'referral_screen.dart';
import 'worsened_update_screen.dart';

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
    switch (_comparison!.overall) {
      case InstrumentComparisonResult.improved:
        return "Great news — your scores show real improvement since your "
            'last check-in. Keep up the practice!';
      case InstrumentComparisonResult.noChange:
        return "Your scores are about the same as last time. That's "
            "completely okay — progress isn't always a straight line, and "
            'a little extra support can help.';
      case InstrumentComparisonResult.worsened:
        return 'Your scores show things have felt a bit harder lately. '
            "That's nothing to be ashamed of, and support is available "
            'whenever you need it.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _blue)),
      );
    }

    if (_error != null || _comparison == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error ?? 'Unable to load results.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ),
        ),
      );
    }

    final comparison = _comparison!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Check-in Complete',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              Center(child: _OverallBadge(overall: comparison.overall)),
              const SizedBox(height: 20),
              Text(
                _summarySentence,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
              _ResultCard(
                title: 'SPIN — Social Anxiety',
                maxScore: 68,
                current: _currentSpin,
                previous: _baseline?.spin,
                result: comparison.spinResult,
                color: _severityColor(_currentSpin.severity),
              ),
              const SizedBox(height: 16),
              _ResultCard(
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
                    backgroundColor: _blue,
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
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverallBadge extends StatelessWidget {
  const _OverallBadge({required this.overall});

  final InstrumentComparisonResult overall;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    switch (overall) {
      case InstrumentComparisonResult.improved:
        label = 'Improved';
        color = const Color(0xFF0D9488);
        break;
      case InstrumentComparisonResult.noChange:
        label = 'No Change';
        color = const Color(0xFF2563EB);
        break;
      case InstrumentComparisonResult.worsened:
        label = 'Needs Extra Support';
        color = const Color(0xFF7C3AED);
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

class _ResultCard extends StatelessWidget {
  const _ResultCard({
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${current.total}',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5, left: 4),
                child: Text(
                  '/ $maxScore',
                  style: const TextStyle(fontSize: 13, color: Colors.black45),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  current.severity,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (previous != null)
            Text(
              previous!.severity == current.severity
                  ? 'Previous: ${previous!.total} (${previous!.severity})'
                  : 'Previous: ${previous!.total} (${previous!.severity}) '
                        '→ Now: ${current.total} (${current.severity})',
              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
            )
          else if (noBaselineNote != null)
            Text(
              noBaselineNote!,
              style: const TextStyle(fontSize: 12.5, color: Colors.black45),
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
  switch (comparison.overall) {
    case InstrumentComparisonResult.improved:
      return const ProgressUpdateScreen();
    case InstrumentComparisonResult.noChange:
      return const ReferralScreen();
    case InstrumentComparisonResult.worsened:
      return const WorsenedUpdateScreen();
  }
}
