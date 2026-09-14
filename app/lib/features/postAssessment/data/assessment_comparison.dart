import 'post_assessment_scoring.dart';

enum InstrumentComparisonResult { improved, noChange, worsened }

class InstrumentSnapshot {
  final int total;
  final String severity;

  const InstrumentSnapshot({required this.total, required this.severity});
}

/// GAD-7 total at or above this is "Elevated" (Moderate/Severe bands) —
/// the standard clinical cutoff (Spitzer et al.) for "probable GAD,
/// warrants further evaluation," and the threshold the thesis's
/// post-assessment category table is built on.
const gad7ElevatedThreshold = 10;

bool isGad7Elevated(int total) => total >= gad7ElevatedThreshold;

/// SPIN severities still considered clinically significant even after an
/// improvement — the 1.1-vs-1.2 split in the category table (its own
/// example: "from very severe to severe" is still 1.2, not 1.1).
const _significantSpinSeverities = {'Severe', 'Very Severe'};

bool isSpinStillSignificant(String severity) =>
    _significantSpinSeverities.contains(severity);

/// The 7 outcome categories from the thesis's post-assessment action table
/// (numbered there as 1.1, 1.2, 2, 3, 4, 5, 6), crossing the SPIN change
/// against current GAD-7 elevation. Each has its own suggested HATI
/// message, shown on [ProgressUpdateScreen] or [ReferralScreen].
enum PostAssessmentCategory {
  /// 1.1 — Improved, GAD-7 not elevated, SPIN no longer significant.
  improvedNoConcerns,

  /// 1.2 — Improved, GAD-7 not elevated, but SPIN still significant
  /// (e.g. very severe -> severe).
  improvedStillSignificant,

  /// 2 — SPIN improved, but GAD-7 is elevated.
  improvedGad7Elevated,

  /// 3 — No meaningful SPIN change, GAD-7 not elevated.
  noChangeNotElevated,

  /// 4 — No meaningful SPIN change, GAD-7 elevated.
  noChangeGad7Elevated,

  /// 5 — SPIN worsened, GAD-7 not elevated.
  worsenedNotElevated,

  /// 6 — SPIN worsened, GAD-7 elevated.
  worsenedGad7Elevated,
}

extension PostAssessmentCategoryRouting on PostAssessmentCategory {
  /// Whether this category's suggested action encourages professional
  /// support (-> [ReferralScreen] instead of [ProgressUpdateScreen]).
  /// Matches every row whose "Suggested HATI Action" mentions professional
  /// support: categories 2, 4, 5, and 6.
  bool get isReferral {
    switch (this) {
      case PostAssessmentCategory.improvedNoConcerns:
      case PostAssessmentCategory.improvedStillSignificant:
      case PostAssessmentCategory.noChangeNotElevated:
        return false;
      case PostAssessmentCategory.improvedGad7Elevated:
      case PostAssessmentCategory.noChangeGad7Elevated:
      case PostAssessmentCategory.worsenedNotElevated:
      case PostAssessmentCategory.worsenedGad7Elevated:
        return true;
    }
  }

  String get routedTo => isReferral ? 'referral' : 'progress';
}

class AssessmentComparisonResult {
  final InstrumentComparisonResult spinResult;

  /// Comparison against the previous GAD-7, kept only for the results
  /// screen's trend chart. NOT used to decide [category] — GAD-7 elevation
  /// is judged on the current score alone (see [gad7Elevated]), since
  /// there's often no previous GAD-7 to compare against (onboarding never
  /// administers it, so a user's first-ever reassessment has none).
  final InstrumentComparisonResult gad7Result;

  final bool gad7Elevated;
  final bool spinStillSignificant;
  final PostAssessmentCategory category;

  const AssessmentComparisonResult({
    required this.spinResult,
    required this.gad7Result,
    required this.gad7Elevated,
    required this.spinStillSignificant,
    required this.category,
  });

  bool get isReferral => category.isReferral;

  String get routedTo => category.routedTo;
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

PostAssessmentCategory _categorize({
  required InstrumentComparisonResult spinResult,
  required bool gad7Elevated,
  required bool spinStillSignificant,
}) {
  switch (spinResult) {
    case InstrumentComparisonResult.improved:
      if (gad7Elevated) return PostAssessmentCategory.improvedGad7Elevated;
      return spinStillSignificant
          ? PostAssessmentCategory.improvedStillSignificant
          : PostAssessmentCategory.improvedNoConcerns;
    case InstrumentComparisonResult.noChange:
      return gad7Elevated
          ? PostAssessmentCategory.noChangeGad7Elevated
          : PostAssessmentCategory.noChangeNotElevated;
    case InstrumentComparisonResult.worsened:
      return gad7Elevated
          ? PostAssessmentCategory.worsenedGad7Elevated
          : PostAssessmentCategory.worsenedNotElevated;
  }
}

/// Compares a new SPIN + GAD-7 pair against the most recent prior
/// assessment and categorizes the result per the thesis's post-assessment
/// action table. [previousGad7] may be null for a user's first-ever
/// reassessment, since onboarding only ever administers SPIN — in that
/// case [AssessmentComparisonResult.gad7Result] (chart-only) defaults to
/// `noChange`, but [AssessmentComparisonResult.gad7Elevated] is still
/// judged correctly, since it only ever needs the current score.
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

  final gad7Elevated = isGad7Elevated(currentGad7.total);
  final spinStillSignificant = isSpinStillSignificant(currentSpin.severity);

  return AssessmentComparisonResult(
    spinResult: spinResult,
    gad7Result: gad7Result,
    gad7Elevated: gad7Elevated,
    spinStillSignificant: spinStillSignificant,
    category: _categorize(
      spinResult: spinResult,
      gad7Elevated: gad7Elevated,
      spinStillSignificant: spinStillSignificant,
    ),
  );
}
