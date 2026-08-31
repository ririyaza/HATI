import 'post_assessment_scoring.dart';

enum InstrumentComparisonResult { improved, noChange, worsened }

class InstrumentSnapshot {
  final int total;
  final String severity;

  const InstrumentSnapshot({required this.total, required this.severity});
}

class AssessmentComparisonResult {
  final InstrumentComparisonResult spinResult;
  final InstrumentComparisonResult gad7Result;
  final InstrumentComparisonResult overall;

  const AssessmentComparisonResult({
    required this.spinResult,
    required this.gad7Result,
    required this.overall,
  });

  bool get isReferral => overall != InstrumentComparisonResult.improved;

  String get routedTo => isReferral ? 'referral' : 'progress';
}

/// Per-instrument improvement rule:
/// - Score increased -> worsened.
/// - Score unchanged -> noChange.
/// - Score decreased:
///   - crosses into a less-severe band -> improved, regardless of magnitude.
///   - drops by 2+ points without a band change -> improved.
///   - drops by exactly 1 point without a band change -> noChange (a trivial
///     fluctuation, not treated as meaningful per the thesis's own note).
InstrumentComparisonResult _compareInstrument({
  required int previousTotal,
  required int currentTotal,
  required String previousSeverity,
  required String currentSeverity,
  required bool Function(String from, String to) severityImprovedFn,
}) {
  final delta = currentTotal - previousTotal;
  if (delta > 0) return InstrumentComparisonResult.worsened;
  if (delta == 0) return InstrumentComparisonResult.noChange;

  if (severityImprovedFn(previousSeverity, currentSeverity)) {
    return InstrumentComparisonResult.improved;
  }
  return delta <= -2
      ? InstrumentComparisonResult.improved
      : InstrumentComparisonResult.noChange;
}

InstrumentComparisonResult _combine(
  InstrumentComparisonResult a,
  InstrumentComparisonResult b,
) {
  if (a == InstrumentComparisonResult.worsened ||
      b == InstrumentComparisonResult.worsened) {
    return InstrumentComparisonResult.worsened;
  }
  if (a == InstrumentComparisonResult.noChange ||
      b == InstrumentComparisonResult.noChange) {
    return InstrumentComparisonResult.noChange;
  }
  return InstrumentComparisonResult.improved;
}

/// Compares a new SPIN + GAD-7 pair against the most recent prior
/// assessment. [previousGad7] may be null for a user's first-ever
/// reassessment, since onboarding only ever administers SPIN — in that case
/// the GAD-7 side contributes `noChange` (neutral: it can't suppress a SPIN
/// worsening via the "either worsened wins" rule, but it also can't force a
/// referral purely from having no history to compare against).
AssessmentComparisonResult compareAssessments({
  required InstrumentSnapshot previousSpin,
  required InstrumentSnapshot currentSpin,
  required InstrumentSnapshot currentGad7,
  InstrumentSnapshot? previousGad7,
}) {
  final spinResult = _compareInstrument(
    previousTotal: previousSpin.total,
    currentTotal: currentSpin.total,
    previousSeverity: previousSpin.severity,
    currentSeverity: currentSpin.severity,
    severityImprovedFn: spinSeverityImproved,
  );

  final gad7Result = previousGad7 == null
      ? InstrumentComparisonResult.noChange
      : _compareInstrument(
          previousTotal: previousGad7.total,
          currentTotal: currentGad7.total,
          previousSeverity: previousGad7.severity,
          currentSeverity: currentGad7.severity,
          severityImprovedFn: gad7SeverityImproved,
        );

  return AssessmentComparisonResult(
    spinResult: spinResult,
    gad7Result: gad7Result,
    overall: _combine(spinResult, gad7Result),
  );
}
