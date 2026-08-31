/// Clinical severity banding for the post-assessment (reassessment) flow.
///
/// Deliberately separate from `spinAssessment/data/spin_scoring.dart`
/// (`spinQualifies` / the onboarding `_ScoreTier`), which drive the
/// initial-access gate with different, non-clinical, friendlier bands.
/// Conflating the two would risk the reassessment result accidentally
/// re-triggering (or being read by) the onboarding gate logic.
library;

/// SPIN-17 total score, 0–68.
String spinSeverity(int total) {
  if (total <= 20) return 'None';
  if (total <= 30) return 'Mild';
  if (total <= 40) return 'Moderate';
  if (total <= 50) return 'Severe';
  return 'Very Severe';
}

/// GAD-7 total score, 0–21.
String gad7Severity(int total) {
  if (total <= 4) return 'Minimal';
  if (total <= 9) return 'Mild';
  if (total <= 14) return 'Moderate';
  return 'Severe';
}

/// Ordered worst→best per instrument, for detecting a severity-band drop
/// regardless of point magnitude.
const spinSeverityOrder = ['Very Severe', 'Severe', 'Moderate', 'Mild', 'None'];
const gad7SeverityOrder = ['Severe', 'Moderate', 'Mild', 'Minimal'];

/// True if [to] is a less severe band than [from], per the given order
/// (worst-to-best). Used to detect a "crossed into a lower band" drop.
bool _isLessSevere(List<String> order, String from, String to) {
  final fromIndex = order.indexOf(from);
  final toIndex = order.indexOf(to);
  return toIndex > fromIndex;
}

bool spinSeverityImproved(String from, String to) =>
    _isLessSevere(spinSeverityOrder, from, to);

bool gad7SeverityImproved(String from, String to) =>
    _isLessSevere(gad7SeverityOrder, from, to);
