import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../postAssessment/data/post_assessment_scoring.dart';
import '../../spinAssessment/screen/spin_result_review_screen.dart';
import '../../spinAssessment/screen/spin_result_visuals.dart';
import 'profile_stat_detail_screen.dart' show formatShortDate;

/// Full breakdown of the user's assessment results, opened by tapping the
/// SPIN card under "Assessment Scores" on the Profile tab.
///
/// Reads the same documents the rest of the app writes:
///  - `spinAssessments/initial` — onboarding SPIN total plus the per-theme
///    breakdown (`themeAverages`) and `priorityScenario` that
///    spin_assessment_screen.dart saves.
///  - `reassessments/*` — every 2-week check-in (SPIN + GAD-7), saved by
///    [PostAssessmentRepository.saveResult].
class AssessmentResultDetailScreen extends StatefulWidget {
  const AssessmentResultDetailScreen({super.key, required this.uid});

  final String uid;

  @override
  State<AssessmentResultDetailScreen> createState() =>
      _AssessmentResultDetailScreenState();
}

class _AssessmentResultDetailScreenState
    extends State<AssessmentResultDetailScreen> {
  static const _spinMax = 68;
  static const _gad7Max = 21;

  late final Future<_AssessmentDetails> _future = _load();

  Future<_AssessmentDetails> _load() async {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid);
    final results = await Future.wait([
      userRef.get(),
      userRef.collection('spinAssessments').doc('initial').get(),
      userRef
          .collection('reassessments')
          .orderBy('administeredAt', descending: true)
          .get(),
    ]);
    final userData =
        (results[0] as DocumentSnapshot<Map<String, dynamic>>).data() ?? {};
    final initial =
        (results[1] as DocumentSnapshot<Map<String, dynamic>>).data() ?? {};
    final reassessmentDocs =
        (results[2] as QuerySnapshot<Map<String, dynamic>>).docs;

    final themeAverages = <String, double>{};
    final rawAverages = initial['themeAverages'];
    if (rawAverages is Map) {
      for (final entry in rawAverages.entries) {
        final value = entry.value;
        if (value is num) {
          themeAverages[entry.key.toString()] = value.toDouble();
        }
      }
    }

    final checkIns = <_CheckIn>[];
    for (final doc in reassessmentDocs) {
      final data = doc.data();
      final date = _date(data['administeredAt']);
      final spin = data['spin'];
      final spinTotal = spin is Map ? _int(spin['total']) : null;
      if (date == null || spinTotal == null) continue;
      final gad7 = data['gad7'];
      checkIns.add(
        _CheckIn(
          date: date,
          spinTotal: spinTotal,
          spinSeverity:
              (spin as Map)['severity']?.toString() ?? spinSeverity(spinTotal),
          gad7Total: gad7 is Map ? _int(gad7['total']) : null,
          gad7Severity: gad7 is Map ? gad7['severity']?.toString() : null,
        ),
      );
    }

    return _AssessmentDetails(
      initialScore: _int(initial['score'] ?? userData['initialSpinScore']),
      initialDate: _date(
        initial['completedAt'] ?? userData['initialSpinCompletedAt'],
      ),
      themeAverages: themeAverages,
      priorityTheme: initial['priorityScenario']?.toString() ?? '',
      checkIns: checkIns,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.blue,
        foregroundColor: AppColors.cream,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        title: const Text(
          'Assessment Results',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<_AssessmentDetails>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.blue),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text(
                'Unable to load your assessment results.',
                style: TextStyle(color: Colors.black54),
              ),
            );
          }
          final details = snapshot.data!;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              24 + MediaQuery.of(context).padding.bottom,
            ),
            children: [
              if (details.initialScore != null)
                _InitialResultCard(
                  score: details.initialScore!,
                  maxScore: _spinMax,
                  date: details.initialDate,
                )
              else
                const _Card(
                  child: Text(
                    'No initial SPIN result has been recorded yet.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              if (details.themeAverages.isNotEmpty) ...[
                const _SectionLabel('What the SPIN measured'),
                const _Hint(
                  'How strongly each area showed up in your answers. '
                  'Higher means it affects you more.',
                ),
                _Card(
                  child: Column(
                    children: [
                      for (final (i, entry) in details.sortedThemes.indexed)
                        _ThemeBar(
                          rank: i + 1,
                          label: _themeLabel(entry.key),
                          percent: entry.value,
                          isFocus: entry.key == details.priorityTheme,
                        ),
                      const SizedBox(height: 6),
                      const _ThemeLegend(),
                    ],
                  ),
                ),
                if (details.priorityTheme.isNotEmpty)
                  _FocusCard(theme: _themeLabel(details.priorityTheme)),
              ],
              const _SectionLabel('2-Week Check-ins'),
              if (details.checkIns.isEmpty)
                const _Card(
                  child: Text(
                    "You haven't completed a check-in yet. It becomes "
                    'available 2 weeks after your last assessment.',
                    style: TextStyle(color: Colors.black54, height: 1.45),
                  ),
                )
              else
                for (var i = 0; i < details.checkIns.length; i++)
                  _CheckInCard(
                    checkIn: details.checkIns[i],
                    // Compare against the check-in before it, or the
                    // onboarding result for the very first one.
                    previousSpin: i + 1 < details.checkIns.length
                        ? details.checkIns[i + 1].spinTotal
                        : details.initialScore,
                    previousGad7: i + 1 < details.checkIns.length
                        ? details.checkIns[i + 1].gad7Total
                        : null,
                    spinMax: _spinMax,
                    gad7Max: _gad7Max,
                  ),
              const SizedBox(height: 8),
              const _Hint(
                'These results are a self-check, not a diagnosis. If you '
                'feel you need support, reach out to a professional or use '
                'the resources in Help & Support.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AssessmentDetails {
  const _AssessmentDetails({
    required this.initialScore,
    required this.initialDate,
    required this.themeAverages,
    required this.priorityTheme,
    required this.checkIns,
  });

  final int? initialScore;
  final DateTime? initialDate;
  final Map<String, double> themeAverages;
  final String priorityTheme;

  /// Newest first.
  final List<_CheckIn> checkIns;

  List<MapEntry<String, double>> get sortedThemes =>
      themeAverages.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
}

class _CheckIn {
  const _CheckIn({
    required this.date,
    required this.spinTotal,
    required this.spinSeverity,
    required this.gad7Total,
    required this.gad7Severity,
  });

  final DateTime date;
  final int spinTotal;
  final String spinSeverity;
  final int? gad7Total;
  final String? gad7Severity;
}

class _InitialResultCard extends StatelessWidget {
  const _InitialResultCard({
    required this.score,
    required this.maxScore,
    required this.date,
  });

  final int score;
  final int maxScore;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final theme = spinResultThemes[spinScoreTierFor(score)]!;
    final severity = spinSeverity(score);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(theme.icon, color: theme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Initial SPIN Assessment',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      date == null
                          ? 'Date not recorded'
                          : 'Taken ${formatShortDate(date!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: theme.primary,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Text(
                  '/$maxScore',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black38,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              _Pill(label: '$severity symptoms', color: theme.primary),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (score / maxScore).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: theme.primary.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            theme.headline,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: theme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            theme.subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.black54,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SpinResultReviewScreen(score: score),
                ),
              ),
              icon: const Icon(Icons.open_in_full_rounded, size: 16),
              label: const Text('View full result'),
              style: TextButton.styleFrom(foregroundColor: AppColors.blue),
            ),
          ),
        ],
      ),
    );
  }
}

