import 'package:cloud_firestore/cloud_firestore.dart';

import 'assessment_comparison.dart';
import 'post_assessment_scoring.dart';

/// How long after the last assessment (onboarding, or a previous
/// reassessment) before the next reassessment becomes due.
const reassessmentCooldown = Duration(days: 14);

class PriorAssessment {
  final DateTime administeredAt;
  final InstrumentSnapshot spin;

  /// Null when [administeredAt] is the onboarding baseline, since
  /// onboarding never administers GAD-7.
  final InstrumentSnapshot? gad7;

  const PriorAssessment({
    required this.administeredAt,
    required this.spin,
    this.gad7,
  });
}

/// Human-readable snapshot of where a user stands in the 14-day
/// reassessment cycle — built for display (e.g. a profile screen "days
/// until next check-in" card), separate from [PostAssessmentRepository
/// .isReassessmentDue]'s plain yes/no used by the dashboard banner.
class ReassessmentStatus {
  const ReassessmentStatus({
    required this.lastAssessedAt,
    required this.dueDate,
    required this.daysSinceLastAssessment,
    required this.daysUntilDue,
    required this.isDue,
    this.snoozedUntil,
  });

  final DateTime lastAssessedAt;
  final DateTime dueDate;

  /// Whole days since [lastAssessedAt]. Always >= 0.
  final int daysSinceLastAssessment;

  /// Whole days until [dueDate]. Zero or negative once due/overdue.
  final int daysUntilDue;

  /// Mirrors [PostAssessmentRepository.isReassessmentDue] (accounts for an
  /// active snooze), so a UI reading this doesn't also need a second call.
  final bool isDue;

  final DateTime? snoozedUntil;
}

class PostAssessmentRepository {
  PostAssessmentRepository._();

  static final _firestore = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _firestore.collection('users').doc(uid);

  static CollectionReference<Map<String, dynamic>> _reassessments(
    String uid,
  ) => _userRef(uid).collection('reassessments');

  /// The most recent prior assessment to compare against: the latest
  /// `reassessments` entry if one exists, otherwise the onboarding
  /// `spinAssessments/initial` baseline. Returns null only if neither
  /// exists (shouldn't happen in practice — onboarding is required before
  /// a user can reach this flow).
  static Future<PriorAssessment?> getBaseline(String uid) async {
    final latest = await _reassessments(
      uid,
    ).orderBy('administeredAt', descending: true).limit(1).get();

    if (latest.docs.isNotEmpty) {
      final data = latest.docs.first.data();
      final administeredAt = _date(data['administeredAt']);
      final spin = data['spin'];
      if (administeredAt != null && spin is Map) {
        final spinTotal = _nullableInt(spin['total']);
        final spinSeverityValue = spin['severity']?.toString();
        if (spinTotal != null && spinSeverityValue != null) {
          final gad7 = data['gad7'];
          InstrumentSnapshot? gad7Snapshot;
          if (gad7 is Map) {
            final gad7Total = _nullableInt(gad7['total']);
            final gad7SeverityValue = gad7['severity']?.toString();
            if (gad7Total != null && gad7SeverityValue != null) {
              gad7Snapshot = InstrumentSnapshot(
                total: gad7Total,
                severity: gad7SeverityValue,
              );
            }
          }
          return PriorAssessment(
            administeredAt: administeredAt,
            spin: InstrumentSnapshot(
              total: spinTotal,
              severity: spinSeverityValue,
            ),
            gad7: gad7Snapshot,
          );
        }
      }
    }

    final userDoc = await _userRef(uid).get();
    final userData = userDoc.data() ?? {};
    final initialDoc = await _userRef(
      uid,
    ).collection('spinAssessments').doc('initial').get();
    final initialData = initialDoc.data() ?? {};

    final initialScore = _nullableInt(
      initialData['score'] ?? userData['initialSpinScore'],
    );
    final initialDate = _date(
      initialData['completedAt'] ?? userData['initialSpinCompletedAt'],
    );
    if (initialScore == null || initialDate == null) return null;

    return PriorAssessment(
      administeredAt: initialDate,
      spin: InstrumentSnapshot(
        total: initialScore,
        severity: spinSeverity(initialScore),
      ),
    );
  }

  static Future<void> saveResult({
    required String uid,
    required InstrumentSnapshot spin,
    required InstrumentSnapshot gad7,
    required AssessmentComparisonResult comparison,
  }) async {
    final now = FieldValue.serverTimestamp();

    await _reassessments(uid).add({
      'type': 'reassessment',
      'administeredAt': now,
      'spin': {'total': spin.total, 'severity': spin.severity},
      'gad7': {'total': gad7.total, 'severity': gad7.severity},
      'comparison': {
        'spinResult': comparison.spinResult.name,
        'gad7Result': comparison.gad7Result.name,
        'overall': comparison.overall.name,
      },
      'routedTo': comparison.routedTo,
    });

    // Keep the existing dashboard's SPIN pre/post comparison
    // (dashboard_user_data.dart's _parseAssessments) working unmodified.
    await _userRef(uid).collection('spinAssessments').doc('post').set({
      'score': spin.total,
      'severity': spin.severity,
      'completedAt': now,
    }, SetOptions(merge: true));

    // A completed reassessment clears any snooze, so the *next* cooldown
    // window starts clean.
    await _userRef(uid).set({
      'reassessmentBannerSnoozedUntil': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  /// Whether the dashboard reassessment banner should show right now: due
  /// date has passed and the user hasn't snoozed it for today.
  static Future<bool> isReassessmentDue(String uid) async {
    final baseline = await getBaseline(uid);
    if (baseline == null) return false;

    final dueDate = baseline.administeredAt.add(reassessmentCooldown);
    if (DateTime.now().isBefore(dueDate)) return false;

    final userDoc = await _userRef(uid).get();
    final snoozedUntil = _date(
      userDoc.data()?['reassessmentBannerSnoozedUntil'],
    );
    if (snoozedUntil != null && DateTime.now().isBefore(snoozedUntil)) {
      return false;
    }

    return true;
  }

  /// Snapshot of the reassessment cycle for display — e.g. a profile
  /// screen's "next check-in in N days" card. Returns null if the user has
  /// no baseline at all (shouldn't happen once onboarding is complete).
  static Future<ReassessmentStatus?> getStatus(String uid) async {
    final baseline = await getBaseline(uid);
    if (baseline == null) return null;

    final dueDate = baseline.administeredAt.add(reassessmentCooldown);
    final now = DateTime.now();

    final userDoc = await _userRef(uid).get();
    final snoozedUntil = _date(
      userDoc.data()?['reassessmentBannerSnoozedUntil'],
    );
    final isSnoozed = snoozedUntil != null && now.isBefore(snoozedUntil);
    final isDue = !now.isBefore(dueDate) && !isSnoozed;

    return ReassessmentStatus(
      lastAssessedAt: baseline.administeredAt,
      dueDate: dueDate,
      daysSinceLastAssessment: now.difference(baseline.administeredAt).inDays,
      daysUntilDue: dueDate.difference(now).inDays,
      isDue: isDue,
      snoozedUntil: isSnoozed ? snoozedUntil : null,
    );
  }

  /// Hides the banner until the same time tomorrow.
  static Future<void> snoozeBannerOneDay(String uid) async {
    await _userRef(uid).set({
      'reassessmentBannerSnoozedUntil': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 1)),
      ),
    }, SetOptions(merge: true));
  }

  static int? _nullableInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }
}