/// How strongly a theme showed up, banded into three calm levels. Kept
/// deliberately free of red/alarm colors — a strong theme is something to
/// work on, not a warning.
enum _ThemeLevel {
  mild('Mild', Color(0xFF3BA99C), Color(0xFF8FD6CB)),
  moderate('Moderate', Color(0xFFD99A2B), Color(0xFFF3CF85)),
  strong('Strong', Color(0xFF6B4FD8), Color(0xFFB3A2F0));

  const _ThemeLevel(this.label, this.color, this.light);

  final String label;
  final Color color;

  /// Lighter start of the bar's gradient.
  final Color light;

  static _ThemeLevel of(double percent) {
    if (percent >= 75) return strong;
    if (percent >= 45) return moderate;
    return mild;
  }
}

class _ThemeBar extends StatelessWidget {
  const _ThemeBar({
    required this.rank,
    required this.label,
    required this.percent,
    required this.isFocus,
  });

  final int rank;
  final String label;
  final double percent;
  final bool isFocus;

  @override
  Widget build(BuildContext context) {
    final level = _ThemeLevel.of(percent);
    final value = (percent / 100).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 12),
      decoration: BoxDecoration(
        color: isFocus ? AppColors.blueTint : AppColors.creamSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFocus
              ? AppColors.blue.withValues(alpha: 0.35)
              : AppColors.creamLine.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: level.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: isFocus
                    ? Icon(Icons.star_rounded, size: 15, color: level.color)
                    : Text(
                        '$rank',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: level.color,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isFocus ? FontWeight.w800 : FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: level.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  level.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: level.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value),
                  duration: Duration(milliseconds: 700 + rank * 120),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => _GradientBar(
                    value: v,
                    start: level.light,
                    end: level.color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 38,
                child: Text(
                  '${percent.round()}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A soft, fully-rounded track with a gradient fill and a small glow,
/// replacing the flat LinearProgressIndicator.
class _GradientBar extends StatelessWidget {
  const _GradientBar({
    required this.value,
    required this.start,
    required this.end,
  });

  final double value;
  final Color start;
  final Color end;

  static const double _height = 12;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: AppColors.creamDeep,
        borderRadius: BorderRadius.circular(_height),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value,
          heightFactor: 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [start, end]),
              borderRadius: BorderRadius.circular(_height),
              boxShadow: [
                BoxShadow(
                  color: end.withValues(alpha: 0.30),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeLegend extends StatelessWidget {
  const _ThemeLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (final level in _ThemeLevel.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [level.light, level.color]),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                level.label,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
      ],
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.theme});

  final String theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: AppColors.cream, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your focus area',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.cream.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  theme,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.cream,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({
    required this.checkIn,
    required this.previousSpin,
    required this.previousGad7,
    required this.spinMax,
    required this.gad7Max,
  });

  final _CheckIn checkIn;
  final int? previousSpin;
  final int? previousGad7;
  final int spinMax;
  final int gad7Max;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_available_rounded,
                size: 18,
                color: AppColors.blue,
              ),
              const SizedBox(width: 8),
              Text(
                formatShortDate(checkIn.date),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InstrumentRow(
            name: 'SPIN',
            total: checkIn.spinTotal,
            max: spinMax,
            severity: checkIn.spinSeverity,
            previous: previousSpin,
          ),
          if (checkIn.gad7Total != null) ...[
            const Divider(height: 20, color: AppColors.creamLine),
            _InstrumentRow(
              name: 'GAD-7',
              total: checkIn.gad7Total!,
              max: gad7Max,
              severity:
                  checkIn.gad7Severity ?? gad7Severity(checkIn.gad7Total!),
              previous: previousGad7,
            ),
          ],
        ],
      ),
    );
  }
}

class _InstrumentRow extends StatelessWidget {
  const _InstrumentRow({
    required this.name,
    required this.total,
    required this.max,
    required this.severity,
    required this.previous,
  });

  final String name;
  final int total;
  final int max;
  final String severity;
  final int? previous;

  @override
  Widget build(BuildContext context) {
    final change = previous == null ? null : total - previous!;
    // Lower is better on both SPIN and GAD-7.
    final Color changeColor = change == null || change == 0
        ? Colors.black45
        : change < 0
        ? const Color(0xFF1DB954)
        : const Color(0xFFFF9500);

    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.blue,
            ),
          ),
        ),
        Text(
          '$total',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        Text(
          '/$max',
          style: const TextStyle(fontSize: 12, color: Colors.black38),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: _Pill(label: severity, color: AppColors.blue),
        ),
        const Spacer(),
        if (change != null)
          Text(
            change == 0 ? 'No change' : '${change > 0 ? '+' : ''}$change pts',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: changeColor,
            ),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.black45,
          height: 1.45,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.creamLine),
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// The stored theme key carries a long-standing typo ("Embarassment") that
// other code matches on, so it's only corrected for display.
String _themeLabel(String theme) =>
    theme.replaceAll('Embarassment', 'Embarrassment');

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}
